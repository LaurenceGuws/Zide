package uk.laurencegouws.terminal.input;

import android.view.inputmethod.InputMethodManager;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.host.ui.HostImeStateAccess;

/** Functional callback adapter for {@link ImeFocusRecoveryController}. */
public final class ImeFocusRecoveryHostCallbacks implements ImeFocusRecoveryController.Host {
    private final Supplier<ShellInputView> shellInputView;
    private final HostImeStateAccess hostImeState;
    private final Consumer<String> appendEvent;
    private final InputMethodManager inputMethodManager;

    public ImeFocusRecoveryHostCallbacks(
            Supplier<ShellInputView> shellInputView,
            HostImeStateAccess hostImeState,
            Consumer<String> appendEvent,
            InputMethodManager inputMethodManager) {
        this.shellInputView = shellInputView;
        this.hostImeState = hostImeState;
        this.appendEvent = appendEvent;
        this.inputMethodManager = inputMethodManager;
    }

    @Override
    public ShellInputView shellInputView() {
        return shellInputView.get();
    }

    @Override
    public boolean imeVisible() {
        return hostImeState.imeVisible();
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public InputMethodManager inputMethodManager() {
        return inputMethodManager;
    }
}
