package dev.zide.terminal.host.ui;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;

/** Functional callback adapter for {@link ViewModeController}. */
public final class ViewModeCallbacks implements ViewModeController.Host {
    private final BooleanSupplier debugViewEnabled;
    private final Consumer<Boolean> setDebugViewEnabled;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Runnable closeSidebar;
    private final Consumer<String> notifyVisibleViewport;
    private final Runnable refreshProductScrollOverlay;
    private final Runnable refreshShellStateForDebugView;

    public ViewModeCallbacks(
            BooleanSupplier debugViewEnabled,
            Consumer<Boolean> setDebugViewEnabled,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Runnable closeSidebar,
            Consumer<String> notifyVisibleViewport,
            Runnable refreshProductScrollOverlay,
            Runnable refreshShellStateForDebugView) {
        this.debugViewEnabled = debugViewEnabled;
        this.setDebugViewEnabled = setDebugViewEnabled;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.closeSidebar = closeSidebar;
        this.notifyVisibleViewport = notifyVisibleViewport;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.refreshShellStateForDebugView = refreshShellStateForDebugView;
    }

    @Override
    public boolean debugViewEnabled() {
        return debugViewEnabled.getAsBoolean();
    }

    @Override
    public void setDebugViewEnabled(boolean enabled) {
        setDebugViewEnabled.accept(enabled);
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }

    @Override
    public void closeSidebar() {
        closeSidebar.run();
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        notifyVisibleViewport.accept(reason);
    }

    @Override
    public void refreshProductScrollOverlay() {
        refreshProductScrollOverlay.run();
    }

    @Override
    public void refreshShellStateForDebugView() {
        refreshShellStateForDebugView.run();
    }
}
