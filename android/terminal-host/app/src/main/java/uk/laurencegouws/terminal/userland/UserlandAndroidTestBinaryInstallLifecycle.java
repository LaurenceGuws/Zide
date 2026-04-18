package uk.laurencegouws.terminal.userland;

import android.content.Context;

import java.io.IOException;
import java.util.List;
import java.util.Optional;

/**
 * Policy-owned invocation of {@code zide-pm install} for Android edge test-binary installs.
 *
 * <p>Install target is derived from {@code zide-pm list-available} output (see
 * {@link UserlandZidePmListAvailableCandidates}); only {@code zide-android-*} ids are eligible. Callers
 * emit {@code packages.edge_install.selected} before invoking {@link #installPackageSpec}.</p>
 */
public final class UserlandAndroidTestBinaryInstallLifecycle {
    /** No parseable first-column package tokens in {@code list-available} output. */
    public static final String NO_CANDIDATE_EMPTY_CATALOG = "empty_catalog";

    /** Parsed catalog rows exist but none match {@link UserlandZidePmListAvailableCandidates#ANDROID_EDGE_PREFIX}. */
    public static final String NO_CANDIDATE_NO_ANDROID_EDGE = "no_android_edge";

    /** Raised when {@code list-available} yields no eligible Android edge install candidate. */
    public static final class NoCandidateException extends IOException {
        private static final long serialVersionUID = 2L;

        private final String reasonCode;

        public NoCandidateException(String reasonCode, String message) {
            super(message);
            this.reasonCode = reasonCode;
        }

        public String reasonCode() {
            return reasonCode;
        }
    }

    private UserlandAndroidTestBinaryInstallLifecycle() {
    }

    /**
     * Runs {@code zide-pm list-available} and resolves the deterministic Android edge spec, or throws.
     */
    public static String selectAndroidEdgeSpecOrThrow(Context context) throws IOException, NoCandidateException {
        final String prefixPath = UserlandPolicy.prefixPath(context);
        final String listOut =
                UserlandCommandRunner.runZidePm(
                        context, "zide-pm-list", "list-available", "--prefix", prefixPath);
        final List<String> any = UserlandZidePmListAvailableCandidates.parseAllFirstColumnPackageTokens(listOut);
        final Optional<String> spec =
                UserlandZidePmListAvailableCandidates.selectLexicographicallyFirstInstallSpec(listOut);
        if (spec.isEmpty()) {
            if (any.isEmpty()) {
                throw new NoCandidateException(
                        NO_CANDIDATE_EMPTY_CATALOG,
                        "no first-column package tokens parsed from zide-pm list-available");
            }
            throw new NoCandidateException(
                    NO_CANDIDATE_NO_ANDROID_EDGE,
                    "zide-pm list-available has no zide-android-* edge id (rejected non-edge catalog rows)");
        }
        return spec.get();
    }

    /** Runs {@code zide-pm install} for an already-selected package spec (edge flow only). */
    public static String installPackageSpec(Context context, String packageSpec) throws IOException {
        final String prefixPath = UserlandPolicy.prefixPath(context);
        return UserlandCommandRunner.runZidePm(
                context, "zide-pm-install-edge", "install", "--prefix", prefixPath, packageSpec);
    }
}
