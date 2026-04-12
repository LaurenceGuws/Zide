package dev.zide.terminal;

final class UserlandPolicy {
    static final String PACKAGE_NAME = "dev.zide.terminal";
    static final String MANIFEST_URL =
            "https://github.com/LaurenceGuws/zide-mobile-pm/releases/download/"
                    + "android-dev-2026.04.12.002012/android-dev-prefix.release.manifest.json";
    static final String EXPECTED_ARTIFACT_NAME = "zide-android-dev-prefix";
    static final String EXPECTED_ARTIFACT_VERSION = "sha256-b123a7b39cc2";
    static final String EXPECTED_PROVIDER = "termux-main";

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
