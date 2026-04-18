package uk.laurencegouws.terminal.host.ui;

import android.view.Window;
import android.view.WindowManager;

/**
 * Harness-owned default keep-screen-on policy for the terminal host activity.
 *
 * <p>Centralizes {@link WindowManager.LayoutParams#FLAG_KEEP_SCREEN_ON} application so future
 * settings-driven toggles can own the decision in one place without scattering {@link Window}
 * flag mutations.</p>
 */
public final class ProductHostKeepScreenOnPolicy {

    /** Product default: keep screen on while the terminal host activity is showing. */
    public void applyDefaultTerminalHostPolicy(Window window) {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }
}
