package uk.laurencegouws.terminal.host.input;

import android.app.Activity;
import android.view.Gravity;
import android.view.inputmethod.InputMethodManager;
import android.widget.FrameLayout;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;

import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.input.HardwareKeyboardController;
import uk.laurencegouws.terminal.input.ImeFocusRecoveryController;

/** Owns shell input installation and input controller wiring assembly. */
public final class InputAssembly {
    /** Activity callbacks required to assemble input state. */
    public interface Host {
        Activity activity();

        android.view.View rootView();

        ShellInputView.Host shellInputHost();

        InputMethodManager inputMethodManager();

        BooleanSupplier currentImeVisible();

        Consumer<Boolean> setImeVisible();

        IntSupplier nativeFollowSessionLiveBottom();

        Runnable refreshProductScrollOverlay();

        Consumer<String> updateStatus();

        Consumer<String> appendEvent();

    }

    /** Primitive int supplier to avoid boxing in hot input paths. */
    public interface IntSupplier {
        int getAsInt();
    }

    /** Immutable assembled input result. */
    public static final class Result {
        public final ShellInputView shellInputView;
        public final HardwareKeyboardController hardwareKeyboardController;
        public final ImeFocusRecoveryController imeFocusRecoveryController;

        private Result(
                ShellInputView shellInputView,
                HardwareKeyboardController hardwareKeyboardController,
                ImeFocusRecoveryController imeFocusRecoveryController) {
            this.shellInputView = shellInputView;
            this.hardwareKeyboardController = hardwareKeyboardController;
            this.imeFocusRecoveryController = imeFocusRecoveryController;
        }
    }

    private InputAssembly() {
    }

    public static Result assemble(Host host) {
        final ShellInputView shellInputView = new ShellInputView(host.activity(), host.shellInputHost());
        final FrameLayout root = (FrameLayout) host.rootView();
        final FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(1, 1);
        lp.gravity = Gravity.BOTTOM | Gravity.START;
        root.addView(shellInputView, lp);

        final HardwareKeyboardController hardwareKeyboardController =
                InputFactory.createHardwareKeyboardController(
                        () -> shellInputView,
                        host.inputMethodManager(),
                        host.currentImeVisible(),
                        host.setImeVisible(),
                        () -> host.nativeFollowSessionLiveBottom().getAsInt(),
                        host.refreshProductScrollOverlay(),
                        host.updateStatus());
        final ImeFocusRecoveryController imeFocusRecoveryController =
                InputFactory.createImeFocusRecoveryController(
                        () -> shellInputView,
                        host.currentImeVisible(),
                        host.appendEvent(),
                        host.inputMethodManager());
        return new Result(shellInputView, hardwareKeyboardController, imeFocusRecoveryController);
    }
}
