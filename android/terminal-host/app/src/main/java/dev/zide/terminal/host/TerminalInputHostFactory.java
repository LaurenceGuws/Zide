package dev.zide.terminal.host;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import dev.zide.terminal.input.ShellInputView;
import dev.zide.terminal.input.TerminalHardwareKeyboardController;
import dev.zide.terminal.input.TerminalHardwareKeyboardHostCallbacks;
import dev.zide.terminal.input.TerminalImeFocusRecoveryController;
import dev.zide.terminal.input.TerminalImeFocusRecoveryHostCallbacks;

/**
 * Input interaction assembly helpers.
 *
 * <p>Owns input-specific controller construction so generic host assembly stays
 * focused on lifecycle/runtime/surface/session wiring.
 */
public final class TerminalInputHostFactory {
    private TerminalInputHostFactory() {
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
