package uk.laurencegouws.terminal.host.interaction;

import android.content.Context;
import android.widget.FrameLayout;

import java.util.function.Consumer;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.gesture.GestureStateControllerFactory;
import uk.laurencegouws.terminal.selection.SelectionController;
import uk.laurencegouws.terminal.selection.SelectionControllerFactory;

/**
 * Selection and gesture interaction assembly helpers.
 *
 * <p>Owns interaction-specific controller construction so generic host assembly
 * remains focused on lifecycle/runtime/surface wiring.
 */
public final class InteractionFactory {
    private InteractionFactory() {
    }

    public static SelectionController createSelectionController(
            Context context,
            FrameLayout productSurfaceContainer,
            IntSupplier productViewportWidthPx,
            IntSupplier productViewportHeightPx,
            Runnable stopScrollbackFling,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop,
            Consumer<String> appendEvent) {
        return SelectionControllerFactory.create(
                context,
                productSurfaceContainer,
                new SelectionCallbacks(
                        productViewportWidthPx,
                        productViewportHeightPx,
                        stopScrollbackFling,
                        refreshProductScrollOverlay,
                        reevaluateProductFrameLoop,
                        appendEvent));
    }

    public static GestureStateController createGestureStateController(
            Context context,
            android.os.Handler handler,
            IntSupplier viewportHeightPx,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop) {
        return GestureStateControllerFactory.create(
                context,
                handler,
                new GestureStateCallbacks(
                        viewportHeightPx,
                        refreshProductScrollOverlay,
                        reevaluateProductFrameLoop));
    }
}
