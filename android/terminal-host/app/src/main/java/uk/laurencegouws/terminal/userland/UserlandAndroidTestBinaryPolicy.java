package uk.laurencegouws.terminal.userland;

/**
 * Product hook for proving {@code zide-pm install} on Android beyond baseline nvim/htop tooling.
 *
 * <p>Value is a package id understood by in-prefix {@code zide-pm}; catalog membership depends on
 * {@code ZIDE_PM_HOST_PLATFORM=android} and {@code zide-pm} itself.</p>
 */
public final class UserlandAndroidTestBinaryPolicy {
    private UserlandAndroidTestBinaryPolicy() {
    }

    /** Package spec passed to {@code zide-pm install} after doctor + list-available in Packages flow. */
    public static String edgeTestPackageSpec() {
        return "jq";
    }
}
