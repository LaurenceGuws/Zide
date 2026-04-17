package uk.laurencegouws.terminal.host.ui;

import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetController;
import uk.laurencegouws.terminal.selection.SelectionController;

/**
 * One hosted terminal widget instance: surface lifecycle bridge, surface host,
 * selection and gesture interaction, and the portable {@link SurfaceWidgetController}
 * seam for this instance.
 *
 * <p>The Android Harness may host multiple instances later (e.g. terminal tabs);
 * today there is exactly one, wired from {@code ZideActivity} startup.
 */
public final class TerminalWidgetInstance {
    public final SelectionController selectionController;
    public final GestureStateController gestureStateController;
    public final SurfaceBridge surfaceBridge;
    public final SurfaceController surfaceController;
    public final SurfaceWidgetController surfaceWidgetController;

    public TerminalWidgetInstance(
            SelectionController selectionController,
            GestureStateController gestureStateController,
            SurfaceBridge surfaceBridge,
            SurfaceController surfaceController,
            SurfaceWidgetController surfaceWidgetController) {
        this.selectionController = selectionController;
        this.gestureStateController = gestureStateController;
        this.surfaceBridge = surfaceBridge;
        this.surfaceController = surfaceController;
        this.surfaceWidgetController = surfaceWidgetController;
    }
}
