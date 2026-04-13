package dev.zide.terminal.host;

import android.widget.FrameLayout;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Surface host assembly helpers. */
public final class TerminalSurfaceHostFactory {
    private TerminalSurfaceHostFactory() {
    }

    public static TerminalSurfaceHostBridge createSurfaceHostBridge(TerminalSurfaceHostBridge.Callbacks callbacks) {
        return new TerminalSurfaceHostBridge(callbacks);
    }

    public static TerminalSurfaceHostBridge.Callbacks createSurfaceHostCallbacks(
            android.os.Handler handler,
            FrameLayout productSurfaceContainer,
            TerminalSurfaceHostCallbacks.Callbacks callbacks) {
        return new TerminalSurfaceHostCallbacks(
                handler,
                productSurfaceContainer,
                callbacks);
    }

    public static TerminalSurfaceHostCallbacks.Callbacks createSurfaceHostLifecycleCallbacks(
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
            Supplier<dev.zide.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
            Consumer<String> handleProductShellStateEvent,
            Consumer<android.view.SurfaceView> installSurfaceGestureHost,
            TerminalSurfaceHostLifecycleCallbacks.ReinstallSurfaceCallback reinstallSurfaceCallback,
            Supplier<android.view.SurfaceHolder.Callback2> surfaceCallback) {
        return new TerminalSurfaceHostLifecycleCallbacks(
                nativeLoaded,
                debugViewEnabled,
                currentImeVisible,
                shouldRunProductFrameLoop,
                refreshProductScrollOverlay,
                appendEvent,
                updateStatus,
                callNative,
                callNativeWithSurfaceState,
                nativeOnSurfaceAvailableBridge,
                nativeOnSurfaceDestroyedBridge,
                nativeOnSurfaceRedrawNeededBridge,
                nativeOnVisibleViewportBridge,
                currentSurfaceStateSnapshot,
                handleProductShellStateEvent,
                installSurfaceGestureHost,
                reinstallSurfaceCallback,
                surfaceCallback);
    }
}
