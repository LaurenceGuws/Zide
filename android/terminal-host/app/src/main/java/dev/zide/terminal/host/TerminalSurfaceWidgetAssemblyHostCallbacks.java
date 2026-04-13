package dev.zide.terminal.host;

import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.widget.FrameLayout;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.IntUnaryOperator;
import java.util.function.Supplier;

import dev.zide.terminal.debug.AndroidDebugFormatter;

/** Functional callback adapter for {@link TerminalSurfaceWidgetAssembly.Host}. */
public final class TerminalSurfaceWidgetAssemblyHostCallbacks implements TerminalSurfaceWidgetAssembly.Host {
    private final Supplier<android.os.Handler> handler;
    private final Supplier<FrameLayout> productSurfaceContainer;
    private final BooleanSupplier nativeLoaded;
    private final BooleanSupplier debugViewEnabled;
    private final BooleanSupplier currentImeVisible;
    private final BooleanSupplier shouldRunProductFrameLoop;
    private final Runnable refreshProductScrollOverlay;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final TerminalSurfaceHostLifecycleCallbacks.NativeEventCallback callNative;
    private final TerminalSurfaceHostLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState;
    private final TerminalSurfaceHostLifecycleCallbacks.SurfaceAvailableCallback nativeOnSurfaceAvailableBridge;
    private final TerminalSurfaceHostLifecycleCallbacks.LongSupplier nativeOnSurfaceDestroyedBridge;
    private final TerminalSurfaceHostLifecycleCallbacks.LongSupplier nativeOnSurfaceRedrawNeededBridge;
    private final TerminalSurfaceHostLifecycleCallbacks.VisibleViewportCallback nativeOnVisibleViewportBridge;
    private final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;
    private final Consumer<String> handleProductShellStateEvent;
    private final Consumer<SurfaceView> installSurfaceGestureHost;
    private final TerminalSurfaceHostLifecycleCallbacks.ReinstallSurfaceCallback reinstallSurfaceCallback;
    private final Supplier<SurfaceHolder.Callback2> surfaceCallback;
    private final IntUnaryOperator nativeSetShellScrollbackOffset;
    private final IntSupplier nativeFollowShellLiveBottom;
    private final IntSupplier productViewportHeightPx;
    private final Runnable reevaluateProductFrameLoop;

    public TerminalSurfaceWidgetAssemblyHostCallbacks(
            Supplier<android.os.Handler> handler,
            Supplier<FrameLayout> productSurfaceContainer,
            BooleanSupplier nativeLoaded,
            BooleanSupplier debugViewEnabled,
            BooleanSupplier currentImeVisible,
            BooleanSupplier shouldRunProductFrameLoop,
            Runnable refreshProductScrollOverlay,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            TerminalSurfaceHostLifecycleCallbacks.NativeEventCallback callNative,
            TerminalSurfaceHostLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState,
            TerminalSurfaceHostLifecycleCallbacks.SurfaceAvailableCallback nativeOnSurfaceAvailableBridge,
            TerminalSurfaceHostLifecycleCallbacks.LongSupplier nativeOnSurfaceDestroyedBridge,
            TerminalSurfaceHostLifecycleCallbacks.LongSupplier nativeOnSurfaceRedrawNeededBridge,
            TerminalSurfaceHostLifecycleCallbacks.VisibleViewportCallback nativeOnVisibleViewportBridge,
            Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
            Consumer<String> handleProductShellStateEvent,
            Consumer<SurfaceView> installSurfaceGestureHost,
            TerminalSurfaceHostLifecycleCallbacks.ReinstallSurfaceCallback reinstallSurfaceCallback,
            Supplier<SurfaceHolder.Callback2> surfaceCallback,
            IntUnaryOperator nativeSetShellScrollbackOffset,
            IntSupplier nativeFollowShellLiveBottom,
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
        this.nativeOnSurfaceAvailableBridge = nativeOnSurfaceAvailableBridge;
        this.nativeOnSurfaceDestroyedBridge = nativeOnSurfaceDestroyedBridge;
        this.nativeOnSurfaceRedrawNeededBridge = nativeOnSurfaceRedrawNeededBridge;
        this.nativeOnVisibleViewportBridge = nativeOnVisibleViewportBridge;
        this.currentSurfaceStateSnapshot = currentSurfaceStateSnapshot;
        this.handleProductShellStateEvent = handleProductShellStateEvent;
        this.installSurfaceGestureHost = installSurfaceGestureHost;
        this.reinstallSurfaceCallback = reinstallSurfaceCallback;
        this.surfaceCallback = surfaceCallback;
        this.nativeSetShellScrollbackOffset = nativeSetShellScrollbackOffset;
        this.nativeFollowShellLiveBottom = nativeFollowShellLiveBottom;
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
    public long nativeOnSurfaceAvailableBridge(SurfaceHolder holder, int width, int height) {
        return nativeOnSurfaceAvailableBridge.call(holder, width, height);
    }

    @Override
    public long nativeOnSurfaceDestroyedBridge() {
        return nativeOnSurfaceDestroyedBridge.getAsLong();
    }

    @Override
    public long nativeOnSurfaceRedrawNeededBridge() {
        return nativeOnSurfaceRedrawNeededBridge.getAsLong();
    }

    @Override
    public long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible) {
        return nativeOnVisibleViewportBridge.call(width, height, imeVisible);
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
    public int nativeSetShellScrollbackOffset(int offsetRows) {
        return nativeSetShellScrollbackOffset.applyAsInt(offsetRows);
    }

    @Override
    public int nativeFollowShellLiveBottom() {
        return nativeFollowShellLiveBottom.getAsInt();
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
