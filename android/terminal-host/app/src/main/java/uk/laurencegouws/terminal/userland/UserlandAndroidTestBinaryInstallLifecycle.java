package uk.laurencegouws.terminal.userland;

import android.content.Context;

import java.io.IOException;

/**
 * Policy-owned invocation of {@code zide-pm install} for the Android edge test package.
 *
 * <p>Callers own UX/telemetry; this type only centralizes argv shape and thread naming
 * expectations ({@code zide-pm-install-edge}).</p>
 */
public final class UserlandAndroidTestBinaryInstallLifecycle {
    private UserlandAndroidTestBinaryInstallLifecycle() {
    }

    /**
     * Runs {@code zide-pm install} for {@link UserlandAndroidTestBinaryPolicy#edgeTestPackageSpec()}.
     *
     * @return trimmed command stdout (including zide-pm’s own reporting)
     */
    public static String runEdgePackageInstall(Context context) throws IOException {
        final String prefixPath = UserlandPolicy.prefixPath(context);
        final String edge = UserlandAndroidTestBinaryPolicy.edgeTestPackageSpec();
        return UserlandCommandRunner.runZidePm(
                context, "zide-pm-install-edge", "install", "--prefix", prefixPath, edge);
    }
}
