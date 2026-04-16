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
    private final android.os.Handler handler;
    private final FrameLayout productSurfaceContainer;
    private final BooleanSupplier debugViewEnabled;
    private final BooleanSupplier currentImeVisible;
    private final BooleanSupplier shouldRunFrameLoop;
    private final Runnable refreshScrollOverlay;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final SurfaceLifecycleCallbacks.NativeEventCallback callNative;
    private final SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState;
    private final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;
    private final Consumer<String> handleShellStateEvent;
    private final Consumer<SurfaceView> installSurfaceGestureHost;
    private final SurfaceLifecycleCallbacks.ReinstallSurfaceCallback reinstallSurfaceCallback;
    private final Supplier<SurfaceHolder.Callback2> surfaceCallback;
    private final IntSupplier productViewportHeightPx;
    private final Runnable reevaluateFrameLoop;

    public SurfaceWidgetAssemblyCallbacks(
            android.os.Handler handler,
            FrameLayout productSurfaceContainer,
            BooleanSupplier debugViewEnabled,
            BooleanSupplier currentImeVisible,
            BooleanSupplier shouldRunFrameLoop,
            Runnable refreshScrollOverlay,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            SurfaceLifecycleCallbacks.NativeEventCallback callNative,
            SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState,
            Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
            Consumer<String> handleShellStateEvent,
            Consumer<SurfaceView> installSurfaceGestureHost,
            SurfaceLifecycleCallbacks.ReinstallSurfaceCallback reinstallSurfaceCallback,
            Supplier<SurfaceHolder.Callback2> surfaceCallback,
            IntSupplier productViewportHeightPx,
            Runnable reevaluateFrameLoop) {
        this.handler = handler;
        this.productSurfaceContainer = productSurfaceContainer;
        this.debugViewEnabled = debugViewEnabled;
        this.currentImeVisible = currentImeVisible;
        this.shouldRunFrameLoop = shouldRunFrameLoop;
        this.refreshScrollOverlay = refreshScrollOverlay;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.callNative = callNative;
        this.callNativeWithSurfaceState = callNativeWithSurfaceState;
        this.currentSurfaceStateSnapshot = currentSurfaceStateSnapshot;
        this.handleShellStateEvent = handleShellStateEvent;
        this.installSurfaceGestureHost = installSurfaceGestureHost;
        this.reinstallSurfaceCallback = reinstallSurfaceCallback;
        this.surfaceCallback = surfaceCallback;
        this.productViewportHeightPx = productViewportHeightPx;
        this.reevaluateFrameLoop = reevaluateFrameLoop;
    }

    @Override
    public android.os.Handler handler() {
        return handler;
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return productSurfaceContainer;
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
    public boolean shouldRunFrameLoop() {
        return shouldRunFrameLoop.getAsBoolean();
    }

    @Override
    public void refreshScrollOverlay() {
        refreshScrollOverlay.run();
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
    public void handleShellStateEvent(String statusLabel) {
        handleShellStateEvent.accept(statusLabel);
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
    public void reevaluateFrameLoop() {
        reevaluateFrameLoop.run();
    }
}
