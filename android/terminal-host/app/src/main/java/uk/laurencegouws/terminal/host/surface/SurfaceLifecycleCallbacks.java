package uk.laurencegouws.terminal.host.surface;

import android.view.SurfaceHolder;
import android.view.SurfaceView;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;

/** Functional callback adapter for {@link SurfaceCallbacks.Callbacks}. */
public final class SurfaceLifecycleCallbacks implements SurfaceCallbacks.Callbacks {
    /** Callback for native event notifications with sequence id. */
    public interface NativeEventCallback {
        void call(String event, long seq);
    }

    /** Callback for native event notifications with a surface snapshot. */
    public interface NativeSurfaceEventCallback {
        void call(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state);
    }

    private final BooleanSupplier debugViewEnabled;
    private final BooleanSupplier currentImeVisible;
    private final BooleanSupplier shouldRunProductFrameLoop;
    private final Runnable refreshProductScrollOverlay;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final NativeEventCallback callNative;
    private final NativeSurfaceEventCallback callNativeWithSurfaceState;
    private final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;
    private final Consumer<String> handleProductShellStateEvent;
    private final Consumer<SurfaceView> installSurfaceGestureHost;
    private final ReinstallSurfaceCallback reinstallSurfaceCallback;
    private final Supplier<SurfaceHolder.Callback2> surfaceCallback;

    /** Callback for SurfaceView callback re-installation. */
    public interface ReinstallSurfaceCallback {
        void call(SurfaceView nextSurfaceView, SurfaceHolder.Callback2 callback);
    }

    public SurfaceLifecycleCallbacks(
            BooleanSupplier debugViewEnabled,
            BooleanSupplier currentImeVisible,
            BooleanSupplier shouldRunProductFrameLoop,
            Runnable refreshProductScrollOverlay,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            NativeEventCallback callNative,
            NativeSurfaceEventCallback callNativeWithSurfaceState,
            Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
            Consumer<String> handleProductShellStateEvent,
            Consumer<SurfaceView> installSurfaceGestureHost,
            ReinstallSurfaceCallback reinstallSurfaceCallback,
            Supplier<SurfaceHolder.Callback2> surfaceCallback) {
        this.debugViewEnabled = debugViewEnabled;
        this.currentImeVisible = currentImeVisible;
        this.shouldRunProductFrameLoop = shouldRunProductFrameLoop;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.callNative = callNative;
        this.callNativeWithSurfaceState = callNativeWithSurfaceState;
        this.currentSurfaceStateSnapshot = currentSurfaceStateSnapshot;
        this.handleProductShellStateEvent = handleProductShellStateEvent;
        this.installSurfaceGestureHost = installSurfaceGestureHost;
        this.reinstallSurfaceCallback = reinstallSurfaceCallback;
        this.surfaceCallback = surfaceCallback;
    }


    @Override
    public boolean debugViewEnabled() {
        return debugViewEnabled.getAsBoolean();
    }

    @Override
    public boolean currentImeVisible() {
        return currentImeVisible.getAsBoolean();
    }

    @Override
    public boolean shouldRunProductFrameLoop() {
        return shouldRunProductFrameLoop.getAsBoolean();
    }

    @Override
    public void refreshProductScrollOverlay() {
        refreshProductScrollOverlay.run();
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }

    @Override
    public void callNative(String event, long seq) {
        callNative.call(event, seq);
    }

    @Override
    public void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state) {
        callNativeWithSurfaceState.call(event, seq, state);
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
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return currentSurfaceStateSnapshot.get();
    }

    @Override
    public void handleProductShellStateEvent(String statusLabel) {
        handleProductShellStateEvent.accept(statusLabel);
    }

    @Override
    public void installSurfaceGestureHost(SurfaceView nextSurfaceView) {
        installSurfaceGestureHost.accept(nextSurfaceView);
    }

    @Override
    public void reinstallSurfaceCallback(SurfaceView nextSurfaceView, SurfaceHolder.Callback2 callback) {
        reinstallSurfaceCallback.call(nextSurfaceView, callback);
    }

    @Override
    public SurfaceHolder.Callback2 surfaceCallback() {
        return surfaceCallback.get();
    }
}
