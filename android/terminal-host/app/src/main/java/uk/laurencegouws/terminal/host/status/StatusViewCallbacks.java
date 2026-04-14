package uk.laurencegouws.terminal.host.status;

import android.app.Activity;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Functional callback adapter for {@link StatusViewAssembly.Host}. */
public final class StatusViewCallbacks implements StatusViewAssembly.Host {
    public static final class StatusHostBundle {
        final Supplier<Activity> activity;
        final BooleanSupplier debugViewEnabled;
        final BooleanSupplier nativeLoaded;
        final BooleanSupplier hasWindowFocusNow;
        final BooleanSupplier imeVisible;
        final Consumer<Boolean> setImeVisible;

        private StatusHostBundle(
                Supplier<Activity> activity,
                BooleanSupplier debugViewEnabled,
                BooleanSupplier nativeLoaded,
                BooleanSupplier hasWindowFocusNow,
                BooleanSupplier imeVisible,
                Consumer<Boolean> setImeVisible) {
            this.activity = activity;
            this.debugViewEnabled = debugViewEnabled;
            this.nativeLoaded = nativeLoaded;
            this.hasWindowFocusNow = hasWindowFocusNow;
            this.imeVisible = imeVisible;
            this.setImeVisible = setImeVisible;
        }

        public static StatusHostBundle of(
                Supplier<Activity> activity,
                BooleanSupplier debugViewEnabled,
                BooleanSupplier nativeLoaded,
                BooleanSupplier hasWindowFocusNow,
                BooleanSupplier imeVisible,
                Consumer<Boolean> setImeVisible) {
            return new StatusHostBundle(
                    activity,
                    debugViewEnabled,
                    nativeLoaded,
                    hasWindowFocusNow,
                    imeVisible,
                    setImeVisible);
        }
    }

    public static final class StatusRuntimeBundle {
        final Supplier<SurfaceBridge> surfaceHostBridge;
        final Supplier<UserlandInstallState> currentInstallState;
        final Supplier<UserlandReadinessState> currentReadinessState;
        final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;
        final Consumer<String> notifyVisibleViewport;

        private StatusRuntimeBundle(
                Supplier<SurfaceBridge> surfaceHostBridge,
                Supplier<UserlandInstallState> currentInstallState,
                Supplier<UserlandReadinessState> currentReadinessState,
                Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
                Consumer<String> notifyVisibleViewport) {
            this.surfaceHostBridge = surfaceHostBridge;
            this.currentInstallState = currentInstallState;
            this.currentReadinessState = currentReadinessState;
            this.currentSurfaceStateSnapshot = currentSurfaceStateSnapshot;
            this.notifyVisibleViewport = notifyVisibleViewport;
        }

        public static StatusRuntimeBundle of(
                Supplier<SurfaceBridge> surfaceHostBridge,
                Supplier<UserlandInstallState> currentInstallState,
                Supplier<UserlandReadinessState> currentReadinessState,
                Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
                Consumer<String> notifyVisibleViewport) {
            return new StatusRuntimeBundle(
                    surfaceHostBridge,
                    currentInstallState,
                    currentReadinessState,
                    currentSurfaceStateSnapshot,
                    notifyVisibleViewport);
        }
    }

    private final StatusHostBundle statusHostBundle;
    private final StatusRuntimeBundle statusRuntimeBundle;

    public StatusViewCallbacks(
            StatusHostBundle statusHostBundle,
            StatusRuntimeBundle statusRuntimeBundle) {
        this.statusHostBundle = statusHostBundle;
        this.statusRuntimeBundle = statusRuntimeBundle;
    }

    @Override
    public Activity activity() {
        return statusHostBundle.activity.get();
    }

    @Override
    public boolean debugViewEnabled() {
        return statusHostBundle.debugViewEnabled.getAsBoolean();
    }

    @Override
    public boolean nativeLoaded() {
        return statusHostBundle.nativeLoaded.getAsBoolean();
    }

    @Override
    public boolean hasWindowFocusNow() {
        return statusHostBundle.hasWindowFocusNow.getAsBoolean();
    }

    @Override
    public boolean imeVisible() {
        return statusHostBundle.imeVisible.getAsBoolean();
    }

    @Override
    public void setImeVisible(boolean visible) {
        statusHostBundle.setImeVisible.accept(visible);
    }

    @Override
    public SurfaceBridge surfaceHostBridge() {
        return statusRuntimeBundle.surfaceHostBridge.get();
    }

    @Override
    public UserlandInstallState currentInstallState() {
        return statusRuntimeBundle.currentInstallState.get();
    }

    @Override
    public UserlandReadinessState currentReadinessState() {
        return statusRuntimeBundle.currentReadinessState.get();
    }

    @Override
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return statusRuntimeBundle.currentSurfaceStateSnapshot.get();
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        statusRuntimeBundle.notifyVisibleViewport.accept(reason);
    }
}
