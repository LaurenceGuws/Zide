package dev.zide.terminal.userland;

import android.content.Context;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Locale;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Installs the pinned userland artifact into the app-private prefix.
 *
 * <p>This class owns manifest fetch, archive verification, extraction, runtime support links, and
 * bootstrap stamp validation. It deliberately has no Android view, lifecycle, or shell session
 * ownership.
 */
public final class UserlandInstaller {
    private static final int BUFFER_SIZE = 64 * 1024;
    private static final int CONNECT_TIMEOUT_MS = 15000;
    private static final int READ_TIMEOUT_MS = 300000;

    public static final class Result {
        public final UserlandReadinessState readinessState;
        public final String detail;

        public Result(UserlandReadinessState readinessState, String detail) {
            this.readinessState = readinessState;
            this.detail = detail;
        }
    }

    private UserlandInstaller() {
    }

    public static Result install(Context context, UserlandRelease release) throws IOException {
        final UserlandArtifact artifact = readArtifactManifest(context, release);
        final File archive = fetchArtifact(context, artifact);
        installArchive(context, archive, artifact);
        final UserlandReadinessState readinessState = UserlandReadinessState.load(
                UserlandPolicy.readinessStampPath(context),
                UserlandPolicy.shellPath(context),
                release);
        if (!readinessState.launchReady) {
            throw new IOException("install finished without a launchable bash shell");
        }
        return new Result(
                readinessState,
                "artifact=" + artifact.name + " version=" + artifact.version + " provider=" + artifact.provider);
    }

    private static UserlandArtifact readArtifactManifest(Context context, UserlandRelease release) throws IOException {
        final byte[] payload = readUrlBytes(release.manifestUrl);
        final JSONObject manifest;
        try {
            manifest = new JSONObject(new String(payload, StandardCharsets.UTF_8));
        } catch (JSONException err) {
            throw new IOException("invalid userland manifest json", err);
        }
        if (manifest.optInt("schema_version", 0) != 1) {
            throw new IOException("unsupported userland manifest schema_version");
        }
        if (!"zide-mobile-pm".equals(manifest.optString("project", ""))) {
            throw new IOException("unexpected userland manifest project");
        }
        if (!"android".equals(manifest.optString("platform", ""))) {
            throw new IOException("unexpected userland manifest platform");
        }
        final JSONArray artifacts = manifest.optJSONArray("artifacts");
        if (artifacts == null) {
            throw new IOException("userland manifest missing artifacts");
        }

        JSONObject selected = null;
        for (int i = 0; i < artifacts.length(); i += 1) {
            final Object raw = artifacts.opt(i);
            if (!(raw instanceof JSONObject)) {
                continue;
            }
            final JSONObject candidate = (JSONObject) raw;
            if ("android-prefix-archive".equals(candidate.optString("kind", ""))) {
                if (selected != null) {
                    throw new IOException("userland manifest has multiple android-prefix-archive entries");
                }
                selected = candidate;
            }
        }
        if (selected == null) {
            throw new IOException("userland manifest missing android-prefix-archive");
        }

        final JSONObject metadata = selected.optJSONObject("metadata");
        if (metadata == null) {
            throw new IOException("android-prefix-archive missing metadata");
        }
        if (!UserlandPolicy.PACKAGE_NAME.equals(metadata.optString("package_name", ""))) {
            throw new IOException("userland artifact package_name mismatch");
        }
        if (!matchesOwnedPrefix(metadata.optString("prefix", ""))) {
            throw new IOException("userland artifact prefix mismatch");
        }
        final String archiveRoot = metadata.optString("archive_root", "");
        if (!"usr".equals(archiveRoot)) {
            throw new IOException("userland artifact archive_root mismatch");
        }
        final String provider = metadata.optString("provider", "");
        if (provider.isEmpty()) {
            throw new IOException("userland artifact missing provider");
        }

        final String name = selected.optString("name", "");
        final String version = selected.optString("version", "");
        final String url = selected.optString("url", "");
        final String sha256 = selected.optString("sha256", "");
        final long size = selected.optLong("size", -1L);
        if (name.isEmpty() || version.isEmpty() || url.isEmpty() || sha256.isEmpty() || size < 0L) {
            throw new IOException("android-prefix-archive missing required fields");
        }

        final String resolvedUrl = resolveManifestUrl(release.manifestUrl, url);
        final String hardcodedPolicy = metadata.optString("hardcoded_termux_policy", "unknown");
        final String runtimeSupportLinks = metadata.optString("runtime_support_links", "");
        return new UserlandArtifact(
                release.manifestUrl,
                name,
                version,
                resolvedUrl,
                sha256,
                size,
                archiveRoot,
                provider,
                hardcodedPolicy,
                runtimeSupportLinks);
    }

