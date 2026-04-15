package uk.laurencegouws.terminal.host.interaction;

import java.util.function.BooleanSupplier;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.TerminalNativeBridge;
import uk.laurencegouws.terminal.gesture.TerminalGestureStateControllerFactory;

/** Functional callback adapter for {@link TerminalGestureStateControllerFactory}. */
public final class GestureStateCallbacks implements TerminalGestureStateControllerFactory.Host {
    private final BooleanSupplier nativeLoaded;
    private final IntSupplier viewportHeightPx;
    private final Runnable refreshProductScrollOverlay;
    private final Runnable reevaluateProductFrameLoop;

    public GestureStateCallbacks(
            BooleanSupplier nativeLoaded,
            IntSupplier viewportHeightPx,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop) {
        this.nativeLoaded = nativeLoaded;
        this.viewportHeightPx = viewportHeightPx;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public int visibleRows() {
        return TerminalNativeBridge.nativeCurrentSessionVisibleRowsBridge();
    }

    @Override
    public int viewportHeightPx() {
        return viewportHeightPx.getAsInt();
    }

    @Override
    public int scrollbackCount() {
        return TerminalNativeBridge.nativeCurrentSessionScrollbackCountBridge();
    }

    @Override
    public int scrollbackOffset() {
        return TerminalNativeBridge.nativeCurrentSessionScrollbackOffsetBridge();
    }

    @Override
    public int setScrollbackOffset(int offsetRows) {
        return TerminalNativeBridge.nativeSetSessionScrollbackOffsetBridge(offsetRows);
    }

    @Override
    public int followLiveBottom() {
        return TerminalNativeBridge.nativeFollowSessionLiveBottomBridge();
    }

    @Override
    public int applyTerminalPinchZoom(float scaleFactor) {
        return TerminalNativeBridge.nativeApplyTerminalPinchZoomBridge(scaleFactor);
    }

    @Override
    public int setTerminalPinchActive(boolean active) {
        return TerminalNativeBridge.nativeSetTerminalPinchActiveBridge(active);
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
