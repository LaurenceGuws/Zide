package uk.laurencegouws.terminal.userland;

import android.content.Context;

import java.io.IOException;
import java.util.Optional;

/**
 * Policy-owned invocation of {@code zide-pm install} for Android edge test-binary installs.
 *
 * <p>Install target is derived from {@code zide-pm list-available} output (see
 * {@link UserlandZidePmListAvailableCandidates}); no hardcoded package id. Callers own UX and
 * telemetry; this type centralizes argv shape and thread naming ({@code zide-pm-install-edge}).</p>
 */
public final class UserlandAndroidTestBinaryInstallLifecycle {
    /** Raised when {@code list-available} yields no parseable install candidate. */
    public static final class NoCandidateException extends IOException {
        private static final long serialVersionUID = 1L;

        public NoCandidateException(String message) {
            super(message);
        }
    }

    private UserlandAndroidTestBinaryInstallLifecycle() {
    }

    /**
     * Runs {@code zide-pm list-available}, selects a deterministic candidate, then {@code install}.
     *
     * @return trimmed {@code install} stdout
     */
    public static String runEdgePackageInstall(Context context) throws IOException {
        final String prefixPath = UserlandPolicy.prefixPath(context);
        final String listOut =
                UserlandCommandRunner.runZidePm(
                        context, "zide-pm-list", "list-available", "--prefix", prefixPath);
        final Optional<String> spec =
                UserlandZidePmListAvailableCandidates.selectLexicographicallyFirstInstallSpec(listOut);
        if (spec.isEmpty()) {
            throw new NoCandidateException(
                    "no package spec parsed from zide-pm list-available (empty catalog or no matching lines)");
        }
        return UserlandCommandRunner.runZidePm(
                context, "zide-pm-install-edge", "install", "--prefix", prefixPath, spec.get());
    }
}
