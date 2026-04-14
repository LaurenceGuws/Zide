package dev.zide.terminal.host.surface;

import android.view.SurfaceHolder;

import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.host.ui.UiFactory;
import dev.zide.terminal.selection.TerminalSelectionController;

/** Owns surface + widget controller assembly for the activity wiring layer. */
public final class SurfaceWidgetAssembly {
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
        public final SurfaceBridge surfaceHostBridge;
        public final SurfaceController surfaceHostController;
        public final SurfaceWidgetController surfaceWidgetController;

        private Result(
                SurfaceBridge surfaceHostBridge,
                SurfaceController surfaceHostController,
                SurfaceWidgetController surfaceWidgetController) {
            this.surfaceHostBridge = surfaceHostBridge;
            this.surfaceHostController = surfaceHostController;
            this.surfaceWidgetController = surfaceWidgetController;
        }
    }

    private SurfaceWidgetAssembly() {
    }

    public static Result assemble(
            TerminalSelectionController selectionController,
            TerminalGestureStateController terminalGestureStateController,
            Host host) {
        final SurfaceWidgetController[] widgetRef = new SurfaceWidgetController[1];
        final SurfaceBridge surfaceHostBridge = SurfaceFactory.createSurfaceHostBridge(
                SurfaceFactory.createSurfaceHostCallbacks(
                        host.handler(),
                        host.productSurfaceContainer(),
                        SurfaceFactory.createSurfaceHostLifecycleCallbacks(
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
        final SurfaceController surfaceHostController = new SurfaceController(surfaceHostBridge);
        final SurfaceWidgetController surfaceWidgetController = UiFactory.createSurfaceWidgetController(
                surfaceHostController,
                selectionController,
                terminalGestureStateController,
                new SurfaceWidgetCallbacks(
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
