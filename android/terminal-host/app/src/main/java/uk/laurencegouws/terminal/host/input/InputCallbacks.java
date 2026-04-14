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
    public static final class InputHostBundle {
        final Supplier<Activity> activity;
        final Supplier<View> rootView;
        final Supplier<ShellInputView.Host> shellInputHost;
        final Supplier<InputMethodManager> inputMethodManager;

        private InputHostBundle(
                Supplier<Activity> activity,
                Supplier<View> rootView,
                Supplier<ShellInputView.Host> shellInputHost,
                Supplier<InputMethodManager> inputMethodManager) {
            this.activity = activity;
            this.rootView = rootView;
            this.shellInputHost = shellInputHost;
            this.inputMethodManager = inputMethodManager;
        }

        public static InputHostBundle of(
                Supplier<Activity> activity,
                Supplier<View> rootView,
                Supplier<ShellInputView.Host> shellInputHost,
                Supplier<InputMethodManager> inputMethodManager) {
            return new InputHostBundle(
                    activity,
                    rootView,
                    shellInputHost,
                    inputMethodManager);
        }
    }

    public static final class InputRuntimeBundle {
        final BooleanSupplier currentImeVisible;
        final Consumer<Boolean> setImeVisible;
        final BooleanSupplier nativeLoaded;
        final InputAssembly.IntSupplier nativeFollowSessionLiveBottom;
        final Runnable refreshProductScrollOverlay;
        final Consumer<String> updateStatus;
        final Consumer<String> appendEvent;

        private InputRuntimeBundle(
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

        public static InputRuntimeBundle of(
                BooleanSupplier currentImeVisible,
                Consumer<Boolean> setImeVisible,
                BooleanSupplier nativeLoaded,
                InputAssembly.IntSupplier nativeFollowSessionLiveBottom,
                Runnable refreshProductScrollOverlay,
                Consumer<String> updateStatus,
                Consumer<String> appendEvent) {
            return new InputRuntimeBundle(
                    currentImeVisible,
                    setImeVisible,
                    nativeLoaded,
                    nativeFollowSessionLiveBottom,
                    refreshProductScrollOverlay,
                    updateStatus,
                    appendEvent);
        }
    }

    private final InputHostBundle inputHostBundle;
    private final InputRuntimeBundle inputRuntimeBundle;

    public InputCallbacks(
            InputHostBundle inputHostBundle,
            InputRuntimeBundle inputRuntimeBundle) {
        this.inputHostBundle = inputHostBundle;
        this.inputRuntimeBundle = inputRuntimeBundle;
    }

    @Override
    public Activity activity() {
        return inputHostBundle.activity.get();
    }

    @Override
    public View rootView() {
        return inputHostBundle.rootView.get();
    }

    @Override
    public ShellInputView.Host shellInputHost() {
        return inputHostBundle.shellInputHost.get();
    }

    @Override
    public Supplier<InputMethodManager> inputMethodManager() {
        return inputHostBundle.inputMethodManager;
    }

    @Override
    public BooleanSupplier currentImeVisible() {
        return inputRuntimeBundle.currentImeVisible;
    }

    @Override
    public Consumer<Boolean> setImeVisible() {
        return inputRuntimeBundle.setImeVisible;
    }

    @Override
    public BooleanSupplier nativeLoaded() {
        return inputRuntimeBundle.nativeLoaded;
    }

    @Override
    public InputAssembly.IntSupplier nativeFollowSessionLiveBottom() {
        return inputRuntimeBundle.nativeFollowSessionLiveBottom;
    }

    @Override
    public Runnable refreshProductScrollOverlay() {
        return inputRuntimeBundle.refreshProductScrollOverlay;
    }

    @Override
    public Consumer<String> updateStatus() {
        return inputRuntimeBundle.updateStatus;
    }

    @Override
    public Consumer<String> appendEvent() {
        return inputRuntimeBundle.appendEvent;
    }
}
