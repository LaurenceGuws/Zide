package uk.laurencegouws.terminal.host.userland;

import android.view.SurfaceView;

import java.util.function.Supplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Functional callback adapter for {@link ShellStateBridge}. */
public final class ShellStateCallbacks implements ShellStateBridge.Callbacks {
    private final Supplier<UserlandReadinessState> readinessState;
    private final Supplier<UserlandInstallState> installState;
    private final Supplier<SurfaceView> surfaceView;

    public ShellStateCallbacks(
            Supplier<UserlandReadinessState> readinessState,
            Supplier<UserlandInstallState> installState,
            Supplier<SurfaceView> surfaceView) {
        this.readinessState = readinessState;
        this.installState = installState;
        this.surfaceView = surfaceView;
    }

    @Override
    public boolean nativeLoaded() {
        return NativeBridge.nativeLoaded();
    }

    @Override
    public boolean sharedShellRendererActive() {
        return NativeBridge.nativeSharedRendererActiveBridge();
    }

    @Override
    public boolean installInstalling() {
        return installState.get().isInstalling();
    }

    @Override
    public boolean installFailed() {
        return installState.get().isFailed();
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
