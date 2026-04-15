package uk.laurencegouws.terminal.host.interaction;

import android.content.Context;
import android.widget.FrameLayout;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.gesture.TerminalGestureStateController;
import uk.laurencegouws.terminal.gesture.TerminalGestureStateControllerFactory;
import uk.laurencegouws.terminal.selection.TerminalSelectionController;
import uk.laurencegouws.terminal.selection.TerminalSelectionControllerFactory;

/**
 * Selection and gesture interaction assembly helpers.
 *
 * <p>Owns interaction-specific controller construction so generic host assembly
 * remains focused on lifecycle/runtime/surface wiring.
 */
public final class InteractionFactory {
    private InteractionFactory() {
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
            BooleanSupplier nativeLoaded) {
        return TerminalSelectionControllerFactory.create(
                context,
                productSurfaceContainer,
                new SelectionCallbacks(
                        productViewportWidthPx,
                        productViewportHeightPx,
                        stopScrollbackFling,
                        refreshProductScrollOverlay,
                        reevaluateProductFrameLoop,
                        appendEvent,
                        nativeLoaded));
    }

    public static TerminalGestureStateController createGestureStateController(
            Context context,
            android.os.Handler handler,
            BooleanSupplier nativeLoaded,
            IntSupplier viewportHeightPx,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop) {
        return TerminalGestureStateControllerFactory.create(
                context,
                handler,
                new GestureStateCallbacks(
                        nativeLoaded,
                        viewportHeightPx,
                        refreshProductScrollOverlay,
                        reevaluateProductFrameLoop));
    }
}
