package uk.laurencegouws.terminal.host.input;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.input.TerminalHardwareKeyboardController;
import uk.laurencegouws.terminal.input.TerminalHardwareKeyboardHostCallbacks;
import uk.laurencegouws.terminal.input.TerminalImeFocusRecoveryController;
import uk.laurencegouws.terminal.input.TerminalImeFocusRecoveryHostCallbacks;

/**
 * Input interaction assembly helpers.
 *
 * <p>Owns input-specific controller construction so generic host assembly stays
 * focused on lifecycle/runtime/surface/session wiring.
 */
public final class InputFactory {
    private InputFactory() {
    }

    public static TerminalHardwareKeyboardController createHardwareKeyboardController(
            Supplier<ShellInputView> shellInputView,
            Supplier<android.view.inputmethod.InputMethodManager> inputMethodManager,
            BooleanSupplier currentImeVisible,
            Consumer<Boolean> setImeVisible,
            BooleanSupplier nativeLoaded,
            Runnable followShellLiveBottom,
            Runnable refreshProductScrollOverlay,
            Consumer<String> updateStatus) {
        return new TerminalHardwareKeyboardController(
                new TerminalHardwareKeyboardHostCallbacks(
                        shellInputView,
                        inputMethodManager,
                        currentImeVisible,
                        setImeVisible,
                        nativeLoaded,
                        followShellLiveBottom,
                        refreshProductScrollOverlay,
                        updateStatus));
    }

    public static TerminalImeFocusRecoveryController createImeFocusRecoveryController(
            Supplier<ShellInputView> shellInputView,
            BooleanSupplier imeVisible,
            Consumer<String> appendEvent,
            Supplier<android.view.inputmethod.InputMethodManager> inputMethodManager) {
        return new TerminalImeFocusRecoveryController(
                new TerminalImeFocusRecoveryHostCallbacks(
                        shellInputView,
                        imeVisible,
                        appendEvent,
                        inputMethodManager));
    }
}