    private static File fetchArtifact(Context context, UserlandArtifact artifact) throws IOException {
        final File cacheDir = new File(context.getCacheDir(), "userland-artifacts");
        if (!cacheDir.isDirectory() && !cacheDir.mkdirs()) {
            throw new IOException("failed to create userland artifact cache");
        }
        final File archive = new File(
                cacheDir,
                artifact.name + "-" + artifact.version + "-" + artifact.sha256.substring(0, 12) + ".tar.gz");
        if (verifySizeAndSha256(archive, artifact.size, artifact.sha256)) {
            return archive;
        }
        downloadToFile(artifact.url, archive);
        if (!verifySizeAndSha256(archive, artifact.size, artifact.sha256)) {
            if (archive.isFile()) {
                archive.delete();
            }
            throw new IOException("artifact verification failed");
        }
        return archive;
    }

    private static void installArchive(Context context, File archive, UserlandArtifact artifact) throws IOException {
        final File filesDir = context.getFilesDir();
        final File packageRoot = filesDir.getParentFile();
        if (packageRoot == null) {
            throw new IOException("missing package root");
        }
        final File prefixDir = new File(filesDir, "usr");
        final File homeDir = new File(filesDir, "home");
        final File tmpDir = new File(packageRoot, "tmp");
        final File aptConfPartsLink = new File(packageRoot, "aptc");
        final File dpkgEtcLink = new File(packageRoot, "dpkg");
        final File dpkgDbLink = new File(packageRoot, "dpkgdb");
        final File stampFile = new File(filesDir, ".zide-userland-bootstrap.json");

        final String command = "rm -rf " + shellQuote(prefixDir.getAbsolutePath()) +
                " " + shellQuote(stampFile.getAbsolutePath()) +
                " && mkdir -p " + shellQuote(filesDir.getAbsolutePath()) +
                " " + shellQuote(homeDir.getAbsolutePath()) +
                " " + shellQuote(tmpDir.getAbsolutePath()) +
                " && cd " + shellQuote(filesDir.getAbsolutePath()) +
                " && toybox tar -xzf " + shellQuote(archive.getAbsolutePath()) +
                " && rm -f " + shellQuote(aptConfPartsLink.getAbsolutePath()) +
                " " + shellQuote(dpkgEtcLink.getAbsolutePath()) +
                " " + shellQuote(dpkgDbLink.getAbsolutePath()) +
                " && ln -s " + shellQuote(new File(prefixDir, "etc/apt/apt.conf.d").getAbsolutePath()) +
                " " + shellQuote(aptConfPartsLink.getAbsolutePath()) +
                " && ln -s " + shellQuote(new File(prefixDir, "etc/dpkg").getAbsolutePath()) +
                " " + shellQuote(dpkgEtcLink.getAbsolutePath()) +
                " && ln -s " + shellQuote(new File(prefixDir, "var/lib/dpkg").getAbsolutePath()) +
                " " + shellQuote(dpkgDbLink.getAbsolutePath()) +
                runtimeSupportLinkCommand(packageRoot, artifact.runtimeSupportLinks) +
                " && chmod 700 " + shellQuote(homeDir.getAbsolutePath()) +
                " " + shellQuote(tmpDir.getAbsolutePath());
        runShell(command);

        final File bash = new File(prefixDir, "bin/bash");
        final File apt = new File(prefixDir, "bin/apt");
        final File nvim = new File(prefixDir, "bin/nvim");
        final File btop = new File(prefixDir, "bin/btop");
        if (!bash.isFile()) {
            throw new IOException("installed artifact did not provide usr/bin/bash");
        }

        final JSONObject stamp = new JSONObject();
        try {
            stamp.put("source", artifact.manifestSource);
            stamp.put("format", "android-prefix-artifact");
            stamp.put("artifact", artifact.name);
            stamp.put("version", artifact.version);
            stamp.put("provider", artifact.provider);
            stamp.put("archive_root", artifact.archiveRoot);
            stamp.put("hardcoded_termux_policy", artifact.hardcodedTermuxPolicy);
            stamp.put("has_bash", bash.isFile());
            stamp.put("has_apt", apt.isFile());
            stamp.put("has_nvim", nvim.isFile());
            stamp.put("has_btop", btop.isFile());
        } catch (JSONException err) {
            throw new IOException("failed to build userland stamp", err);
        }
        final String stampText;
        try {
            stampText = stamp.toString(2) + "\n";
        } catch (JSONException err) {
            throw new IOException("failed to serialize userland stamp", err);
        }
        writeFile(stampFile, stampText);
    }

    private static void downloadToFile(String urlText, File destination) throws IOException {
        final HttpURLConnection connection = (HttpURLConnection) URI.create(urlText).toURL().openConnection();
        connection.setConnectTimeout(CONNECT_TIMEOUT_MS);
        connection.setReadTimeout(READ_TIMEOUT_MS);
        connection.setRequestProperty("User-Agent", "zide-android-terminal-host");
        try {
            final int status = connection.getResponseCode();
            if (status < 200 || status >= 300) {
                throw new IOException("artifact download failed http=" + status);
            }
            try (InputStream in = new BufferedInputStream(connection.getInputStream());
                    FileOutputStream out = new FileOutputStream(destination, false)) {
                final byte[] buffer = new byte[BUFFER_SIZE];
                while (true) {
                    final int read = in.read(buffer);
                    if (read < 0) {
                        break;
                    }
                    out.write(buffer, 0, read);
                }
                out.getFD().sync();
            }
        } finally {
            connection.disconnect();
        }
    }

