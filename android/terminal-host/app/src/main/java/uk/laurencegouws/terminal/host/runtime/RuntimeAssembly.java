package uk.laurencegouws.terminal.host.runtime;

import android.view.View;

import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.scroll.ScrollOverlayView;
import uk.laurencegouws.terminal.selection.SelectionController;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/** Owns product-runtime controller assembly for activity wiring. */
public final class RuntimeAssembly {
    /** Activity callbacks required for product-runtime assembly. */
    public interface Host {
        UserlandInstallState installState();

        void setInstallState(UserlandInstallState installState);

        UserlandReadinessState readinessState();

        SurfaceBridge surfaceHostBridge();

        View productReadinessBlocker();

        ScrollOverlayView terminalScrollOverlay();

        SelectionController selectionController();

        ShellStatePresenter ShellStatePresenter();

        FrameLoopController frameLoopController();

        StatusController StatusController();

        UserlandSessionCoordinator userlandSessionCoordinator();

        GestureStateController GestureStateController();

        void appendEvent(String message);

        void updateStatus(String statusLabel);
    }

    private RuntimeAssembly() {
    }

    public static RuntimeController assemble(Host host) {
        return RuntimeFactory.createRuntimeController(
                RuntimeFactory.createRuntimeHostCallbacks(
                        host::installState,
                        host::setInstallState,
                        host::readinessState,
                        host::surfaceHostBridge,
                        host.productReadinessBlocker(),
                        host.terminalScrollOverlay(),
                        host.selectionController(),
                        host.ShellStatePresenter(),
                        host.frameLoopController(),
                        host.StatusController(),
                        host.userlandSessionCoordinator(),
                        host.GestureStateController(),
                        host::appendEvent,
                        host::updateStatus));
    }
}
