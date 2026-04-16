package uk.laurencegouws.terminal.host.interaction;

import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.gesture.GestureStateControllerFactory;

/** Functional callback adapter for {@link GestureStateControllerFactory}. */
public final class GestureStateCallbacks implements GestureStateControllerFactory.Host {
    private final IntSupplier viewportHeightPx;
    private final Runnable refreshProductScrollOverlay;
    private final Runnable reevaluateProductFrameLoop;

    public GestureStateCallbacks(
            IntSupplier viewportHeightPx,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop) {
        this.viewportHeightPx = viewportHeightPx;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
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
    public int applyTerminalPinchZoom(float scaleFactor) {
        return NativeBridge.nativeApplyTerminalPinchZoomBridge(scaleFactor);
    }

    @Override
    public int setTerminalPinchActive(boolean active) {
        return NativeBridge.nativeSetTerminalPinchActiveBridge(active);
    }

    @Override
    public void refreshProductScrollOverlay() {
        refreshProductScrollOverlay.run();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        reevaluateProductFrameLoop.run();
    }
}
