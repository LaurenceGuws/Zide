package uk.laurencegouws.terminal.host.surface;

import android.os.Handler;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.widget.FrameLayout;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;

/** Adapts activity-owned callbacks/state into {@link SurfaceBridge.Callbacks}. */
public final class SurfaceCallbacks implements SurfaceBridge.Callbacks {
    /** Activity callbacks used by the surface host bridge. */
    public interface Callbacks {
        boolean debugViewEnabled();

        boolean currentImeVisible();

        boolean shouldRunFrameLoop();

        void refreshScrollOverlay();

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void callNative(String event, long seq);

        void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state);

        long nativeOnSurfaceAvailableBridge(SurfaceHolder holder, int width, int height);

        long nativeOnSurfaceDestroyedBridge();

        long nativeOnSurfaceRedrawNeededBridge();

        long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible);

        AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();

        void handleShellStateEvent(String statusLabel);

        void installSurfaceGestureHost(SurfaceView nextSurfaceView);

        void reinstallSurfaceCallback(SurfaceView nextSurfaceView, SurfaceHolder.Callback2 callback);

        SurfaceHolder.Callback2 surfaceCallback();
    }

    private final Handler handler;
    private final FrameLayout productSurfaceContainer;
    private final Callbacks callbacks;

    public SurfaceCallbacks(
            Handler handler,
            FrameLayout productSurfaceContainer,
            Callbacks callbacks) {
        this.handler = handler;
        this.productSurfaceContainer = productSurfaceContainer;
        this.callbacks = callbacks;
    }

    @Override
    public Handler handler() {
        return handler;
    }

    @Override
    public boolean nativeLoaded() {
        return NativeBridge.nativeLoaded();
    }

    @Override
    public boolean debugViewEnabled() {
        return callbacks.debugViewEnabled();
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return productSurfaceContainer;
    }

    @Override
    public boolean currentImeVisible() {
        return callbacks.currentImeVisible();
    }

    @Override
    public boolean shouldRunFrameLoop() {
        return callbacks.shouldRunFrameLoop();
    }

    @Override
    public void refreshScrollOverlay() {
        callbacks.refreshScrollOverlay();
    }

    @Override
    public void appendEvent(String event) {
        callbacks.appendEvent(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        callbacks.updateStatus(statusLabel);
    }

    @Override
    public void callNative(String event, long seq) {
        callbacks.callNative(event, seq);
    }

    @Override
    public void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state) {
        callbacks.callNativeWithSurfaceState(event, seq, state);
    }

    @Override
    public long nativeOnSurfaceAvailableBridge(SurfaceHolder holder, int width, int height) {
        return callbacks.nativeOnSurfaceAvailableBridge(holder, width, height);
    }

    @Override
    public long nativeOnSurfaceDestroyedBridge() {
        return callbacks.nativeOnSurfaceDestroyedBridge();
    }

    @Override
    public long nativeOnSurfaceRedrawNeededBridge() {
        return callbacks.nativeOnSurfaceRedrawNeededBridge();
    }

    @Override
    public long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible) {
        return callbacks.nativeOnVisibleViewportBridge(width, height, imeVisible);
    }

    @Override
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return callbacks.currentSurfaceStateSnapshot();
    }

    @Override
    public void handleShellStateEvent(String statusLabel) {
        callbacks.handleShellStateEvent(statusLabel);
    }

    @Override
    public void installSurfaceGestureHost(SurfaceView nextSurfaceView) {
        callbacks.installSurfaceGestureHost(nextSurfaceView);
    }

    @Override
    public void reinstallSurfaceCallback(SurfaceView nextSurfaceView, SurfaceHolder.Callback2 callback) {
        callbacks.reinstallSurfaceCallback(nextSurfaceView, callback);
    }

    @Override
    public SurfaceHolder.Callback2 surfaceCallback() {
        return callbacks.surfaceCallback();
    }
}
