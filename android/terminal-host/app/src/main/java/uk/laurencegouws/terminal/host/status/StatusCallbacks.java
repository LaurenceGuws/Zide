package uk.laurencegouws.terminal.host.status;

import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Functional callback adapter for {@link StatusBridge}. */
public final class StatusCallbacks implements StatusBridge.Callbacks {
    private final BooleanSupplier debugViewEnabled;
    private final BooleanSupplier nativeLoaded;
    private final BooleanSupplier hasWindowFocus;
    private final BooleanSupplier imeVisible;
    private final Supplier<SurfaceBridge> surfaceHostBridge;
    private final Supplier<UserlandInstallState> installState;
    private final Supplier<UserlandReadinessState> readinessState;
    private final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;

    /** Lightweight int supplier to avoid boxing in callback paths. */
    public interface IntSupplier {
        int getAsInt();
    }

    public StatusCallbacks(
            BooleanSupplier debugViewEnabled,
            BooleanSupplier nativeLoaded,
            BooleanSupplier hasWindowFocus,
            BooleanSupplier imeVisible,
            Supplier<SurfaceBridge> surfaceHostBridge,
            Supplier<UserlandInstallState> installState,
            Supplier<UserlandReadinessState> readinessState,
            Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot) {
        this.debugViewEnabled = debugViewEnabled;
        this.nativeLoaded = nativeLoaded;
        this.hasWindowFocus = hasWindowFocus;
        this.imeVisible = imeVisible;
        this.surfaceHostBridge = surfaceHostBridge;
        this.installState = installState;
        this.readinessState = readinessState;
        this.currentSurfaceStateSnapshot = currentSurfaceStateSnapshot;
    }

    @Override
    public boolean debugViewEnabled() {
        return debugViewEnabled.getAsBoolean();
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public boolean hasWindowFocus() {
        return hasWindowFocus.getAsBoolean();
    }

    @Override
    public boolean imeVisible() {
        return imeVisible.getAsBoolean();
    }

    @Override
    public android.view.SurfaceView surfaceView() {
        final SurfaceBridge bridge = surfaceHostBridge.get();
        return bridge != null ? bridge.currentSurfaceView() : null;
    }

    @Override
    public int visibleViewportWidth() {
        final SurfaceBridge bridge = surfaceHostBridge.get();
        return bridge != null ? bridge.currentVisibleViewportWidth() : 0;
    }

    @Override
    public int visibleViewportHeight() {
        final SurfaceBridge bridge = surfaceHostBridge.get();
        return bridge != null ? bridge.currentVisibleViewportHeight() : 0;
    }

    @Override
    public UserlandInstallState installState() {
        return installState.get();
    }

    @Override
    public UserlandReadinessState readinessState() {
        return readinessState.get();
    }

    @Override
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return currentSurfaceStateSnapshot.get();
    }
}
