package uk.laurencegouws.terminal.host.surface;

import java.util.function.Supplier;

/**
 * Startup-order null-guard forwards into {@link SurfaceController}.
 */
public final class SurfaceStartupForwards {
    private final Supplier<SurfaceController> surfaceHostController;

    public SurfaceStartupForwards(Supplier<SurfaceController> surfaceHostController) {
        this.surfaceHostController = surfaceHostController;
    }

    public void notifyVisibleViewportIfReady(String reason) {
        final SurfaceController c = surfaceHostController.get();
        if (c != null) {
            c.notifyVisibleViewport(reason);
        }
    }

    public void pauseSurfaceIfReady() {
        final SurfaceController c = surfaceHostController.get();
        if (c != null) {
            c.onPause();
        }
    }

    public void resumeSurfaceIfReady(
            boolean debugRecreateSurfaceOnce,
            boolean debugResizeSurfaceOnce,
            boolean debugStartShellOnce) {
        final SurfaceController c = surfaceHostController.get();
        if (c != null) {
            c.onResume(
                    debugRecreateSurfaceOnce,
                    debugResizeSurfaceOnce,
                    debugStartShellOnce);
        }
    }
}
