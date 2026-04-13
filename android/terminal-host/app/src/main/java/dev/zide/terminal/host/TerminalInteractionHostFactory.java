package dev.zide.terminal.host;

import android.content.Context;
import android.widget.FrameLayout;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.gesture.TerminalGestureStateControllerFactory;
import dev.zide.terminal.selection.TerminalSelectionController;
import dev.zide.terminal.selection.TerminalSelectionControllerFactory;

/**
 * Selection and gesture interaction assembly helpers.
 *
 * <p>Owns interaction-specific controller construction so generic host assembly
 * remains focused on lifecycle/runtime/surface wiring.
 */
public final class TerminalInteractionHostFactory {
    private TerminalInteractionHostFactory() {
    }

    public static TerminalSelectionController createSelectionController(
            Context context,
            FrameLayout productSurfaceContainer,
            IntSupplier productViewportWidthPx,
            IntSupplier productViewportHeightPx,
            Runnable stopScrollbackFling,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop,
            Consumer<String> appendEvent,
            BooleanSupplier nativeLoaded,
            java.util.function.IntBinaryOperator beginWordSelectionAtVisibleCell,
            java.util.function.IntBinaryOperator extendSelectionGestureToVisibleCell,
            IntSupplier finishSelectionGesture,
            IntSupplier clearSelection,
            java.util.function.IntBinaryOperator updateSelectionStartAtVisibleCell,
            java.util.function.IntBinaryOperator updateSelectionEndAtVisibleCell,
            BooleanSupplier currentSelectionActive,
            IntSupplier currentSelectionRectLeft,
            IntSupplier currentSelectionRectTop,
            IntSupplier currentSelectionRectRight,
            IntSupplier currentSelectionRectBottom,
            IntSupplier currentSelectionStartRectLeft,
            IntSupplier currentSelectionStartRectTop,
            IntSupplier currentSelectionStartRectRight,
            IntSupplier currentSelectionStartRectBottom,
            IntSupplier currentSelectionEndRectLeft,
            IntSupplier currentSelectionEndRectTop,
            IntSupplier currentSelectionEndRectRight,
            IntSupplier currentSelectionEndRectBottom,
            Supplier<byte[]> currentSelectionTextBytes,
            IntSupplier currentVisibleRows,
            IntSupplier currentVisibleCols,
            IntSupplier currentScrollbackCount,
            IntSupplier currentScrollbackOffset,
            java.util.function.IntUnaryOperator setShellScrollbackOffset,
            IntSupplier followShellLiveBottom) {
        return TerminalSelectionControllerFactory.create(
                context,
                productSurfaceContainer,
                new TerminalSelectionFactoryHostCallbacks(
                        productViewportWidthPx,
                        productViewportHeightPx,
                        stopScrollbackFling,
                        refreshProductScrollOverlay,
                        reevaluateProductFrameLoop,
                        appendEvent,
                        nativeLoaded,
                        beginWordSelectionAtVisibleCell,
                        extendSelectionGestureToVisibleCell,
                        finishSelectionGesture,
                        clearSelection,
                        updateSelectionStartAtVisibleCell,
                        updateSelectionEndAtVisibleCell,
                        currentSelectionActive,
                        currentSelectionRectLeft,
                        currentSelectionRectTop,
                        currentSelectionRectRight,
                        currentSelectionRectBottom,
                        currentSelectionStartRectLeft,
                        currentSelectionStartRectTop,
                        currentSelectionStartRectRight,
                        currentSelectionStartRectBottom,
                        currentSelectionEndRectLeft,
                        currentSelectionEndRectTop,
                        currentSelectionEndRectRight,
                        currentSelectionEndRectBottom,
                        currentSelectionTextBytes,
                        currentVisibleRows,
                        currentVisibleCols,
                        currentScrollbackCount,
                        currentScrollbackOffset,
                        setShellScrollbackOffset,
                        followShellLiveBottom));
    }

    public static TerminalGestureStateController createGestureStateController(
            Context context,
            android.os.Handler handler,
            BooleanSupplier nativeLoaded,
            IntSupplier visibleRows,
            IntSupplier viewportHeightPx,
            IntSupplier scrollbackCount,
            IntSupplier scrollbackOffset,
            java.util.function.IntUnaryOperator setScrollbackOffset,
            IntSupplier followLiveBottom,
            TerminalGestureStateFactoryHostCallbacks.FloatToIntFunction applyTerminalPinchZoom,
            TerminalGestureStateFactoryHostCallbacks.BooleanToIntFunction setTerminalPinchActive,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop) {
        return TerminalGestureStateControllerFactory.create(
                context,
                handler,
                new TerminalGestureStateFactoryHostCallbacks(
                        nativeLoaded,
                        visibleRows,
                        viewportHeightPx,
                        scrollbackCount,
                        scrollbackOffset,
                        setScrollbackOffset,
                        followLiveBottom,
                        applyTerminalPinchZoom,
                        setTerminalPinchActive,
                        refreshProductScrollOverlay,
                        reevaluateProductFrameLoop));
    }
}
