package uk.laurencegouws.terminal.input;

import android.view.inputmethod.InputMethodManager;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.host.ui.HostImeStateAccess;

/** Functional callback adapter for {@link HardwareKeyboardController}. */
public final class HardwareKeyboardHostCallbacks implements HardwareKeyboardController.Host {
    private final Supplier<ShellInputView> shellInputView;
    private final InputMethodManager inputMethodManager;
    private final HostImeStateAccess hostImeState;
    private final Runnable followShellLiveBottom;
    private final Runnable refreshScrollOverlay;
    private final Consumer<String> updateStatus;

    public HardwareKeyboardHostCallbacks(
            Supplier<ShellInputView> shellInputView,
            InputMethodManager inputMethodManager,
            HostImeStateAccess hostImeState,
            Runnable followShellLiveBottom,
            Runnable refreshScrollOverlay,
            Consumer<String> updateStatus) {
        this.shellInputView = shellInputView;
        this.inputMethodManager = inputMethodManager;
        this.hostImeState = hostImeState;
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
        return hostImeState.imeVisible();
    }

    @Override
    public void setImeVisible(boolean visible) {
        hostImeState.setImeVisible(visible);
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
