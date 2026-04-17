package uk.laurencegouws.terminal.host.surface;

import android.view.SurfaceHolder;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.host.ui.UiFactory;
import uk.laurencegouws.terminal.selection.SelectionController;

/** Owns surface + widget controller assembly for the activity wiring layer. */
public final class SurfaceWidgetAssembly {
    /** Activity callbacks required to assemble surface/widget host wiring. */
    public interface Host {
        android.os.Handler handler();

        android.widget.FrameLayout productSurfaceContainer();

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

        void handleShellStateEvent();

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
                        createSurfaceCallbacks(host, widgetRef)));
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

    private static SurfaceCallbacks.Callbacks createSurfaceCallbacks(
            Host host,
            SurfaceWidgetController[] widgetRef) {
        return new SurfaceCallbacks.Callbacks() {
            public boolean currentImeVisible() {
                return host.currentImeVisible();
            }

            @Override
            public boolean shouldRunFrameLoop() {
                return host.shouldRunFrameLoop();
            }

            @Override
            public void refreshScrollOverlay() {
                host.refreshScrollOverlay();
            }

            @Override
            public void appendEvent(String event) {
                host.appendEvent(event);
            }

            @Override
            public void updateStatus(String statusLabel) {
                host.updateStatus(statusLabel);
            }

            @Override
            public void callNative(String event, long seq) {
                host.callNative(event, seq);
            }

            @Override
            public void callNativeWithSurfaceState(
                    String event,
                    long seq,
                    uk.laurencegouws.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot state) {
                host.callNativeWithSurfaceState(event, seq, state);
            }

            @Override
            public long nativeOnSurfaceAvailableBridge(SurfaceHolder holder, int width, int height) {
                return NativeBridge.nativeOnSurfaceAvailableBridge(holder.getSurface(), width, height);
            }

            @Override
            public long nativeOnSurfaceDestroyedBridge() {
                return NativeBridge.nativeOnSurfaceDestroyedBridge();
            }

            @Override
            public long nativeOnSurfaceRedrawNeededBridge() {
                return NativeBridge.nativeOnSurfaceRedrawNeededBridge();
            }

            @Override
            public long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible) {
                return NativeBridge.nativeOnVisibleViewportBridge(width, height, imeVisible);
            }

            @Override
            public uk.laurencegouws.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
                return host.currentSurfaceStateSnapshot();
            }

            @Override
            public void handleShellStateEvent() {
                host.handleShellStateEvent();
            }

            @Override
            public void installSurfaceGestureHost(android.view.SurfaceView nextSurfaceView) {
                host.installSurfaceGestureHost(nextSurfaceView);
            }

            @Override
            public void reinstallSurfaceCallback(android.view.SurfaceView nextSurfaceView, SurfaceHolder.Callback2 callback) {
                host.reinstallSurfaceCallback(nextSurfaceView, callback);
            }

            @Override
            public SurfaceHolder.Callback2 surfaceCallback() {
                return widgetRef[0];
            }
        };
    }
}
