package uk.laurencegouws.terminal.host.interaction;

import android.content.Context;
import android.os.Handler;
import android.widget.FrameLayout;

import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.host.ui.TerminalWidgetSlotId;
import uk.laurencegouws.terminal.selection.SelectionController;

/** Owns selection + gesture interaction controller assembly for activity wiring. */
public final class InteractionAssembly {
    /** Harness callbacks required for interaction assembly. */
    public interface Host {
        /**
         * Terminal widget slot for this assembly (must be {@link TerminalWidgetSlotId#PRIMARY}
         * for current product wiring; reserved enum values are not active until host policy
         * defines them).
         */
        TerminalWidgetSlotId terminalWidgetSlot();

        Context harnessContext();

        Handler handler();

        FrameLayout productSurfaceContainer();

        int productViewportWidthPx();

        int productViewportHeightPx();

        void stopScrollbackFling();

        void refreshScrollOverlay();

        void reevaluateFrameLoop();

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
        TerminalWidgetSlotId.checkActiveProductTerminalSlot(host.terminalWidgetSlot());
        final SelectionController selectionController = InteractionFactory.createSelectionController(
                host.harnessContext(),
                host.productSurfaceContainer(),
                host::productViewportWidthPx,
                host::productViewportHeightPx,
                host::stopScrollbackFling,
                host::refreshScrollOverlay,
                host::reevaluateFrameLoop,
                host::appendEvent);
        selectionController.install();

        final GestureStateController GestureStateController =
                InteractionFactory.createGestureStateController(
                        host.harnessContext(),
                        host.handler(),
                        host::productViewportHeightPx,
                        host::refreshScrollOverlay,
                        host::reevaluateFrameLoop);
        return new Result(selectionController, GestureStateController);
    }
}
