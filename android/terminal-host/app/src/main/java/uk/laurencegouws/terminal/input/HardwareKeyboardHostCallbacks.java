package uk.laurencegouws.terminal.input;

import android.view.inputmethod.InputMethodManager;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.NativeBridge;

/** Functional callback adapter for {@link HardwareKeyboardController}. */
public final class HardwareKeyboardHostCallbacks implements HardwareKeyboardController.Host {
    private final Supplier<ShellInputView> shellInputView;
    private final InputMethodManager inputMethodManager;
    private final BooleanSupplier currentImeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final Runnable followShellLiveBottom;
    private final Runnable refreshScrollOverlay;
    private final Consumer<String> updateStatus;

    public HardwareKeyboardHostCallbacks(
            Supplier<ShellInputView> shellInputView,
            InputMethodManager inputMethodManager,
            BooleanSupplier currentImeVisible,
            Consumer<Boolean> setImeVisible,
            Runnable followShellLiveBottom,
            Runnable refreshScrollOverlay,
            Consumer<String> updateStatus) {
        this.shellInputView = shellInputView;
        this.inputMethodManager = inputMethodManager;
        this.currentImeVisible = currentImeVisible;
        this.setImeVisible = setImeVisible;
        this.followShellLiveBottom = followShellLiveBottom;
        this.refreshScrollOverlay = refreshScrollOverlay;
        this.updateStatus = updateStatus;
    }

    @Override
    public ShellInputView shellInputView() {
        return shellInputView.get();
    }

    @Override
    public InputMethodManager inputMethodManager() {
        return inputMethodManager;
    }

    @Override
    public boolean currentImeVisible() {
        return currentImeVisible.getAsBoolean();
    }

    @Override
    public void setImeVisible(boolean visible) {
        setImeVisible.accept(visible);
    }

    @Override
    public boolean nativeLoaded() {
        return NativeBridge.nativeLoaded();
    }

    @Override
    public void followShellLiveBottom() {
        followShellLiveBottom.run();
    }

    @Override
    public void refreshScrollOverlay() {
        refreshScrollOverlay.run();
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }
}
