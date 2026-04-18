package uk.laurencegouws.terminal.host.input;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.host.ui.HostImeStateAccess;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.input.HardwareKeyboardController;
import uk.laurencegouws.terminal.input.HardwareKeyboardHostCallbacks;
import uk.laurencegouws.terminal.input.ImeFocusRecoveryController;
import uk.laurencegouws.terminal.input.ImeFocusRecoveryHostCallbacks;

/**
 * Input interaction assembly helpers.
 *
 * <p>Owns input-specific controller construction so generic host assembly stays
 * focused on lifecycle/runtime/surface/session wiring.
 */
public final class InputFactory {
    private InputFactory() {
    }

    public static HardwareKeyboardController createHardwareKeyboardController(
            Supplier<ShellInputView> shellInputView,
            android.view.inputmethod.InputMethodManager inputMethodManager,
            HostImeStateAccess hostImeState,
            Runnable followShellLiveBottom,
            Runnable refreshScrollOverlay,
            Consumer<String> updateStatus) {
        return new HardwareKeyboardController(
                new HardwareKeyboardHostCallbacks(
                        shellInputView,
                        inputMethodManager,
                        hostImeState,
                        followShellLiveBottom,
                        refreshScrollOverlay,
                        updateStatus));
    }

    public static ImeFocusRecoveryController createImeFocusRecoveryController(
            Supplier<ShellInputView> shellInputView,
            HostImeStateAccess hostImeState,
            Consumer<String> appendEvent,
            android.view.inputmethod.InputMethodManager inputMethodManager) {
        return new ImeFocusRecoveryController(
                new ImeFocusRecoveryHostCallbacks(
                        shellInputView,
                        hostImeState,
                        appendEvent,
                        inputMethodManager));
    }
}
