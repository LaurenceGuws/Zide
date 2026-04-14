package uk.laurencegouws.terminal.userland;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Immutable readiness snapshot for the app-private Android userland prefix.
 *
 * <p>This class classifies the installed prefix against the release expected by the APK. It should
 * stay a small value/parser type and not perform install, UI, or shell-start work.
 */
public final class UserlandReadinessState {
    public static final String STATE_MISSING_STAMP = "missing-stamp";
    public static final String STATE_INVALID_STAMP = "invalid-stamp";
    public static final String STATE_MISSING_SHELL = "missing-shell";
    public static final String STATE_STAMP_NO_BASH = "stamp-no-bash";
    public static final String STATE_READY_CURRENT = "ready-current";
    public static final String STATE_READY_UPGRADE_NEEDED = "ready-upgrade-needed";

    public final String state;
    public final String format;
    public final String artifact;
    public final String version;
    public final String provider;
    public final boolean launchReady;
    public final boolean expectedCurrent;

    public UserlandReadinessState(
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

    public static UserlandReadinessState load(String stampPath, String shellPath, UserlandRelease release) {
        final File stampFile = resolveStampFile(stampPath);
        if (stampFile == null) {
            return new UserlandReadinessState(STATE_MISSING_STAMP, "", "", "", "", false, false);
        }

        final JSONObject stamp;
        try {
            stamp = new JSONObject(new String(Files.readAllBytes(stampFile.toPath()), StandardCharsets.UTF_8));
        } catch (IOException | JSONException err) {
            return new UserlandReadinessState(STATE_INVALID_STAMP, "", "", "", "", false, false);
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
            return new UserlandReadinessState(STATE_STAMP_NO_BASH, format, artifact, version, provider, false, expectedCurrent);
        }
        if (!shellExists) {
            return new UserlandReadinessState(STATE_MISSING_SHELL, format, artifact, version, provider, false, expectedCurrent);
        }
        return new UserlandReadinessState(
                expectedCurrent ? STATE_READY_CURRENT : STATE_READY_UPGRADE_NEEDED,
                format,
                artifact,
                version,
                provider,
                true,
                expectedCurrent);
    }

    private static File resolveStampFile(String stampPath) {
        final File primary = new File(stampPath);
        return primary.isFile() ? primary : null;
    }
}
