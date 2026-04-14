package uk.laurencegouws.terminal.input;

import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.inputmethod.InputMethodManager;

/** Owns hardware-keyboard dispatch policy for terminal input on Android. */
public final class TerminalHardwareKeyboardController {
    /** Host callbacks for shell focus, IME state, and native scrollback follow. */
    public interface Host {
        ShellInputView shellInputView();

        InputMethodManager inputMethodManager();

        boolean currentImeVisible();

        void setImeVisible(boolean visible);

        boolean nativeLoaded();

        void followShellLiveBottom();

        void refreshProductScrollOverlay();

        void updateStatus(String statusLabel);
    }

    private final Host host;

    public TerminalHardwareKeyboardController(Host host) {
        this.host = host;
    }

    public boolean handleDispatchKeyEvent(KeyEvent event) {
        if (!shouldHandleHardwareKeyboardEvent(event)) {
            return false;
        }
        host.shellInputView().requestFocus();
        if (host.currentImeVisible()) {
            if (host.nativeLoaded()) {
                host.followShellLiveBottom();
                host.refreshProductScrollOverlay();
            }
            final InputMethodManager imm = host.inputMethodManager();
            if (imm != null) {
                imm.hideSoftInputFromWindow(host.shellInputView().getWindowToken(), 0);
            }
            host.setImeVisible(false);
            host.updateStatus("hardware-keyboard");
        }
        return host.shellInputView().handleHardwareKeyEvent(event);
    }

    private static boolean shouldHandleHardwareKeyboardEvent(KeyEvent event) {
        if ((event.getSource() & InputDevice.SOURCE_KEYBOARD) == 0) {
            return false;
        }
        switch (event.getKeyCode()) {
            case KeyEvent.KEYCODE_VOLUME_DOWN:
            case KeyEvent.KEYCODE_VOLUME_UP:
            case KeyEvent.KEYCODE_VOLUME_MUTE:
            case KeyEvent.KEYCODE_BACK:
            case KeyEvent.KEYCODE_HOME:
            case KeyEvent.KEYCODE_APP_SWITCH:
            case KeyEvent.KEYCODE_POWER:
                return false;
            default:
                return true;
        }
    }
}
