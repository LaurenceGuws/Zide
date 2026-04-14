package uk.laurencegouws.terminal.host.input;

import android.app.Activity;
import android.view.View;
import android.view.inputmethod.InputMethodManager;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.input.ShellInputView;

/** Functional callback adapter for {@link InputAssembly.Host}. */
public final class InputCallbacks implements InputAssembly.Host {
    public static final class InputHostCallbacks {
        final Supplier<Activity> activity;
        final Supplier<View> rootView;
        final Supplier<ShellInputView.Host> shellInputHost;
        final Supplier<InputMethodManager> inputMethodManager;

        private InputHostCallbacks(
                Supplier<Activity> activity,
                Supplier<View> rootView,
                Supplier<ShellInputView.Host> shellInputHost,
                Supplier<InputMethodManager> inputMethodManager) {
            this.activity = activity;
            this.rootView = rootView;
            this.shellInputHost = shellInputHost;
            this.inputMethodManager = inputMethodManager;
        }

        public static InputHostCallbacks of(
                Supplier<Activity> activity,
                Supplier<View> rootView,
                Supplier<ShellInputView.Host> shellInputHost,
                Supplier<InputMethodManager> inputMethodManager) {
            return new InputHostCallbacks(
                    activity,
                    rootView,
                    shellInputHost,
                    inputMethodManager);
        }
    }

    public static final class InputRuntimeCallbacks {
        final BooleanSupplier currentImeVisible;
        final Consumer<Boolean> setImeVisible;
        final BooleanSupplier nativeLoaded;
        final InputAssembly.IntSupplier nativeFollowSessionLiveBottom;
        final Runnable refreshProductScrollOverlay;
        final Consumer<String> updateStatus;
        final Consumer<String> appendEvent;

        private InputRuntimeCallbacks(
                BooleanSupplier currentImeVisible,
                Consumer<Boolean> setImeVisible,
                BooleanSupplier nativeLoaded,
                InputAssembly.IntSupplier nativeFollowSessionLiveBottom,
                Runnable refreshProductScrollOverlay,
                Consumer<String> updateStatus,
                Consumer<String> appendEvent) {
            this.currentImeVisible = currentImeVisible;
            this.setImeVisible = setImeVisible;
            this.nativeLoaded = nativeLoaded;
            this.nativeFollowSessionLiveBottom = nativeFollowSessionLiveBottom;
            this.refreshProductScrollOverlay = refreshProductScrollOverlay;
            this.updateStatus = updateStatus;
            this.appendEvent = appendEvent;
        }

        public static InputRuntimeCallbacks of(
                BooleanSupplier currentImeVisible,
                Consumer<Boolean> setImeVisible,
                BooleanSupplier nativeLoaded,
                InputAssembly.IntSupplier nativeFollowSessionLiveBottom,
                Runnable refreshProductScrollOverlay,
                Consumer<String> updateStatus,
                Consumer<String> appendEvent) {
            return new InputRuntimeCallbacks(
                    currentImeVisible,
                    setImeVisible,
                    nativeLoaded,
                    nativeFollowSessionLiveBottom,
                    refreshProductScrollOverlay,
                    updateStatus,
                    appendEvent);
        }
    }

    private final InputHostCallbacks inputHostCallbacks;
    private final InputRuntimeCallbacks inputRuntimeCallbacks;

    public InputCallbacks(
            InputHostCallbacks inputHostCallbacks,
            InputRuntimeCallbacks inputRuntimeCallbacks) {
        this.inputHostCallbacks = inputHostCallbacks;
        this.inputRuntimeCallbacks = inputRuntimeCallbacks;
    }

    @Override
    public Activity activity() {
        return inputHostCallbacks.activity.get();
    }

    @Override
    public View rootView() {
        return inputHostCallbacks.rootView.get();
    }

    @Override
    public ShellInputView.Host shellInputHost() {
        return inputHostCallbacks.shellInputHost.get();
    }

    @Override
    public Supplier<InputMethodManager> inputMethodManager() {
        return inputHostCallbacks.inputMethodManager;
    }

    @Override
    public BooleanSupplier currentImeVisible() {
        return inputRuntimeCallbacks.currentImeVisible;
    }

    @Override
    public Consumer<Boolean> setImeVisible() {
        return inputRuntimeCallbacks.setImeVisible;
    }

    @Override
    public BooleanSupplier nativeLoaded() {
        return inputRuntimeCallbacks.nativeLoaded;
    }

    @Override
    public InputAssembly.IntSupplier nativeFollowSessionLiveBottom() {
        return inputRuntimeCallbacks.nativeFollowSessionLiveBottom;
    }

    @Override
    public Runnable refreshProductScrollOverlay() {
        return inputRuntimeCallbacks.refreshProductScrollOverlay;
    }

    @Override
    public Consumer<String> updateStatus() {
        return inputRuntimeCallbacks.updateStatus;
    }

    @Override
    public Consumer<String> appendEvent() {
        return inputRuntimeCallbacks.appendEvent;
    }
}
