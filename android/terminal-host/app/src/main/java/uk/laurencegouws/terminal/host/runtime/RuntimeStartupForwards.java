package uk.laurencegouws.terminal.host.runtime;

import java.util.function.Supplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
/**
 * Startup-order null-guard forwards into {@link RuntimeController}. Not product
 * policy; only bridges wiring that completes after {@code onCreate} sequencing.
 */
public final class RuntimeStartupForwards {
    private final Supplier<RuntimeController> runtimeController;

    public RuntimeStartupForwards(Supplier<RuntimeController> runtimeController) {
        this.runtimeController = runtimeController;
    }

    public void stopScrollbackFlingIfReady() {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.stopScrollbackFling();
        }
    }

    public void refreshScrollOverlayIfReady() {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.refreshScrollOverlay();
        }
    }

    public void refreshShellStateIfReady() {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.refreshShellState();
        }
    }

    public void refreshStatusTelemetryIfReady() {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.refreshStatusTelemetry();
        }
    }

    public void handleShellStateEventIfReady() {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.handleShellStateEvent();
        }
    }

    public void applyInstallStateIfReady(UserlandInstallState installState) {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.applyInstallState(installState);
        }
    }

    public void restartSessionAfterInstallIfReady(boolean logRefresh) {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.restartSessionAfterInstall(logRefresh);
        }
    }

    public void restartShellSessionForProductTabIfReady(final int tabIndex, final boolean logRefresh) {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.restartShellSessionForProductTab(tabIndex, logRefresh);
        }
    }

    public boolean shouldRunFrameLoop() {
        final RuntimeController c = runtimeController.get();
        return c != null && c.shouldRunFrameLoop();
    }

    public int tickFrameAndRefreshScrollOverlay(boolean nativeLoaded) {
        final int tick = nativeLoaded ? NativeBridge.nativeTickFrameBridge() : 0;
        refreshScrollOverlayIfReady();
        return tick;
    }
}
