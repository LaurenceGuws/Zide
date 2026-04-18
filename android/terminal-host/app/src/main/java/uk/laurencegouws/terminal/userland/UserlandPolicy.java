package uk.laurencegouws.terminal.userland;

/**
 * Central path policy for the Android app-private userland.
 *
 * <p>Keep path construction here so installer, session, and command execution code agree on the
 * same prefix, shell, and readiness stamp locations.
 */
public final class UserlandPolicy {
    public static final String PACKAGE_NAME = "uk.laurencegouws.zide";
    public static final String READINESS_STAMP_FILE = ".zide-userland-readiness.json";
    /**
     * Sibling package used in {@code runtime_support_links} embed bridge paths
     * (e.g. {@code /data/data/zide.embed/files/usr}).
     */
    public static final String RUNTIME_SUPPORT_EMBED_PACKAGE = "zide.embed";

    private UserlandPolicy() {
    }

    /** Absolute path of {@code /data/data/zide.embed} for runtime support link validation. */
    public static String runtimeSupportEmbedPackageRoot(final android.content.Context context) {
        final java.io.File filesDir = context.getFilesDir();
        final java.io.File packageRoot = filesDir.getParentFile();
        if (packageRoot == null) {
            return "";
        }
        final java.io.File dataDir = packageRoot.getParentFile();
        if (dataDir == null) {
            return "";
        }
        return new java.io.File(dataDir, RUNTIME_SUPPORT_EMBED_PACKAGE).getAbsolutePath();
    }

    public static String readinessStampPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), READINESS_STAMP_FILE).getAbsolutePath();
    }

    public static String shellPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), "usr/bin/bash").getAbsolutePath();
    }

    public static String prefixPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), "usr").getAbsolutePath();
    }
}
