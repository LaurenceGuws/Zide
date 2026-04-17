package uk.laurencegouws.terminal.host.input;

import android.content.Context;
import android.view.View;
import android.view.inputmethod.InputMethodManager;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.input.ShellInputView;

/** Functional callback adapter for {@link InputAssembly.Host}. */
public final class InputCallbacks implements InputAssembly.Host {
    private final Context harnessContext;
    private final ShellInputView.Host shellInputHost;
    private final View rootView;
    private final InputMethodManager inputMethodManager;
    private final BooleanSupplier currentImeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final Runnable refreshScrollOverlay;
    private final Consumer<String> updateStatus;
    private final Consumer<String> appendEvent;

    public InputCallbacks(
            Context harnessContext,
            ShellInputView.Host shellInputHost,
            View rootView,
            InputMethodManager inputMethodManager,
            BooleanSupplier currentImeVisible,
            Consumer<Boolean> setImeVisible,
            Runnable refreshScrollOverlay,
            Consumer<String> updateStatus,
            Consumer<String> appendEvent) {
        this.harnessContext = harnessContext;
        this.shellInputHost = shellInputHost;
        this.rootView = rootView;
        this.inputMethodManager = inputMethodManager;
        this.currentImeVisible = currentImeVisible;
        this.setImeVisible = setImeVisible;
        this.refreshScrollOverlay = refreshScrollOverlay;
        this.updateStatus = updateStatus;
        this.appendEvent = appendEvent;
    }

    @Override
    public Context harnessContext() {
        return harnessContext;
    }

    @Override
    public View rootView() {
        return rootView;
    }

    @Override
    public ShellInputView.Host shellInputHost() {
        return shellInputHost;
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
        return NativeBridge::nativeFollowSessionLiveBottomBridge;
    }

    @Override
    public Runnable refreshScrollOverlay() {
        return refreshScrollOverlay;
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
