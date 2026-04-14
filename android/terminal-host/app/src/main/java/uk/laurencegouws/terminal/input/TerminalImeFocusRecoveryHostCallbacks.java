package uk.laurencegouws.terminal.input;

import android.view.inputmethod.InputMethodManager;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Functional callback adapter for {@link TerminalImeFocusRecoveryController}. */
public final class TerminalImeFocusRecoveryHostCallbacks implements TerminalImeFocusRecoveryController.Host {
    private final Supplier<ShellInputView> shellInputView;
    private final BooleanSupplier imeVisible;
    private final Consumer<String> appendEvent;
    private final Supplier<InputMethodManager> inputMethodManager;

    public TerminalImeFocusRecoveryHostCallbacks(
            Supplier<ShellInputView> shellInputView,
            BooleanSupplier imeVisible,
            Consumer<String> appendEvent,
            Supplier<InputMethodManager> inputMethodManager) {
        this.shellInputView = shellInputView;
        this.imeVisible = imeVisible;
        this.appendEvent = appendEvent;
        this.inputMethodManager = inputMethodManager;
    }

    @Override
    public ShellInputView shellInputView() {
        return shellInputView.get();
    }

    @Override
    public boolean imeVisible() {
        return imeVisible.getAsBoolean();
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public InputMethodManager inputMethodManager() {
        return inputMethodManager.get();
    }
}
