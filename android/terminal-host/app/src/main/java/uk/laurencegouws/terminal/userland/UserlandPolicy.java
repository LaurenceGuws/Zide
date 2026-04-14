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

    private UserlandPolicy() {
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
