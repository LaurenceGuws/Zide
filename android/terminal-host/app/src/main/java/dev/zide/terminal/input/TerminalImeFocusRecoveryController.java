package dev.zide.terminal.input;

import android.view.inputmethod.InputMethodManager;

/** Owns IME focus-recovery behavior for the hidden ShellInputView. */
public final class TerminalImeFocusRecoveryController {
    /** Host callbacks for focus state, diagnostics, and IME operations. */
    public interface Host {
        ShellInputView shellInputView();

        boolean imeVisible();

        void appendEvent(String event);

        InputMethodManager inputMethodManager();
    }

    private final Host host;

    public TerminalImeFocusRecoveryController(Host host) {
        this.host = host;
    }

    public void onInputFocusChanged(boolean hasFocus) {
        if (hasFocus || !host.imeVisible()) {
            return;
        }
        final ShellInputView shellInputView = host.shellInputView();
        shellInputView.post(() -> {
            host.appendEvent("input.focus recoverAttempt");
            shellInputView.requestFocusFromTouch();
            if (!shellInputView.hasFocus()) {
                shellInputView.requestFocus();
            }
            final InputMethodManager imm = host.inputMethodManager();
            if (imm != null) {
                imm.restartInput(shellInputView);
                final boolean shown = imm.showSoftInput(shellInputView, InputMethodManager.SHOW_IMPLICIT);
                host.appendEvent("input.focus recoverShown=" + shown + " focus=" + shellInputView.hasFocus());
            }
        });
    }
}
