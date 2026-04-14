package dev.zide.terminal.userland;

/**
 * Central path policy for the Android app-private userland.
 *
 * <p>Keep path construction here so installer, session, and command execution code agree on the
 * same prefix, shell, and bootstrap stamp locations.
 */
public final class UserlandPolicy {
    public static final String PACKAGE_NAME = "dev.zide.terminal";

    private UserlandPolicy() {
    }

    public static String readinessStampPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), ".zide-userland-bootstrap.json").getAbsolutePath();
    }

    public static String shellPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), "usr/bin/bash").getAbsolutePath();
    }

    public static String prefixPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), "usr").getAbsolutePath();
    }
}
