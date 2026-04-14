package uk.laurencegouws.terminal.host.userland;

import android.view.SurfaceView;

import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Functional callback adapter for {@link ProductShellStateBridge}. */
public final class ProductShellStateCallbacks implements ProductShellStateBridge.Callbacks {
    private final BooleanSupplier nativeLoaded;
    private final BooleanSupplier sharedShellRendererActive;
    private final BooleanSupplier installInstalling;
    private final BooleanSupplier installFailed;
    private final Supplier<UserlandReadinessState> readinessState;
    private final Supplier<UserlandInstallState> installState;
    private final Supplier<SurfaceView> surfaceView;

    public ProductShellStateCallbacks(
            BooleanSupplier nativeLoaded,
            BooleanSupplier sharedShellRendererActive,
            BooleanSupplier installInstalling,
            BooleanSupplier installFailed,
            Supplier<UserlandReadinessState> readinessState,
            Supplier<UserlandInstallState> installState,
            Supplier<SurfaceView> surfaceView) {
        this.nativeLoaded = nativeLoaded;
        this.sharedShellRendererActive = sharedShellRendererActive;
        this.installInstalling = installInstalling;
        this.installFailed = installFailed;
        this.readinessState = readinessState;
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
    public UserlandReadinessState readinessState() {
        return readinessState.get();
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
