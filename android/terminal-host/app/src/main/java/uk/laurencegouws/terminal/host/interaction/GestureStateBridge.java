package uk.laurencegouws.terminal.host.interaction;

import uk.laurencegouws.terminal.gesture.GestureStateController;

/**
 * Adapts activity-owned callbacks to {@link GestureStateController.Host}.
 */
public final class GestureStateBridge implements GestureStateController.Host {
    /** Activity callbacks required by gesture-state policy. */
    public interface Callbacks {
        boolean nativeLoaded();

        int visibleRows();

        int viewportHeightPx();

        int scrollbackCount();

        int scrollbackOffset();

        int setScrollbackOffset(int offsetRows);

        int followLiveBottom();

        int applyPinchZoom(float scaleFactor);

        int setPinchActive(boolean active);

        void refreshScrollOverlay();

        void reevaluateFrameLoop();
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
    public int applyPinchZoom(float scaleFactor) {
        return callbacks.applyPinchZoom(scaleFactor);
    }

    @Override
    public int setPinchActive(boolean active) {
        return callbacks.setPinchActive(active);
    }

    @Override
    public void refreshScrollOverlay() {
        callbacks.refreshScrollOverlay();
    }

    @Override
    public void reevaluateFrameLoop() {
        callbacks.reevaluateFrameLoop();
    }
}
