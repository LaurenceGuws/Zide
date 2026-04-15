package uk.laurencegouws.terminal.host.input;

import android.app.Activity;
import android.view.View;
import android.view.inputmethod.InputMethodManager;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;

import uk.laurencegouws.terminal.TerminalNativeBridge;
import uk.laurencegouws.terminal.input.ShellInputView;

/** Functional callback adapter for {@link InputAssembly.Host}; activity must implement {@link ShellInputView.Host}. */
public final class InputCallbacks implements InputAssembly.Host {
    private final Activity activity;
    private final View rootView;
    private final InputMethodManager inputMethodManager;
    private final BooleanSupplier currentImeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final Runnable refreshProductScrollOverlay;
    private final Consumer<String> updateStatus;
    private final Consumer<String> appendEvent;

    public InputCallbacks(
            Activity activity,
            View rootView,
            InputMethodManager inputMethodManager,
            BooleanSupplier currentImeVisible,
            Consumer<Boolean> setImeVisible,
            Runnable refreshProductScrollOverlay,
            Consumer<String> updateStatus,
            Consumer<String> appendEvent) {
        this.activity = activity;
        this.rootView = rootView;
        this.inputMethodManager = inputMethodManager;
        this.currentImeVisible = currentImeVisible;
        this.setImeVisible = setImeVisible;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.updateStatus = updateStatus;
        this.appendEvent = appendEvent;
    }

    @Override
    public Activity activity() {
        return activity;
    }

    @Override
    public View rootView() {
        return rootView;
    }

    @Override
    public ShellInputView.Host shellInputHost() {
        return (ShellInputView.Host) activity;
    }

    @Override
    public InputMethodManager inputMethodManager() {
        return inputMethodManager;
    }

    @Override
    public BooleanSupplier currentImeVisible() {
        return currentImeVisible;
    }

    @Override
    public Consumer<Boolean> setImeVisible() {
        return setImeVisible;
    }

    @Override
    public InputAssembly.IntSupplier nativeFollowSessionLiveBottom() {
        return TerminalNativeBridge::nativeFollowSessionLiveBottomBridge;
    }

    @Override
    public Runnable refreshProductScrollOverlay() {
        return refreshProductScrollOverlay;
    }

    @Override
    public Consumer<String> updateStatus() {
        return updateStatus;
    }

    @Override
    public Consumer<String> appendEvent() {
        return appendEvent;
    }
}
