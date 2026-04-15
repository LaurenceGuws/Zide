package uk.laurencegouws.terminal.host.runtime;

import android.view.SurfaceView;
import android.view.View;

import uk.laurencegouws.terminal.TerminalNativeBridge;
import uk.laurencegouws.terminal.debug.TerminalStatusController;
import uk.laurencegouws.terminal.gesture.TerminalGestureStateController;
import uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView;
import uk.laurencegouws.terminal.selection.TerminalSelectionController;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.userland.ProductShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/** Owns product-runtime controller assembly for activity wiring. */
public final class ProductRuntimeAssembly {
    /** Activity callbacks required for product-runtime assembly. */
    public interface Host {
        boolean debugViewEnabled();

        UserlandInstallState installState();

        void setInstallState(UserlandInstallState installState);

        UserlandReadinessState readinessState();

        SurfaceBridge surfaceHostBridge();

        View productReadinessBlocker();

        TerminalScrollOverlayView terminalScrollOverlay();

        TerminalSelectionController selectionController();

        ProductShellStatePresenter productShellStatePresenter();

        FrameLoopController frameLoopController();

        TerminalStatusController terminalStatusController();

        UserlandSessionCoordinator userlandSessionCoordinator();

        TerminalGestureStateController terminalGestureStateController();

        void appendEvent(String message);

        void updateStatus(String statusLabel);
    }

    private ProductRuntimeAssembly() {
    }

    public static ProductRuntimeController assemble(Host host) {
        return RuntimeFactory.createProductRuntimeController(
                RuntimeFactory.createProductRuntimeHostCallbacks(
                        host::debugViewEnabled,
                        host::installState,
                        host::setInstallState,
                        host::readinessState,
                        host::surfaceHostBridge,
                        host.productReadinessBlocker(),
                        host.terminalScrollOverlay(),
                        host.selectionController(),
                        host.productShellStatePresenter(),
                        host.frameLoopController(),
                        host.terminalStatusController(),
                        host.userlandSessionCoordinator(),
                        host.terminalGestureStateController(),
                        host::appendEvent,
                        host::updateStatus));
    }
}
