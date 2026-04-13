package dev.zide.terminal.host;

import android.view.SurfaceView;

import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandInstallState;

/** Functional callback adapter for {@link TerminalProductShellStateHostBridge}. */
public final class TerminalProductShellStateHostCallbacks implements TerminalProductShellStateHostBridge.Callbacks {
    private final BooleanSupplier nativeLoaded;
    private final BooleanSupplier sharedShellRendererActive;
    private final BooleanSupplier installInstalling;
    private final BooleanSupplier installFailed;
    private final Supplier<UserlandBootstrapState> bootstrapState;
    private final Supplier<UserlandInstallState> installState;
    private final Supplier<SurfaceView> surfaceView;

    public TerminalProductShellStateHostCallbacks(
            BooleanSupplier nativeLoaded,
            BooleanSupplier sharedShellRendererActive,
            BooleanSupplier installInstalling,
            BooleanSupplier installFailed,
            Supplier<UserlandBootstrapState> bootstrapState,
            Supplier<UserlandInstallState> installState,
            Supplier<SurfaceView> surfaceView) {
        this.nativeLoaded = nativeLoaded;
        this.sharedShellRendererActive = sharedShellRendererActive;
        this.installInstalling = installInstalling;
        this.installFailed = installFailed;
        this.bootstrapState = bootstrapState;
        this.installState = installState;
        this.surfaceView = surfaceView;
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public boolean sharedShellRendererActive() {
        return sharedShellRendererActive.getAsBoolean();
    }

    @Override
    public boolean installInstalling() {
        return installInstalling.getAsBoolean();
    }

    @Override
    public boolean installFailed() {
        return installFailed.getAsBoolean();
    }

    @Override
    public UserlandBootstrapState bootstrapState() {
        return bootstrapState.get();
    }

    @Override
    public UserlandInstallState installState() {
        return installState.get();
    }

    @Override
    public SurfaceView surfaceView() {
        return surfaceView.get();
    }
}
