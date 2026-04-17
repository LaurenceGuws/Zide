package uk.laurencegouws.terminal.host.ui;

import java.util.function.Consumer;

/** Functional callback adapter for {@link ViewModeController}. */
public final class ViewModeCallbacks implements ViewModeController.Host {
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Consumer<String> notifyVisibleViewport;
    private final Runnable refreshScrollOverlay;

    public ViewModeCallbacks(
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Consumer<String> notifyVisibleViewport,
            Runnable refreshScrollOverlay) {
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.notifyVisibleViewport = notifyVisibleViewport;
        this.refreshScrollOverlay = refreshScrollOverlay;
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
    public void notifyVisibleViewport(String reason) {
        notifyVisibleViewport.accept(reason);
    }

    @Override
    public void refreshScrollOverlay() {
        refreshScrollOverlay.run();
    }
}
