package uk.laurencegouws.terminal.host.surface;

import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.widget.FrameLayout;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;

/** Functional callback adapter for {@link SurfaceWidgetAssembly.Host}. */
public final class SurfaceWidgetAssemblyCallbacks implements SurfaceWidgetAssembly.Host {
    private final Supplier<android.os.Handler> handler;
    private final Supplier<FrameLayout> productSurfaceContainer;
    private final BooleanSupplier nativeLoaded;
    private final BooleanSupplier debugViewEnabled;
    private final BooleanSupplier currentImeVisible;
    private final BooleanSupplier shouldRunProductFrameLoop;
    private final Runnable refreshProductScrollOverlay;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final SurfaceLifecycleCallbacks.NativeEventCallback callNative;
    private final SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState;
    private final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;
    private final Consumer<String> handleProductShellStateEvent;
    private final Consumer<SurfaceView> installSurfaceGestureHost;
    private final SurfaceLifecycleCallbacks.ReinstallSurfaceCallback reinstallSurfaceCallback;
    private final Supplier<SurfaceHolder.Callback2> surfaceCallback;
    private final IntSupplier productViewportHeightPx;
    private final Runnable reevaluateProductFrameLoop;

    public SurfaceWidgetAssemblyCallbacks(
            Supplier<android.os.Handler> handler,
            Supplier<FrameLayout> productSurfaceContainer,
            BooleanSupplier nativeLoaded,
            BooleanSupplier debugViewEnabled,
            BooleanSupplier currentImeVisible,
            BooleanSupplier shouldRunProductFrameLoop,
            Runnable refreshProductScrollOverlay,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            SurfaceLifecycleCallbacks.NativeEventCallback callNative,
            SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState,
            Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
            Consumer<String> handleProductShellStateEvent,
            Consumer<SurfaceView> installSurfaceGestureHost,
            SurfaceLifecycleCallbacks.ReinstallSurfaceCallback reinstallSurfaceCallback,
            Supplier<SurfaceHolder.Callback2> surfaceCallback,
            IntSupplier productViewportHeightPx,
            Runnable reevaluateProductFrameLoop) {
        this.handler = handler;
        this.productSurfaceContainer = productSurfaceContainer;
        this.nativeLoaded = nativeLoaded;
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
        this.productViewportHeightPx = productViewportHeightPx;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
    }

    @Override
    public android.os.Handler handler() {
        return handler.get();
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return productSurfaceContainer.get();
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
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
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return currentSurfaceStateSnapshot.get();
    }

    @Override
    public void handleProductShellStateEvent(String statusLabel) {
        handleProductShellStateEvent.accept(statusLabel);
    }

    @Override
    public void installSurfaceGestureHost(SurfaceView surfaceView) {
        installSurfaceGestureHost.accept(surfaceView);
    }

    @Override
    public void reinstallSurfaceCallback(SurfaceView surfaceView, SurfaceHolder.Callback2 callback) {
        reinstallSurfaceCallback.call(surfaceView, callback);
    }

    @Override
    public SurfaceHolder.Callback2 surfaceCallback() {
        return surfaceCallback.get();
    }

    @Override
    public int productViewportHeightPx() {
        return productViewportHeightPx.getAsInt();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        reevaluateProductFrameLoop.run();
    }
}
