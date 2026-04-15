package uk.laurencegouws.terminal.host.surface;

import android.widget.FrameLayout;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Surface host assembly helpers. */
public final class SurfaceFactory {
    private SurfaceFactory() {
    }

    public static SurfaceBridge createSurfaceHostBridge(SurfaceBridge.Callbacks callbacks) {
        return new SurfaceBridge(callbacks);
    }

    public static SurfaceBridge.Callbacks createSurfaceHostCallbacks(
            android.os.Handler handler,
            FrameLayout productSurfaceContainer,
            SurfaceCallbacks.Callbacks callbacks) {
        return new SurfaceCallbacks(
                handler,
                productSurfaceContainer,
                callbacks);
    }

    public static SurfaceCallbacks.Callbacks createSurfaceHostLifecycleCallbacks(
            BooleanSupplier debugViewEnabled,
            BooleanSupplier currentImeVisible,
            BooleanSupplier shouldRunProductFrameLoop,
            Runnable refreshProductScrollOverlay,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            SurfaceLifecycleCallbacks.NativeEventCallback callNative,
            SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState,
            Supplier<uk.laurencegouws.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
            Consumer<String> handleProductShellStateEvent,
            Consumer<android.view.SurfaceView> installSurfaceGestureHost,
            SurfaceLifecycleCallbacks.ReinstallSurfaceCallback reinstallSurfaceCallback,
            Supplier<android.view.SurfaceHolder.Callback2> surfaceCallback) {
        return new SurfaceLifecycleCallbacks(
                debugViewEnabled,
                currentImeVisible,
                shouldRunProductFrameLoop,
                refreshProductScrollOverlay,
                appendEvent,
                updateStatus,
                callNative,
                callNativeWithSurfaceState,
                currentSurfaceStateSnapshot,
                handleProductShellStateEvent,
                installSurfaceGestureHost,
                reinstallSurfaceCallback,
                surfaceCallback);
    }
}
