package uk.laurencegouws.terminal.host.status;

import android.app.Activity;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.host.ui.HostImeStateAccess;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Functional callback adapter for {@link StatusViewAssembly.Host}. */
public final class StatusViewCallbacks implements StatusViewAssembly.Host {
    private final Activity activity;
    private final BooleanSupplier hasWindowFocus;
    private final HostImeStateAccess hostImeState;
    private final Supplier<SurfaceBridge> surfaceHostBridge;
    private final Consumer<String> notifyVisibleViewport;
    private final Supplier<UserlandInstallState> currentInstallState;
    private final Supplier<UserlandReadinessState> currentReadinessState;

    public StatusViewCallbacks(
            Activity activity,
            BooleanSupplier hasWindowFocus,
            HostImeStateAccess hostImeState,
            Supplier<SurfaceBridge> surfaceHostBridge,
            Consumer<String> notifyVisibleViewport,
            Supplier<UserlandInstallState> currentInstallState,
            Supplier<UserlandReadinessState> currentReadinessState) {
        this.activity = activity;
        this.hasWindowFocus = hasWindowFocus;
        this.hostImeState = hostImeState;
        this.surfaceHostBridge = surfaceHostBridge;
        this.notifyVisibleViewport = notifyVisibleViewport;
        this.currentInstallState = currentInstallState;
        this.currentReadinessState = currentReadinessState;
    }

    @Override
    public Activity activity() {
        return activity;
    }

    public boolean nativeLoaded() {
        return NativeBridge.nativeLoaded();
    }

    @Override
    public boolean hasWindowFocus() {
        return hasWindowFocus.getAsBoolean();
    }

    @Override
    public HostImeStateAccess hostImeStateAccess() {
        return hostImeState;
    }

    @Override
    public SurfaceBridge surfaceHostBridge() {
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
    public void notifyVisibleViewport(String reason) {
        notifyVisibleViewport.accept(reason);
    }
}
