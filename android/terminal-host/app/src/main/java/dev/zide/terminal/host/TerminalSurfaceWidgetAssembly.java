package dev.zide.terminal.host;

import android.view.SurfaceHolder;

import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.selection.TerminalSelectionController;

/** Owns surface + widget controller assembly for the activity wiring layer. */
public final class TerminalSurfaceWidgetAssembly {
    /** Activity callbacks required to assemble surface/widget host wiring. */
    public interface Host {
        android.os.Handler handler();

        android.widget.FrameLayout productSurfaceContainer();

        boolean nativeLoaded();

        boolean debugViewEnabled();

        boolean currentImeVisible();

        boolean shouldRunProductFrameLoop();

        void refreshProductScrollOverlay();

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void callNative(String event, long seq);

        void callNativeWithSurfaceState(
                String event,
                long seq,
                dev.zide.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot state);

        long nativeOnSurfaceAvailableBridge(SurfaceHolder holder, int width, int height);

        long nativeOnSurfaceDestroyedBridge();

        long nativeOnSurfaceRedrawNeededBridge();

        long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible);

        dev.zide.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();

        void handleProductShellStateEvent(String statusLabel);

        void installSurfaceGestureHost(android.view.SurfaceView surfaceView);

        void reinstallSurfaceCallback(android.view.SurfaceView surfaceView, SurfaceHolder.Callback2 callback);

        SurfaceHolder.Callback2 surfaceCallback();

        int nativeSetShellScrollbackOffset(int offsetRows);

        int nativeFollowShellLiveBottom();

        int productViewportHeightPx();

        void reevaluateProductFrameLoop();
    }

    /** Immutable assembled surface/widget construction result. */
    public static final class Result {
        public final TerminalSurfaceHostBridge surfaceHostBridge;
        public final TerminalSurfaceHostController surfaceHostController;
        public final TerminalSurfaceWidgetController surfaceWidgetController;

        private Result(
                TerminalSurfaceHostBridge surfaceHostBridge,
                TerminalSurfaceHostController surfaceHostController,
                TerminalSurfaceWidgetController surfaceWidgetController) {
            this.surfaceHostBridge = surfaceHostBridge;
            this.surfaceHostController = surfaceHostController;
            this.surfaceWidgetController = surfaceWidgetController;
        }
    }

    private TerminalSurfaceWidgetAssembly() {
    }

    public static Result assemble(
            TerminalSelectionController selectionController,
            TerminalGestureStateController terminalGestureStateController,
            Host host) {
        final TerminalSurfaceWidgetController[] widgetRef = new TerminalSurfaceWidgetController[1];
        final TerminalSurfaceHostBridge surfaceHostBridge = TerminalSurfaceHostFactory.createSurfaceHostBridge(
                TerminalSurfaceHostFactory.createSurfaceHostCallbacks(
                        host.handler(),
                        host.productSurfaceContainer(),
                        TerminalSurfaceHostFactory.createSurfaceHostLifecycleCallbacks(
                                host::nativeLoaded,
                                host::debugViewEnabled,
                                host::currentImeVisible,
                                host::shouldRunProductFrameLoop,
                                host::refreshProductScrollOverlay,
                                host::appendEvent,
                                host::updateStatus,
                                host::callNative,
                                host::callNativeWithSurfaceState,
                                host::nativeOnSurfaceAvailableBridge,
                                host::nativeOnSurfaceDestroyedBridge,
                                host::nativeOnSurfaceRedrawNeededBridge,
                                host::nativeOnVisibleViewportBridge,
                                host::currentSurfaceStateSnapshot,
                                host::handleProductShellStateEvent,
                                host::installSurfaceGestureHost,
                                host::reinstallSurfaceCallback,
                                () -> widgetRef[0])));
        final TerminalSurfaceHostController surfaceHostController = new TerminalSurfaceHostController(surfaceHostBridge);
        final TerminalSurfaceWidgetController surfaceWidgetController = TerminalUiHostFactory.createSurfaceWidgetController(
                surfaceHostController,
                selectionController,
                terminalGestureStateController,
                new TerminalSurfaceWidgetHostCallbacks(
                        host::nativeLoaded,
                        host::nativeSetShellScrollbackOffset,
                        host::nativeFollowShellLiveBottom,
                        host::productViewportHeightPx,
                        host::appendEvent,
                        host::refreshProductScrollOverlay,
                        host::reevaluateProductFrameLoop));
        widgetRef[0] = surfaceWidgetController;
        return new Result(surfaceHostBridge, surfaceHostController, surfaceWidgetController);
    }
}
