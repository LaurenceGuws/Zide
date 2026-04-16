package uk.laurencegouws.terminal.host.interaction;

import android.app.Activity;
import android.os.Handler;
import android.widget.FrameLayout;

import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.selection.SelectionController;

/** Owns selection + gesture interaction controller assembly for activity wiring. */
public final class InteractionAssembly {
    /** Activity callbacks required for interaction assembly. */
    public interface Host {
        Activity activity();

        Handler handler();

        FrameLayout productSurfaceContainer();

        int productViewportWidthPx();

        int productViewportHeightPx();

        void stopScrollbackFling();

        void refreshProductScrollOverlay();

        void reevaluateProductFrameLoop();

        void appendEvent(String message);
    }

    /** Immutable assembled interaction controller result. */
    public static final class Result {
        public final SelectionController selectionController;
        public final GestureStateController GestureStateController;

        private Result(
                SelectionController selectionController,
                GestureStateController GestureStateController) {
            this.selectionController = selectionController;
            this.GestureStateController = GestureStateController;
        }
    }

    private InteractionAssembly() {
    }

    public static Result assemble(Host host) {
        final SelectionController selectionController = InteractionFactory.createSelectionController(
                host.activity(),
                host.productSurfaceContainer(),
                host::productViewportWidthPx,
                host::productViewportHeightPx,
                host::stopScrollbackFling,
                host::refreshProductScrollOverlay,
                host::reevaluateProductFrameLoop,
                host::appendEvent);
        selectionController.install();

        final GestureStateController GestureStateController =
                InteractionFactory.createGestureStateController(
                        host.activity(),
                        host.handler(),
                        host::productViewportHeightPx,
                        host::refreshProductScrollOverlay,
                        host::reevaluateProductFrameLoop);
        return new Result(selectionController, GestureStateController);
    }
}
