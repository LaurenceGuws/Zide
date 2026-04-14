package uk.laurencegouws.terminal.host.interaction;

import java.util.function.BooleanSupplier;
import java.util.function.IntSupplier;
import java.util.function.IntUnaryOperator;

import uk.laurencegouws.terminal.gesture.TerminalGestureStateControllerFactory;

/** Functional callback adapter for {@link TerminalGestureStateControllerFactory}. */
public final class GestureStateCallbacks implements TerminalGestureStateControllerFactory.Host {
    private final BooleanSupplier nativeLoaded;
    private final IntSupplier visibleRows;
    private final IntSupplier viewportHeightPx;
    private final IntSupplier scrollbackCount;
    private final IntSupplier scrollbackOffset;
    private final IntUnaryOperator setScrollbackOffset;
    private final IntSupplier followLiveBottom;
    private final FloatToIntFunction applyTerminalPinchZoom;
    private final BooleanToIntFunction setTerminalPinchActive;
    private final Runnable refreshProductScrollOverlay;
    private final Runnable reevaluateProductFrameLoop;

    /** Functional callback for float input with integer status output. */
    public interface FloatToIntFunction {
        int apply(float value);
    }

    /** Functional callback for boolean input with integer status output. */
    public interface BooleanToIntFunction {
        int apply(boolean value);
    }

    public GestureStateCallbacks(
            BooleanSupplier nativeLoaded,
            IntSupplier visibleRows,
            IntSupplier viewportHeightPx,
            IntSupplier scrollbackCount,
            IntSupplier scrollbackOffset,
            IntUnaryOperator setScrollbackOffset,
            IntSupplier followLiveBottom,
            FloatToIntFunction applyTerminalPinchZoom,
            BooleanToIntFunction setTerminalPinchActive,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop) {
        this.nativeLoaded = nativeLoaded;
        this.visibleRows = visibleRows;
        this.viewportHeightPx = viewportHeightPx;
        this.scrollbackCount = scrollbackCount;
        this.scrollbackOffset = scrollbackOffset;
        this.setScrollbackOffset = setScrollbackOffset;
        this.followLiveBottom = followLiveBottom;
        this.applyTerminalPinchZoom = applyTerminalPinchZoom;
        this.setTerminalPinchActive = setTerminalPinchActive;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public int visibleRows() {
        return visibleRows.getAsInt();
    }

    @Override
    public int viewportHeightPx() {
        return viewportHeightPx.getAsInt();
    }

    @Override
    public int scrollbackCount() {
        return scrollbackCount.getAsInt();
    }

    @Override
    public int scrollbackOffset() {
        return scrollbackOffset.getAsInt();
    }

    @Override
    public int setScrollbackOffset(int offsetRows) {
        return setScrollbackOffset.applyAsInt(offsetRows);
    }

    @Override
    public int followLiveBottom() {
        return followLiveBottom.getAsInt();
    }

    @Override
    public int applyTerminalPinchZoom(float scaleFactor) {
        return applyTerminalPinchZoom.apply(scaleFactor);
    }

    @Override
    public int setTerminalPinchActive(boolean active) {
        return setTerminalPinchActive.apply(active);
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
