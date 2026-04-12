package dev.zide.terminal;

final class UserlandPolicy {
    static final String PACKAGE_NAME = "dev.zide.terminal";

    private UserlandPolicy() {
    }

    static String bootstrapStampPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), ".zide-userland-bootstrap.json").getAbsolutePath();
    }

    static String shellPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), "usr/bin/bash").getAbsolutePath();
    }

    static String prefixPath(android.content.Context context) {
        return new java.io.File(context.getFilesDir(), "usr").getAbsolutePath();
    }
}
