package dev.zide.terminal.host;

import android.app.Activity;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import dev.zide.terminal.debug.AndroidDebugFormatter;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;

/** Functional callback adapter for {@link TerminalStatusViewAssembly.Host}. */
public final class TerminalStatusViewAssemblyHostCallbacks implements TerminalStatusViewAssembly.Host {
    private final Supplier<Activity> activity;
    private final BooleanSupplier debugViewEnabled;
    private final BooleanSupplier nativeLoaded;
    private final BooleanSupplier hasWindowFocusNow;
    private final BooleanSupplier imeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final Supplier<TerminalSurfaceHostBridge> surfaceHostBridge;
    private final Supplier<UserlandInstallState> currentInstallState;
    private final Supplier<UserlandReadinessState> currentReadinessState;
    private final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;
    private final Consumer<String> notifyVisibleViewport;

    public TerminalStatusViewAssemblyHostCallbacks(
            Supplier<Activity> activity,
            BooleanSupplier debugViewEnabled,
            BooleanSupplier nativeLoaded,
            BooleanSupplier hasWindowFocusNow,
            BooleanSupplier imeVisible,
            Consumer<Boolean> setImeVisible,
            Supplier<TerminalSurfaceHostBridge> surfaceHostBridge,
            Supplier<UserlandInstallState> currentInstallState,
            Supplier<UserlandReadinessState> currentReadinessState,
            Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
            Consumer<String> notifyVisibleViewport) {
        this.activity = activity;
        this.debugViewEnabled = debugViewEnabled;
        this.nativeLoaded = nativeLoaded;
        this.hasWindowFocusNow = hasWindowFocusNow;
        this.imeVisible = imeVisible;
        this.setImeVisible = setImeVisible;
        this.surfaceHostBridge = surfaceHostBridge;
        this.currentInstallState = currentInstallState;
        this.currentReadinessState = currentReadinessState;
        this.currentSurfaceStateSnapshot = currentSurfaceStateSnapshot;
        this.notifyVisibleViewport = notifyVisibleViewport;
    }

    @Override
    public Activity activity() {
        return activity.get();
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
    public boolean hasWindowFocusNow() {
        return hasWindowFocusNow.getAsBoolean();
    }

    @Override
    public boolean imeVisible() {
        return imeVisible.getAsBoolean();
    }

    @Override
    public void setImeVisible(boolean visible) {
        setImeVisible.accept(visible);
    }

    @Override
    public TerminalSurfaceHostBridge surfaceHostBridge() {
        return surfaceHostBridge.get();
    }

    @Override
    public UserlandInstallState currentInstallState() {
        return currentInstallState.get();
    }

    @Override
    public UserlandReadinessState currentReadinessState() {
        return currentReadinessState.get();
    }

    @Override
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return currentSurfaceStateSnapshot.get();
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        notifyVisibleViewport.accept(reason);
    }
}
