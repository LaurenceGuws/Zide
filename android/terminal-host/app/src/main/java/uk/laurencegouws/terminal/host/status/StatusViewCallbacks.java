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
    public static final class StatusHostCallbacks {
        final Supplier<Activity> activity;
        final BooleanSupplier debugViewEnabled;
        final BooleanSupplier nativeLoaded;
        final BooleanSupplier hasWindowFocusNow;
        final BooleanSupplier imeVisible;
        final Consumer<Boolean> setImeVisible;

        private StatusHostCallbacks(
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

        public static StatusHostCallbacks of(
                Supplier<Activity> activity,
                BooleanSupplier debugViewEnabled,
                BooleanSupplier nativeLoaded,
                BooleanSupplier hasWindowFocusNow,
                BooleanSupplier imeVisible,
                Consumer<Boolean> setImeVisible) {
            return new StatusHostCallbacks(
                    activity,
                    debugViewEnabled,
                    nativeLoaded,
                    hasWindowFocusNow,
                    imeVisible,
                    setImeVisible);
        }
    }

    public static final class StatusRuntimeCallbacks {
        final StatusSurfaceCallbacks statusSurfaceCallbacks;
        final StatusUserlandCallbacks statusUserlandCallbacks;

        private StatusRuntimeCallbacks(
                StatusSurfaceCallbacks statusSurfaceCallbacks,
                StatusUserlandCallbacks statusUserlandCallbacks) {
            this.statusSurfaceCallbacks = statusSurfaceCallbacks;
            this.statusUserlandCallbacks = statusUserlandCallbacks;
        }

        public static StatusRuntimeCallbacks of(
                StatusSurfaceCallbacks statusSurfaceCallbacks,
                StatusUserlandCallbacks statusUserlandCallbacks) {
            return new StatusRuntimeCallbacks(
                    statusSurfaceCallbacks,
                    statusUserlandCallbacks);
        }
    }

    public static final class StatusSurfaceCallbacks {
        final Supplier<SurfaceBridge> surfaceHostBridge;
        final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;
        final Consumer<String> notifyVisibleViewport;

        private StatusSurfaceCallbacks(
                Supplier<SurfaceBridge> surfaceHostBridge,
                Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
                Consumer<String> notifyVisibleViewport) {
            this.surfaceHostBridge = surfaceHostBridge;
            this.currentSurfaceStateSnapshot = currentSurfaceStateSnapshot;
            this.notifyVisibleViewport = notifyVisibleViewport;
        }

        public static StatusSurfaceCallbacks of(
                Supplier<SurfaceBridge> surfaceHostBridge,
                Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
                Consumer<String> notifyVisibleViewport) {
            return new StatusSurfaceCallbacks(
                    surfaceHostBridge,
                    currentSurfaceStateSnapshot,
                    notifyVisibleViewport);
        }
    }

    public static final class StatusUserlandCallbacks {
        final Supplier<UserlandInstallState> currentInstallState;
        final Supplier<UserlandReadinessState> currentReadinessState;

        private StatusUserlandCallbacks(
                Supplier<UserlandInstallState> currentInstallState,
                Supplier<UserlandReadinessState> currentReadinessState) {
            this.currentInstallState = currentInstallState;
            this.currentReadinessState = currentReadinessState;
        }

        public static StatusUserlandCallbacks of(
                Supplier<UserlandInstallState> currentInstallState,
                Supplier<UserlandReadinessState> currentReadinessState) {
            return new StatusUserlandCallbacks(
                    currentInstallState,
                    currentReadinessState);
        }
    }

    private final StatusHostCallbacks statusHostCallbacks;
    private final StatusRuntimeCallbacks statusRuntimeCallbacks;

    public StatusViewCallbacks(
            StatusHostCallbacks statusHostCallbacks,
            StatusRuntimeCallbacks statusRuntimeCallbacks) {
        this.statusHostCallbacks = statusHostCallbacks;
        this.statusRuntimeCallbacks = statusRuntimeCallbacks;
    }

    @Override
    public Activity activity() {
        return statusHostCallbacks.activity.get();
    }

    @Override
    public boolean debugViewEnabled() {
        return statusHostCallbacks.debugViewEnabled.getAsBoolean();
    }

    @Override
    public boolean nativeLoaded() {
        return statusHostCallbacks.nativeLoaded.getAsBoolean();
    }

    @Override
    public boolean hasWindowFocusNow() {
        return statusHostCallbacks.hasWindowFocusNow.getAsBoolean();
    }

    @Override
    public boolean imeVisible() {
        return statusHostCallbacks.imeVisible.getAsBoolean();
    }

    @Override
    public void setImeVisible(boolean visible) {
        statusHostCallbacks.setImeVisible.accept(visible);
    }

    @Override
    public SurfaceBridge surfaceHostBridge() {
        return statusRuntimeCallbacks.statusSurfaceCallbacks.surfaceHostBridge.get();
    }

    @Override
    public UserlandInstallState currentInstallState() {
        return statusRuntimeCallbacks.statusUserlandCallbacks.currentInstallState.get();
    }

    @Override
    public UserlandReadinessState currentReadinessState() {
        return statusRuntimeCallbacks.statusUserlandCallbacks.currentReadinessState.get();
    }

    @Override
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return statusRuntimeCallbacks.statusSurfaceCallbacks.currentSurfaceStateSnapshot.get();
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        statusRuntimeCallbacks.statusSurfaceCallbacks.notifyVisibleViewport.accept(reason);
    }
}
