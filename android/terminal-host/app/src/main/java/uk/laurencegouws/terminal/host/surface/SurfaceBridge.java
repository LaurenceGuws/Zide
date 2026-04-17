package uk.laurencegouws.terminal.host.surface;

import android.os.Handler;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.widget.FrameLayout;

import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;

/**
 * Owns mutable surface-host state and adapts activity callbacks to {@link SurfaceController}.
 */
public final class SurfaceBridge implements SurfaceController.Host {
    /** Callbacks owned by the activity/controller assembly. */
    public interface Callbacks {
        Handler handler();

        boolean nativeLoaded();

        FrameLayout productSurfaceContainer();

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

    private final Callbacks callbacks;
    private SurfaceView surfaceView;
    private int surfaceHostGeneration = 0;
    private boolean surfaceRecreationScheduled = false;
    private boolean surfaceResizeScheduled = false;
    private boolean shellStartScheduled = false;
    private int visibleViewportWidth = 0;
    private int visibleViewportHeight = 0;
    private int notifiedViewportWidth = 0;
    private int notifiedViewportHeight = 0;
    private boolean notifiedViewportImeVisible = false;

    public SurfaceBridge(Callbacks callbacks) {
        this.callbacks = callbacks;
    }

    public SurfaceView currentSurfaceView() {
        return surfaceView;
    }

    public int currentVisibleViewportWidth() {
        return visibleViewportWidth;
    }

    public int currentVisibleViewportHeight() {
        return visibleViewportHeight;
    }

    @Override
    public Handler handler() {
        return callbacks.handler();
    }

    @Override
    public boolean nativeLoaded() {
        return callbacks.nativeLoaded();
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return callbacks.productSurfaceContainer();
    }

    @Override
    public SurfaceView surfaceView() {
        return surfaceView;
    }

    @Override
    public void setSurfaceView(SurfaceView surfaceView) {
        this.surfaceView = surfaceView;
    }

    @Override
    public int surfaceHostGeneration() {
        return surfaceHostGeneration;
    }

    @Override
    public void setSurfaceHostGeneration(int generation) {
        surfaceHostGeneration = generation;
    }

    @Override
    public boolean surfaceRecreationScheduled() {
        return surfaceRecreationScheduled;
    }

    @Override
    public void setSurfaceRecreationScheduled(boolean scheduled) {
        surfaceRecreationScheduled = scheduled;
    }

    @Override
    public boolean surfaceResizeScheduled() {
        return surfaceResizeScheduled;
    }

    @Override
    public void setSurfaceResizeScheduled(boolean scheduled) {
        surfaceResizeScheduled = scheduled;
    }

    @Override
    public boolean shellStartScheduled() {
        return shellStartScheduled;
    }

    @Override
    public void setShellStartScheduled(boolean scheduled) {
        shellStartScheduled = scheduled;
    }

    @Override
    public int visibleViewportWidth() {
        return visibleViewportWidth;
    }

    @Override
    public int visibleViewportHeight() {
        return visibleViewportHeight;
    }

    @Override
    public void setVisibleViewportSize(int width, int height) {
        visibleViewportWidth = width;
        visibleViewportHeight = height;
    }

    @Override
    public int notifiedViewportWidth() {
        return notifiedViewportWidth;
    }

    @Override
    public int notifiedViewportHeight() {
        return notifiedViewportHeight;
    }

    @Override
    public boolean notifiedViewportImeVisible() {
        return notifiedViewportImeVisible;
    }

    @Override
    public void setNotifiedViewportSize(int width, int height, boolean imeVisible) {
        notifiedViewportWidth = width;
        notifiedViewportHeight = height;
        notifiedViewportImeVisible = imeVisible;
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
