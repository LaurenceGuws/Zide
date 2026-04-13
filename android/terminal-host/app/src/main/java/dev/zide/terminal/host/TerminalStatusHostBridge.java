package dev.zide.terminal.host;

import android.view.SurfaceView;

import dev.zide.terminal.debug.AndroidDebugFormatter;
import dev.zide.terminal.debug.TerminalStatusController;
import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandInstallState;

/**
 * Adapts activity-owned status callbacks to {@link TerminalStatusController.Host}.
 */
public final class TerminalStatusHostBridge implements TerminalStatusController.Host {
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

        UserlandBootstrapState bootstrapState();

        AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();
    }

    private final Callbacks callbacks;

    public TerminalStatusHostBridge(Callbacks callbacks) {
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
    public UserlandBootstrapState bootstrapState() {
        return callbacks.bootstrapState();
    }

    @Override
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return callbacks.currentSurfaceStateSnapshot();
    }
}
