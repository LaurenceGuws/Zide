package uk.laurencegouws.terminal.input;

import android.view.inputmethod.InputMethodManager;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.TerminalNativeBridge;

/** Functional callback adapter for {@link TerminalHardwareKeyboardController}. */
public final class TerminalHardwareKeyboardHostCallbacks implements TerminalHardwareKeyboardController.Host {
    private final Supplier<ShellInputView> shellInputView;
    private final Supplier<InputMethodManager> inputMethodManager;
    private final BooleanSupplier currentImeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final Runnable followShellLiveBottom;
    private final Runnable refreshProductScrollOverlay;
    private final Consumer<String> updateStatus;

    public TerminalHardwareKeyboardHostCallbacks(
            Supplier<ShellInputView> shellInputView,
            Supplier<InputMethodManager> inputMethodManager,
            BooleanSupplier currentImeVisible,
            Consumer<Boolean> setImeVisible,
            Runnable followShellLiveBottom,
            Runnable refreshProductScrollOverlay,
            Consumer<String> updateStatus) {
        this.shellInputView = shellInputView;
        this.inputMethodManager = inputMethodManager;
        this.currentImeVisible = currentImeVisible;
        this.setImeVisible = setImeVisible;
        this.followShellLiveBottom = followShellLiveBottom;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.updateStatus = updateStatus;
    }

    @Override
    public ShellInputView shellInputView() {
        return shellInputView.get();
    }

    @Override
    public InputMethodManager inputMethodManager() {
        return inputMethodManager.get();
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
        return TerminalNativeBridge.nativeLoaded();
    }

    @Override
    public void followShellLiveBottom() {
        followShellLiveBottom.run();
    }

    @Override
    public void refreshProductScrollOverlay() {
        refreshProductScrollOverlay.run();
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }
}
