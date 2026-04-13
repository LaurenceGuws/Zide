package dev.zide.terminal.userland;

public final class UserlandPolicy {
    public static final String PACKAGE_NAME = "dev.zide.terminal";

    private UserlandPolicy() {
    }

    public static String bootstrapStampPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), ".zide-userland-bootstrap.json").getAbsolutePath();
    }

    public static String shellPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), "usr/bin/bash").getAbsolutePath();
    }

    public static String prefixPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), "usr").getAbsolutePath();
    }
}
