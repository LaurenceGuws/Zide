package uk.laurencegouws.terminal.host.interaction;

import android.app.Activity;
import android.os.Handler;
import android.widget.FrameLayout;

import uk.laurencegouws.terminal.TerminalNativeBridge;
import uk.laurencegouws.terminal.gesture.TerminalGestureStateController;
import uk.laurencegouws.terminal.selection.TerminalSelectionController;

/** Owns selection + gesture interaction controller assembly for activity wiring. */
public final class InteractionAssembly {
    /** Activity callbacks required for interaction assembly. */
    public interface Host {
        Activity activity();

        Handler handler();

        FrameLayout productSurfaceContainer();

        int productViewportWidthPx();

        int productViewportHeightPx();

        boolean nativeLoaded();

        void stopScrollbackFling();

        void refreshProductScrollOverlay();

        void reevaluateProductFrameLoop();

        void appendEvent(String message);
    }

    /** Immutable assembled interaction controller result. */
    public static final class Result {
        public final TerminalSelectionController selectionController;
        public final TerminalGestureStateController terminalGestureStateController;

        private Result(
                TerminalSelectionController selectionController,
                TerminalGestureStateController terminalGestureStateController) {
            this.selectionController = selectionController;
            this.terminalGestureStateController = terminalGestureStateController;
        }
    }

    private InteractionAssembly() {
    }

    public static Result assemble(Host host) {
        final TerminalSelectionController selectionController = InteractionFactory.createSelectionController(
                host.activity(),
                host.productSurfaceContainer(),
                host::productViewportWidthPx,
                host::productViewportHeightPx,
                host::stopScrollbackFling,
                host::refreshProductScrollOverlay,
                host::reevaluateProductFrameLoop,
                host::appendEvent,
                host::nativeLoaded,
                TerminalNativeBridge::nativeBeginSelectionWordAtVisibleCellBridge,
                TerminalNativeBridge::nativeExtendSelectionGestureToVisibleCellBridge,
                TerminalNativeBridge::nativeFinishSelectionGestureBridge,
                TerminalNativeBridge::nativeClearSelectionBridge,
                TerminalNativeBridge::nativeUpdateSelectionStartAtVisibleCellBridge,
                TerminalNativeBridge::nativeUpdateSelectionEndAtVisibleCellBridge,
                TerminalNativeBridge::nativeCurrentSelectionActiveBridge,
                TerminalNativeBridge::nativeCurrentSelectionRectLeftBridge,
                TerminalNativeBridge::nativeCurrentSelectionRectTopBridge,
                TerminalNativeBridge::nativeCurrentSelectionRectRightBridge,
                TerminalNativeBridge::nativeCurrentSelectionRectBottomBridge,
                TerminalNativeBridge::nativeCurrentSelectionStartRectLeftBridge,
                TerminalNativeBridge::nativeCurrentSelectionStartRectTopBridge,
                TerminalNativeBridge::nativeCurrentSelectionStartRectRightBridge,
                TerminalNativeBridge::nativeCurrentSelectionStartRectBottomBridge,
                TerminalNativeBridge::nativeCurrentSelectionEndRectLeftBridge,
                TerminalNativeBridge::nativeCurrentSelectionEndRectTopBridge,
                TerminalNativeBridge::nativeCurrentSelectionEndRectRightBridge,
                TerminalNativeBridge::nativeCurrentSelectionEndRectBottomBridge,
                TerminalNativeBridge::nativeCurrentSelectionTextBytesBridge,
                TerminalNativeBridge::nativeCurrentSessionVisibleRowsBridge,
                TerminalNativeBridge::nativeCurrentSessionVisibleColsBridge,
                TerminalNativeBridge::nativeCurrentSessionScrollbackCountBridge,
                TerminalNativeBridge::nativeCurrentSessionScrollbackOffsetBridge,
                TerminalNativeBridge::nativeSetSessionScrollbackOffsetBridge,
                TerminalNativeBridge::nativeFollowSessionLiveBottomBridge);
        selectionController.install();

        final TerminalGestureStateController terminalGestureStateController =
                InteractionFactory.createGestureStateController(
                        host.activity(),
                        host.handler(),
                        host::nativeLoaded,
                        TerminalNativeBridge::nativeCurrentSessionVisibleRowsBridge,
                        host::productViewportHeightPx,
                        TerminalNativeBridge::nativeCurrentSessionScrollbackCountBridge,
                        TerminalNativeBridge::nativeCurrentSessionScrollbackOffsetBridge,
                        TerminalNativeBridge::nativeSetSessionScrollbackOffsetBridge,
                        TerminalNativeBridge::nativeFollowSessionLiveBottomBridge,
                        TerminalNativeBridge::nativeApplyTerminalPinchZoomBridge,
                        TerminalNativeBridge::nativeSetTerminalPinchActiveBridge,
                        host::refreshProductScrollOverlay,
                        host::reevaluateProductFrameLoop);
        return new Result(selectionController, terminalGestureStateController);
    }
}
