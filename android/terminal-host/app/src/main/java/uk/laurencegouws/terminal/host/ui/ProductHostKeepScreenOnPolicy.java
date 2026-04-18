package uk.laurencegouws.terminal.host.ui;

import android.view.WindowManager;

/**
 * Harness-owned default keep-screen-on policy for the terminal host activity.
 *
 * <p>Applies {@link WindowManager.LayoutParams#FLAG_KEEP_SCREEN_ON} through {@link HostWindowFlagAccess}
 * so this type does not depend on raw {@link android.view.Window} in its API.</p>
 */
public final class ProductHostKeepScreenOnPolicy {

    /** Product default: keep screen on while the terminal host activity is showing. */
    public void applyDefaultTerminalHostPolicy(HostWindowFlagAccess windowFlags) {
        windowFlags.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }
}
