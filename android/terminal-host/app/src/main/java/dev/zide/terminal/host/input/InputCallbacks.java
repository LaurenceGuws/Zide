package dev.zide.terminal.host.input;

import android.app.Activity;
import android.view.View;
import android.view.inputmethod.InputMethodManager;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import dev.zide.terminal.input.ShellInputView;

/** Functional callback adapter for {@link InputAssembly.Host}. */
public final class InputCallbacks implements InputAssembly.Host {
    private final Supplier<Activity> activity;
    private final Supplier<View> rootView;
    private final Supplier<ShellInputView.Host> shellInputHost;
    private final Supplier<InputMethodManager> inputMethodManager;
    private final BooleanSupplier currentImeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final BooleanSupplier nativeLoaded;
    private final InputAssembly.IntSupplier nativeFollowShellLiveBottom;
    private final Runnable refreshProductScrollOverlay;
    private final Consumer<String> updateStatus;
    private final Consumer<String> appendEvent;

    public InputCallbacks(
            Supplier<Activity> activity,
            Supplier<View> rootView,
            Supplier<ShellInputView.Host> shellInputHost,
            Supplier<InputMethodManager> inputMethodManager,
            BooleanSupplier currentImeVisible,
            Consumer<Boolean> setImeVisible,
            BooleanSupplier nativeLoaded,
            InputAssembly.IntSupplier nativeFollowShellLiveBottom,
            Runnable refreshProductScrollOverlay,
            Consumer<String> updateStatus,
            Consumer<String> appendEvent) {
        this.activity = activity;
        this.rootView = rootView;
        this.shellInputHost = shellInputHost;
        this.inputMethodManager = inputMethodManager;
        this.currentImeVisible = currentImeVisible;
        this.setImeVisible = setImeVisible;
        this.nativeLoaded = nativeLoaded;
        this.nativeFollowShellLiveBottom = nativeFollowShellLiveBottom;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.updateStatus = updateStatus;
        this.appendEvent = appendEvent;
    }

    @Override
    public Activity activity() {
        return activity.get();
    }

    @Override
    public View rootView() {
        return rootView.get();
    }

    @Override
    public ShellInputView.Host shellInputHost() {
        return shellInputHost.get();
    }

    @Override
    public Supplier<InputMethodManager> inputMethodManager() {
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
    public BooleanSupplier nativeLoaded() {
        return nativeLoaded;
    }

    @Override
    public InputAssembly.IntSupplier nativeFollowShellLiveBottom() {
        return nativeFollowShellLiveBottom;
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
