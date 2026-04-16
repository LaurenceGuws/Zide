package uk.laurencegouws.terminal.host.status;

import android.view.SurfaceView;

import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;
import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/**
 * Adapts activity-owned status callbacks to {@link StatusController.Host}.
 */
public final class StatusBridge implements StatusController.Host {
    /** Activity callbacks used by debug status presentation. */
    public interface Callbacks {
        boolean debugViewEnabled();

        boolean nativeLoaded();

        boolean hasWindowFocus();

        boolean imeVisible();

        SurfaceView surfaceView();

        int visibleViewportWidth();

        int visibleViewportHeight();

        UserlandInstallState installState();

        UserlandReadinessState readinessState();

        AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();
    }

    private final Callbacks callbacks;

    public StatusBridge(Callbacks callbacks) {
        this.callbacks = callbacks;
    }

    @Override
    public boolean debugViewEnabled() {
        return callbacks.debugViewEnabled();
    }

    @Override
    public boolean nativeLoaded() {
        return callbacks.nativeLoaded();
    }

    @Override
    public boolean hasWindowFocus() {
        return callbacks.hasWindowFocus();
    }

    @Override
    public boolean imeVisible() {
        return callbacks.imeVisible();
    }

    @Override
    public SurfaceView surfaceView() {
        return callbacks.surfaceView();
    }

    @Override
    public int visibleViewportWidth() {
        return callbacks.visibleViewportWidth();
    }

    @Override
    public int visibleViewportHeight() {
        return callbacks.visibleViewportHeight();
    }

    @Override
    public UserlandInstallState installState() {
        return callbacks.installState();
    }

    @Override
    public UserlandReadinessState readinessState() {
        return callbacks.readinessState();
    }

    @Override
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return callbacks.currentSurfaceStateSnapshot();
    }
}
