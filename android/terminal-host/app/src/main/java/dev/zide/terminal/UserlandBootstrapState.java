package dev.zide.terminal;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.json.JSONException;
import org.json.JSONObject;

final class UserlandBootstrapState {
    static final String STATE_MISSING_STAMP = "missing-stamp";
    static final String STATE_INVALID_STAMP = "invalid-stamp";
    static final String STATE_MISSING_SHELL = "missing-shell";
    static final String STATE_STAMP_NO_BASH = "stamp-no-bash";
    static final String STATE_READY_CURRENT = "ready-current";
    static final String STATE_READY_UPGRADE_NEEDED = "ready-upgrade-needed";

    final String state;
    final String format;
    final String artifact;
    final String version;
    final String provider;
    final boolean launchReady;
    final boolean expectedCurrent;

    UserlandBootstrapState(
            String state,
            String format,
            String artifact,
            String version,
            String provider,
            boolean launchReady,
            boolean expectedCurrent) {
        this.state = state;
        this.format = format;
        this.artifact = artifact;
        this.version = version;
        this.provider = provider;
        this.launchReady = launchReady;
        this.expectedCurrent = expectedCurrent;
    }

    static UserlandBootstrapState load(String stampPath, String shellPath, UserlandRelease release) {
        final File stampFile = new File(stampPath);
        if (!stampFile.isFile()) {
            return new UserlandBootstrapState(STATE_MISSING_STAMP, "", "", "", "", false, false);
        }

        final JSONObject stamp;
        try {
            stamp = new JSONObject(new String(Files.readAllBytes(stampFile.toPath()), StandardCharsets.UTF_8));
        } catch (IOException | JSONException err) {
            return new UserlandBootstrapState(STATE_INVALID_STAMP, "", "", "", "", false, false);
        }

        final String format = stamp.optString("format", "");
        final String artifact = stamp.optString("artifact", "");
        final String version = stamp.optString("version", "");
        final String provider = stamp.optString("provider", "");
        final boolean hasBash = stamp.optBoolean("has_bash", false);
        final boolean shellExists = new File(shellPath).isFile();
        final boolean expectedCurrent =
                release.artifactName.equals(artifact)
                        && release.artifactVersion.equals(version)
                        && release.provider.equals(provider);

        if (!hasBash) {
            return new UserlandBootstrapState(STATE_STAMP_NO_BASH, format, artifact, version, provider, false, expectedCurrent);
        }
        if (!shellExists) {
            return new UserlandBootstrapState(STATE_MISSING_SHELL, format, artifact, version, provider, false, expectedCurrent);
        }
        return new UserlandBootstrapState(
                expectedCurrent ? STATE_READY_CURRENT : STATE_READY_UPGRADE_NEEDED,
                format,
                artifact,
                version,
                provider,
                true,
                expectedCurrent);
    }
}
