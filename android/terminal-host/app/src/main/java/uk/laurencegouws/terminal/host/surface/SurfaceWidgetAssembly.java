package uk.laurencegouws.terminal.host.surface;

import android.view.SurfaceHolder;

import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.host.ui.UiFactory;
import uk.laurencegouws.terminal.selection.SelectionController;

/** Owns surface + widget controller assembly for the activity wiring layer. */
public final class SurfaceWidgetAssembly {
    /** Activity callbacks required to assemble surface/widget host wiring. */
    public interface Host {
        android.os.Handler handler();

        android.widget.FrameLayout productSurfaceContainer();

        boolean debugViewEnabled();

        boolean currentImeVisible();

        boolean shouldRunFrameLoop();

        void refreshScrollOverlay();

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void callNative(String event, long seq);

        void callNativeWithSurfaceState(
                String event,
                long seq,
                uk.laurencegouws.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot state);

        uk.laurencegouws.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();

        void handleShellStateEvent(String statusLabel);

        void installSurfaceGestureHost(android.view.SurfaceView surfaceView);

        void reinstallSurfaceCallback(android.view.SurfaceView surfaceView, SurfaceHolder.Callback2 callback);

        SurfaceHolder.Callback2 surfaceCallback();

        int productViewportHeightPx();

        void reevaluateFrameLoop();
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
            SelectionController selectionController,
            GestureStateController GestureStateController,
            Host host) {
        final SurfaceWidgetController[] widgetRef = new SurfaceWidgetController[1];
        final SurfaceBridge surfaceHostBridge = new SurfaceBridge(
                new SurfaceCallbacks(
                        host.handler(),
                        host.productSurfaceContainer(),
                        new SurfaceLifecycleCallbacks(
                                host::debugViewEnabled,
                                host::currentImeVisible,
                                host::shouldRunFrameLoop,
                                host::refreshScrollOverlay,
                                host::appendEvent,
                                host::updateStatus,
                                host::callNative,
                                host::callNativeWithSurfaceState,
                                host::currentSurfaceStateSnapshot,
                                host::handleShellStateEvent,
                                host::installSurfaceGestureHost,
                                host::reinstallSurfaceCallback,
                                () -> widgetRef[0])));
        final SurfaceController surfaceHostController = new SurfaceController(surfaceHostBridge);
        final SurfaceWidgetController surfaceWidgetController = UiFactory.createSurfaceWidgetController(
                surfaceHostController,
                selectionController,
                GestureStateController,
                new SurfaceWidgetCallbacks(
                        host::productViewportHeightPx,
                        host::appendEvent,
                        host::refreshScrollOverlay,
                        host::reevaluateFrameLoop));
        widgetRef[0] = surfaceWidgetController;
        return new Result(surfaceHostBridge, surfaceHostController, surfaceWidgetController);
    }
}
