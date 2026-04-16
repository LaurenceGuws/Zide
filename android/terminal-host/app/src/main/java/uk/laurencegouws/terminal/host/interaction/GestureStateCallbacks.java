package uk.laurencegouws.terminal.host.interaction;

import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.gesture.GestureStateControllerFactory;

/** Functional callback adapter for {@link GestureStateControllerFactory}. */
public final class GestureStateCallbacks implements GestureStateControllerFactory.Host {
    private final IntSupplier viewportHeightPx;
    private final Runnable refreshScrollOverlay;
    private final Runnable reevaluateFrameLoop;

    public GestureStateCallbacks(
            IntSupplier viewportHeightPx,
            Runnable refreshScrollOverlay,
            Runnable reevaluateFrameLoop) {
        this.viewportHeightPx = viewportHeightPx;
        this.refreshScrollOverlay = refreshScrollOverlay;
        this.reevaluateFrameLoop = reevaluateFrameLoop;
    }

    @Override
    public boolean nativeLoaded() {
        return NativeBridge.nativeLoaded();
    }

    @Override
    public int visibleRows() {
        return NativeBridge.nativeCurrentSessionVisibleRowsBridge();
    }

    @Override
    public int viewportHeightPx() {
        return viewportHeightPx.getAsInt();
    }

    @Override
    public int scrollbackCount() {
        return NativeBridge.nativeCurrentSessionScrollbackCountBridge();
    }

    @Override
    public int scrollbackOffset() {
        return NativeBridge.nativeCurrentSessionScrollbackOffsetBridge();
    }

    @Override
    public int setScrollbackOffset(int offsetRows) {
        return NativeBridge.nativeSetSessionScrollbackOffsetBridge(offsetRows);
    }

    @Override
    public int followLiveBottom() {
        return NativeBridge.nativeFollowSessionLiveBottomBridge();
    }

    @Override
    public int applyPinchZoom(float scaleFactor) {
        return NativeBridge.nativeApplyPinchZoomBridge(scaleFactor);
    }

    @Override
    public int setPinchActive(boolean active) {
        return NativeBridge.nativeSetPinchActiveBridge(active);
    }

    @Override
    public void refreshScrollOverlay() {
        refreshScrollOverlay.run();
    }

    @Override
    public void reevaluateFrameLoop() {
        reevaluateFrameLoop.run();
    }
}