    private static byte[] readUrlBytes(String urlText) throws IOException {
        final HttpURLConnection connection = (HttpURLConnection) URI.create(urlText).toURL().openConnection();
        connection.setConnectTimeout(CONNECT_TIMEOUT_MS);
        connection.setReadTimeout(READ_TIMEOUT_MS);
        connection.setRequestProperty("User-Agent", "zide-android-terminal-host");
        try {
            final int status = connection.getResponseCode();
            if (status < 200 || status >= 300) {
                throw new IOException("manifest fetch failed http=" + status);
            }
            try (InputStream in = new BufferedInputStream(connection.getInputStream());
                    ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                final byte[] buffer = new byte[BUFFER_SIZE];
                while (true) {
                    final int read = in.read(buffer);
                    if (read < 0) {
                        break;
                    }
                    out.write(buffer, 0, read);
                }
                return out.toByteArray();
            }
        } finally {
            connection.disconnect();
        }
    }

    private static boolean verifySizeAndSha256(File file, long expectedSize, String expectedSha256) throws IOException {
        if (!file.isFile()) {
            return false;
        }
        if (expectedSize >= 0L && file.length() != expectedSize) {
            return false;
        }
        return sha256File(file).equalsIgnoreCase(expectedSha256);
    }

    private static String sha256File(File file) throws IOException {
        final MessageDigest digest;
        try {
            digest = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException err) {
            throw new IOException("sha-256 unavailable", err);
        }
        try (InputStream in = new BufferedInputStream(new FileInputStream(file))) {
            final byte[] buffer = new byte[BUFFER_SIZE];
            while (true) {
                final int read = in.read(buffer);
                if (read < 0) {
                    break;
                }
                digest.update(buffer, 0, read);
            }
        }
        final byte[] bytes = digest.digest();
        final StringBuilder out = new StringBuilder(bytes.length * 2);
        for (byte value : bytes) {
            out.append(String.format(Locale.US, "%02x", value));
        }
        return out.toString();
    }

    private static String resolveManifestUrl(String manifestUrl, String artifactUrl) throws IOException {
        try {
            return URI.create(manifestUrl).resolve(artifactUrl).toString();
        } catch (Exception err) {
            throw new IOException("failed to resolve artifact url", err);
        }
    }

    private static void runShell(String command) throws IOException {
        final Process process = new ProcessBuilder("/system/bin/sh", "-c", command)
                .redirectErrorStream(true)
                .start();
        final String output;
        try (InputStream in = process.getInputStream(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            final byte[] buffer = new byte[BUFFER_SIZE];
            while (true) {
                final int read = in.read(buffer);
                if (read < 0) {
                    break;
                }
                out.write(buffer, 0, read);
            }
            output = out.toString(StandardCharsets.UTF_8.name()).trim();
        }
        final int exitCode;
        try {
            exitCode = process.waitFor();
        } catch (InterruptedException err) {
            Thread.currentThread().interrupt();
            throw new IOException("userland install interrupted", err);
        }
        if (exitCode != 0) {
            throw new IOException(output.isEmpty() ? "userland install shell command failed" : output);
        }
    }

    private static String runtimeSupportLinkCommand(File packageRoot, String rawLinks) throws IOException {
        if (rawLinks == null || rawLinks.isEmpty()) {
            return "";
        }
        final String packagePath = packageRoot.getAbsolutePath();
        final StringBuilder command = new StringBuilder();
        final String[] entries = rawLinks.split(",");
        for (String entry : entries) {
            if (entry.isEmpty()) {
                continue;
            }
            final int separator = entry.indexOf("=>");
            if (separator <= 0 || separator + 2 >= entry.length()) {
                throw new IOException("invalid runtime support link: " + entry);
            }
            final String source = entry.substring(0, separator);
            final String target = entry.substring(separator + 2);
            if (!source.startsWith(packagePath + "/") || !target.startsWith(packagePath + "/")) {
                throw new IOException("runtime support link escapes package root");
            }
            final File sourceFile = new File(source);
            final File sourceParent = sourceFile.getParentFile();
            if (sourceParent == null) {
                throw new IOException("runtime support link has no parent");
            }
            command.append(" && mkdir -p ")
                    .append(shellQuote(sourceParent.getAbsolutePath()))
                    .append(" && rm -f ")
                    .append(shellQuote(source))
                    .append(" && ln -s ")
                    .append(shellQuote(target))
                    .append(" ")
                    .append(shellQuote(source));
        }
        return command.toString();
    }

    private static void writeFile(File file, String text) throws IOException {
        try (BufferedOutputStream out = new BufferedOutputStream(new FileOutputStream(file, false))) {
            out.write(text.getBytes(StandardCharsets.UTF_8));
            out.flush();
        }
    }

    private static boolean matchesOwnedPrefix(String prefix) {
        if (prefix == null || prefix.isEmpty()) {
            return false;
        }
        return prefix.endsWith("/" + UserlandPolicy.PACKAGE_NAME + "/files/usr");
    }

    private static String shellQuote(String text) {
        return "'" + text.replace("'", "'\"'\"'") + "'";
    }
}
