package uk.laurencegouws.terminal.host.input;

import android.view.KeyEvent;

import java.util.function.Supplier;

import uk.laurencegouws.terminal.host.ui.ChromeController;
import uk.laurencegouws.terminal.input.HardwareKeyboardController;
import uk.laurencegouws.terminal.input.ImeFocusRecoveryController;
import uk.laurencegouws.terminal.input.ShellInputView;

/**
 * Startup-order null-guard forwards for input hardware path, IME focus recovery,
 * and chrome modifier latch — distinct from terminal text policy in {@code input/*}.
 */
public final class InputChromeStartupForwards {
    private final Supplier<HardwareKeyboardController> hardwareKeyboardController;
    private final Supplier<ImeFocusRecoveryController> imeFocusRecoveryController;
    private final Supplier<ChromeController> chromeController;

    public InputChromeStartupForwards(
            Supplier<HardwareKeyboardController> hardwareKeyboardController,
            Supplier<ImeFocusRecoveryController> imeFocusRecoveryController,
            Supplier<ChromeController> chromeController) {
        this.hardwareKeyboardController = hardwareKeyboardController;
        this.imeFocusRecoveryController = imeFocusRecoveryController;
        this.chromeController = chromeController;
    }

    public boolean handleHardwareDispatchKeyEventIfReady(KeyEvent event) {
        final HardwareKeyboardController c = hardwareKeyboardController.get();
        return c != null && c.handleDispatchKeyEvent(event);
    }

    public void notifyInputFocusRecoveryIfReady(boolean hasFocus) {
        final ImeFocusRecoveryController c = imeFocusRecoveryController.get();
        if (c != null) {
            c.onInputFocusChanged(hasFocus);
        }
    }

    public void applyModifierLatchIfReady(ShellInputView.Host.ModifierLatchState state) {
        final ChromeController c = chromeController.get();
        if (c != null) {
            c.applyModifierLatchState(state);
        }
    }
}
