package dev.zide.terminal.host;

import android.app.Activity;
import android.os.Handler;
import android.widget.FrameLayout;

import dev.zide.terminal.TerminalNativeBridge;
import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.selection.TerminalSelectionController;

/** Owns selection + gesture interaction controller assembly for activity wiring. */
public final class TerminalInteractionAssembly {
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

    private TerminalInteractionAssembly() {
    }

    public static Result assemble(Host host) {
        final TerminalSelectionController selectionController = TerminalInteractionHostFactory.createSelectionController(
                host.activity(),
                host.productSurfaceContainer(),
                host::productViewportWidthPx,
                host::productViewportHeightPx,
                host::stopScrollbackFling,
                host::refreshProductScrollOverlay,
                host::reevaluateProductFrameLoop,
                host::appendEvent,
                host::nativeLoaded,
                TerminalNativeBridge::nativeBeginShellWordSelectionAtVisibleCellBridge,
                TerminalNativeBridge::nativeExtendShellSelectionGestureToVisibleCellBridge,
                TerminalNativeBridge::nativeFinishShellSelectionGestureBridge,
                TerminalNativeBridge::nativeClearShellSelectionBridge,
                TerminalNativeBridge::nativeUpdateShellSelectionStartAtVisibleCellBridge,
                TerminalNativeBridge::nativeUpdateShellSelectionEndAtVisibleCellBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionActiveBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionRectLeftBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionRectTopBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionRectRightBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionRectBottomBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionStartRectLeftBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionStartRectTopBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionStartRectRightBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionStartRectBottomBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionEndRectLeftBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionEndRectTopBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionEndRectRightBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionEndRectBottomBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionTextBytesBridge,
                TerminalNativeBridge::nativeCurrentShellVisibleRowsBridge,
                TerminalNativeBridge::nativeCurrentShellVisibleColsBridge,
                TerminalNativeBridge::nativeCurrentShellScrollbackCountBridge,
                TerminalNativeBridge::nativeCurrentShellScrollbackOffsetBridge,
                TerminalNativeBridge::nativeSetShellScrollbackOffsetBridge,
                TerminalNativeBridge::nativeFollowShellLiveBottomBridge);
        selectionController.install();

        final TerminalGestureStateController terminalGestureStateController =
                TerminalInteractionHostFactory.createGestureStateController(
                        host.activity(),
                        host.handler(),
                        host::nativeLoaded,
                        TerminalNativeBridge::nativeCurrentShellVisibleRowsBridge,
                        host::productViewportHeightPx,
                        TerminalNativeBridge::nativeCurrentShellScrollbackCountBridge,
                        TerminalNativeBridge::nativeCurrentShellScrollbackOffsetBridge,
                        TerminalNativeBridge::nativeSetShellScrollbackOffsetBridge,
                        TerminalNativeBridge::nativeFollowShellLiveBottomBridge,
                        TerminalNativeBridge::nativeApplyTerminalPinchZoomBridge,
                        TerminalNativeBridge::nativeSetTerminalPinchActiveBridge,
                        host::refreshProductScrollOverlay,
                        host::reevaluateProductFrameLoop);
        return new Result(selectionController, terminalGestureStateController);
    }
}
