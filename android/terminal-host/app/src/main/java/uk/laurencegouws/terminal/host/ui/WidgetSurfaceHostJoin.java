package uk.laurencegouws.terminal.host.ui;

import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetController;

/**
 * Surface host join slice produced by {@link WidgetAssembly} for {@link TerminalWidgetCompositionAssembly}.
 *
 * <p>Separates surface lifecycle/controller refs from harness chrome/shell controllers so composition
 * consumes only the portable surface seam. Future multi-slot hosting can pass one join per slot
 * without expanding {@link WidgetAssembly.Result} field fan-out.</p>
 */
public final class WidgetSurfaceHostJoin {
    public final SurfaceBridge surfaceHostBridge;
    public final SurfaceController surfaceHostController;
    public final SurfaceWidgetController surfaceWidgetController;

    public WidgetSurfaceHostJoin(
            SurfaceBridge surfaceHostBridge,
            SurfaceController surfaceHostController,
            SurfaceWidgetController surfaceWidgetController) {
        this.surfaceHostBridge = surfaceHostBridge;
        this.surfaceHostController = surfaceHostController;
        this.surfaceWidgetController = surfaceWidgetController;
    }
}
