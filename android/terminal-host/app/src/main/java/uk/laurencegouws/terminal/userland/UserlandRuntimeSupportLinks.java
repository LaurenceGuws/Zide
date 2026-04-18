package uk.laurencegouws.terminal.userland;

import android.content.Context;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.function.Consumer;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Contract-owned materialization of {@code runtime_support_links} from the staged readiness stamp
 * (install snapshot) and from the install-time shell fragment.
 *
 * <p>Paths may reference the host package data dir or the {@link UserlandPolicy#RUNTIME_SUPPORT_EMBED_PACKAGE}
 * sibling (embed bridge). Materialization is idempotent ({@code rm -f} + {@code ln -s}).</p>
 */
public final class UserlandRuntimeSupportLinks {
    private UserlandRuntimeSupportLinks() {
    }

    /**
     * Re-applies all links recorded on the readiness stamp before native session activation. Reads
     * only local disk (no manifest network fetch).
     */
    public static void materializeFromReadinessStamp(final Context context, final Consumer<String> appendEvent)
            throws IOException {
        final File stampFile = new File(UserlandPolicy.readinessStampPath(context));
        if (!stampFile.isFile()) {
            throw new IOException("readiness stamp missing for runtime_support_links materialize");
        }
        final String raw;
        try {
            final JSONObject stamp =
                    new JSONObject(new String(Files.readAllBytes(stampFile.toPath()), StandardCharsets.UTF_8));
            raw = stamp.optString("runtime_support_links", "");
        } catch (JSONException err) {
            throw new IOException("invalid readiness stamp json", err);
        }
        if (raw == null || raw.isEmpty()) {
            if (appendEvent != null) {
                appendEvent.accept("userland.runtime_support_links.materialize skip empty_stamp_field");
            }
            return;
        }
        if (appendEvent != null) {
            appendEvent.accept("userland.runtime_support_links.materialize begin");
        }
        final File packageRoot = context.getFilesDir().getParentFile();
        if (packageRoot == null) {
            throw new IOException("missing package root");
        }
        final String command = "true" + installArchiveCommandFragment(context, packageRoot, raw);
        UserlandInstaller.executeShellCommand(command);
        if (appendEvent != null) {
            appendEvent.accept("userland.runtime_support_links.materialize ok");
        }
    }

    /**
     * Shell fragment (leading {@code " && "}) for the userland install pipeline, after the prefix
     * archive is extracted.
     */
    public static String installArchiveCommandFragment(final Context context, final File packageRoot, final String rawLinks)
            throws IOException {
        return linkCommandTail(context, packageRoot, rawLinks);
    }

    private static String linkCommandTail(final Context context, final File packageRoot, final String rawLinks)
            throws IOException {
        if (rawLinks == null || rawLinks.isEmpty()) {
            return "";
        }
        final String hostRoot = packageRoot.getAbsolutePath();
        final String embedRoot = UserlandPolicy.runtimeSupportEmbedPackageRoot(context);
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
            final String source = entry.substring(0, separator).trim();
            final String target = entry.substring(separator + 2).trim();
            final String normalizedSource = normalizeRuntimeSupportPath(source, hostRoot, embedRoot);
            final String normalizedTarget = normalizeRuntimeSupportPath(target, hostRoot, embedRoot);
            if (normalizedSource == null || normalizedTarget == null) {
                throw new IOException("runtime support link escapes allowed package roots: " + entry);
            }
            final File sourceFile = new File(normalizedSource);
            final File sourceParent = sourceFile.getParentFile();
            if (sourceParent == null) {
                throw new IOException("runtime support link has no parent");
            }
            command.append(" && mkdir -p ")
                    .append(UserlandInstaller.shellQuote(sourceParent.getAbsolutePath()))
                    .append(" && rm -f ")
                    .append(UserlandInstaller.shellQuote(normalizedSource))
                    .append(" && ln -s ")
                    .append(UserlandInstaller.shellQuote(normalizedTarget))
                    .append(" ")
                    .append(UserlandInstaller.shellQuote(normalizedSource));
        }
        return command.toString();
    }

    private static String normalizeRuntimeSupportPath(
            final String path, final String hostPackagePath, final String embedPackagePath) {
        if (path.equals(hostPackagePath) || path.startsWith(hostPackagePath + "/")) {
            return path;
        }
        if (embedPackagePath != null
                && !embedPackagePath.isEmpty()
                && (path.equals(embedPackagePath) || path.startsWith(embedPackagePath + "/"))) {
            return path;
        }
        return null;
    }
}
