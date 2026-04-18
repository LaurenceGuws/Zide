package uk.laurencegouws.terminal.input;

import android.view.InputDevice;
import android.view.KeyCharacterMap;
import android.view.KeyEvent;
import android.view.inputmethod.InputMethodManager;

/** Owns hardware-keyboard dispatch policy for terminal input on Android. */
public final class HardwareKeyboardController {
    /** Host callbacks for shell focus, IME state, and native scrollback follow. */
    public interface Host {
        ShellInputView shellInputView();

        InputMethodManager inputMethodManager();

        boolean currentImeVisible();

        void setImeVisible(boolean visible);

        boolean nativeLoaded();

        void followShellLiveBottom();

        void refreshScrollOverlay();

        void updateStatus(String statusLabel);
    }

    private final Host host;

    public HardwareKeyboardController(Host host) {
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
                host.refreshScrollOverlay();
            }
            final InputMethodManager imm = host.inputMethodManager();
            if (imm != null) {
                imm.hideSoftInputFromWindow(host.shellInputView().getWindowToken(), 0);
            }
            host.setImeVisible(false);
            host.updateStatus("input.hardware_keyboard.state");
        }
        return host.shellInputView().handleHardwareKeyEvent(event);
    }

    private static boolean shouldHandleHardwareKeyboardEvent(KeyEvent event) {
        if ((event.getSource() & InputDevice.SOURCE_KEYBOARD) == 0) {
            return false;
        }
        if (event.getDeviceId() == KeyCharacterMap.VIRTUAL_KEYBOARD) {
            return false;
        }
        final InputDevice device = event.getDevice();
        if (device == null || device.isVirtual()) {
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
