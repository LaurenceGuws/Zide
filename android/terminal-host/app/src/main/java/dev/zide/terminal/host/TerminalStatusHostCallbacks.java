package dev.zide.terminal.host;

import android.view.SurfaceView;

import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

import dev.zide.terminal.debug.AndroidDebugFormatter;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;

/** Functional callback adapter for {@link TerminalStatusHostBridge}. */
public final class TerminalStatusHostCallbacks implements TerminalStatusHostBridge.Callbacks {
    private final BooleanSupplier debugViewEnabled;
    private final BooleanSupplier nativeLoaded;
    private final BooleanSupplier hasWindowFocus;
    private final BooleanSupplier imeVisible;
    private final Supplier<SurfaceView> surfaceView;
    private final IntSupplier visibleViewportWidth;
    private final IntSupplier visibleViewportHeight;
    private final Supplier<UserlandInstallState> installState;
    private final Supplier<UserlandReadinessState> readinessState;
    private final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;

    /** Lightweight int supplier to avoid boxing in callback paths. */
    public interface IntSupplier {
        int getAsInt();
    }

    public TerminalStatusHostCallbacks(
            BooleanSupplier debugViewEnabled,
            BooleanSupplier nativeLoaded,
            BooleanSupplier hasWindowFocus,
            BooleanSupplier imeVisible,
            Supplier<SurfaceView> surfaceView,
            IntSupplier visibleViewportWidth,
            IntSupplier visibleViewportHeight,
            Supplier<UserlandInstallState> installState,
            Supplier<UserlandReadinessState> readinessState,
            Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot) {
        this.debugViewEnabled = debugViewEnabled;
        this.nativeLoaded = nativeLoaded;
        this.hasWindowFocus = hasWindowFocus;
        this.imeVisible = imeVisible;
        this.surfaceView = surfaceView;
        this.visibleViewportWidth = visibleViewportWidth;
        this.visibleViewportHeight = visibleViewportHeight;
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
    public SurfaceView surfaceView() {
        return surfaceView.get();
    }

    @Override
    public int visibleViewportWidth() {
        return visibleViewportWidth.getAsInt();
    }

    @Override
    public int visibleViewportHeight() {
        return visibleViewportHeight.getAsInt();
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
