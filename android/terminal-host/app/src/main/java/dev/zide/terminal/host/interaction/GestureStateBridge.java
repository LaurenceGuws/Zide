package dev.zide.terminal.host.interaction;

import dev.zide.terminal.gesture.TerminalGestureStateController;

/**
 * Adapts activity-owned callbacks to {@link TerminalGestureStateController.Host}.
 */
public final class GestureStateBridge implements TerminalGestureStateController.Host {
    /** Activity callbacks required by gesture-state policy. */
    public interface Callbacks {
        boolean nativeLoaded();

        int visibleRows();

        int viewportHeightPx();

        int scrollbackCount();

        int scrollbackOffset();

        int setScrollbackOffset(int offsetRows);

        int followLiveBottom();

        int applyTerminalPinchZoom(float scaleFactor);

        int setTerminalPinchActive(boolean active);

        void refreshProductScrollOverlay();

        void reevaluateProductFrameLoop();
    }

    private final Callbacks callbacks;

    public GestureStateBridge(Callbacks callbacks) {
        this.callbacks = callbacks;
    }

    @Override
    public boolean nativeLoaded() {
        return callbacks.nativeLoaded();
    }

    @Override
    public int visibleRows() {
        return callbacks.visibleRows();
    }

    @Override
    public int viewportHeightPx() {
        return callbacks.viewportHeightPx();
    }

    @Override
    public int scrollbackCount() {
        return callbacks.scrollbackCount();
    }

    @Override
    public int scrollbackOffset() {
        return callbacks.scrollbackOffset();
    }

    @Override
    public int setScrollbackOffset(int offsetRows) {
        return callbacks.setScrollbackOffset(offsetRows);
    }

    @Override
    public int followLiveBottom() {
        return callbacks.followLiveBottom();
    }

    @Override
    public int applyTerminalPinchZoom(float scaleFactor) {
        return callbacks.applyTerminalPinchZoom(scaleFactor);
    }

    @Override
    public int setTerminalPinchActive(boolean active) {
        return callbacks.setTerminalPinchActive(active);
    }

    @Override
    public void refreshProductScrollOverlay() {
        callbacks.refreshProductScrollOverlay();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        callbacks.reevaluateProductFrameLoop();
    }
}
