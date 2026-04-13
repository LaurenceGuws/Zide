package dev.zide.terminal.userland;

import android.content.Context;
import dev.zide.terminal.R;

/** Userland bootstrap blocker copy and action policy for the Android host UI. */
public final class UserlandBootstrapUiPolicy {
    private UserlandBootstrapUiPolicy() {
    }

    public static int title(UserlandBootstrapState state, UserlandInstallState installState, boolean rendererMissing) {
        if (installState.isInstalling()) {
            return R.string.product_bootstrap_title_installing;
        }
        if (installState.isFailed()) {
            return R.string.product_bootstrap_title_install_failed;
        }
        if (rendererMissing) {
            return R.string.product_bootstrap_title_renderer_missing;
        }
        switch (state.state) {
            case UserlandBootstrapState.STATE_INVALID_STAMP:
                return R.string.product_bootstrap_title_invalid;
            case UserlandBootstrapState.STATE_READY_UPGRADE_NEEDED:
                return R.string.product_bootstrap_title_upgrade;
            case UserlandBootstrapState.STATE_MISSING_SHELL:
            case UserlandBootstrapState.STATE_STAMP_NO_BASH:
                return R.string.product_bootstrap_title_shell_missing;
            case UserlandBootstrapState.STATE_MISSING_STAMP:
            default:
                return R.string.product_bootstrap_title_missing;
        }
    }

    public static CharSequence detail(
            Context context,
            UserlandBootstrapState state,
            UserlandInstallState installState,
            boolean rendererMissing) {
        if (installState.isInstalling()) {
            return installState.detail;
        }
        if (installState.isFailed()) {
            return context.getString(R.string.product_bootstrap_detail_install_failed, installState.detail);
        }
        if (rendererMissing) {
            return context.getText(R.string.product_bootstrap_detail_renderer_missing);
        }
        switch (state.state) {
            case UserlandBootstrapState.STATE_INVALID_STAMP:
                return context.getText(R.string.product_bootstrap_detail_invalid);
            case UserlandBootstrapState.STATE_READY_UPGRADE_NEEDED:
                return context.getText(R.string.product_bootstrap_detail_upgrade);
            case UserlandBootstrapState.STATE_MISSING_SHELL:
            case UserlandBootstrapState.STATE_STAMP_NO_BASH:
                return context.getText(R.string.product_bootstrap_detail_shell_missing);
            case UserlandBootstrapState.STATE_MISSING_STAMP:
            default:
                return context.getText(R.string.product_bootstrap_detail_missing);
        }
    }

    public static int actionLabel(UserlandBootstrapState state, UserlandInstallState installState) {
        if (installState.isInstalling()) {
            return R.string.product_bootstrap_installing;
        }
        if (shouldStartInstall(state)) {
            return UserlandBootstrapState.STATE_READY_UPGRADE_NEEDED.equals(state.state)
                    ? R.string.product_bootstrap_update
                    : R.string.product_bootstrap_install;
        }
        return R.string.product_bootstrap_retry;
    }

    public static boolean shouldStartInstall(UserlandBootstrapState state) {
        return UserlandBootstrapState.STATE_MISSING_STAMP.equals(state.state)
                || UserlandBootstrapState.STATE_INVALID_STAMP.equals(state.state)
                || UserlandBootstrapState.STATE_MISSING_SHELL.equals(state.state)
                || UserlandBootstrapState.STATE_STAMP_NO_BASH.equals(state.state)
                || UserlandBootstrapState.STATE_READY_UPGRADE_NEEDED.equals(state.state);
    }
}
