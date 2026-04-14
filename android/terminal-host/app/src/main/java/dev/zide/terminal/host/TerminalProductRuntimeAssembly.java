package dev.zide.terminal.host;

import android.view.SurfaceView;
import android.view.View;

import dev.zide.terminal.TerminalNativeBridge;
import dev.zide.terminal.debug.TerminalStatusController;
import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.scroll.TerminalScrollOverlayView;
import dev.zide.terminal.selection.TerminalSelectionController;
import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;

/** Owns product-runtime controller assembly for activity wiring. */
public final class TerminalProductRuntimeAssembly {
    /** Activity callbacks required for product-runtime assembly. */
    public interface Host {
        boolean debugViewEnabled();

        boolean nativeLoaded();

        UserlandInstallState installState();

        void setInstallState(UserlandInstallState installState);

        UserlandReadinessState readinessState();

        SurfaceView surfaceView();

        View productBootstrapBlocker();

        TerminalScrollOverlayView terminalScrollOverlay();

        TerminalSelectionController selectionController();

        ProductShellStatePresenter productShellStatePresenter();

        TerminalFrameLoopController frameLoopController();

        TerminalStatusController terminalStatusController();

        UserlandSessionCoordinator userlandSessionCoordinator();

        TerminalGestureStateController terminalGestureStateController();

        void appendEvent(String message);

        void updateStatus(String statusLabel);
    }

    private TerminalProductRuntimeAssembly() {
    }

    public static TerminalProductRuntimeController assemble(Host host) {
        return TerminalRuntimeHostFactory.createProductRuntimeController(
                TerminalRuntimeHostFactory.createProductRuntimeHostCallbacks(
                        host::debugViewEnabled,
                        host::nativeLoaded,
                        host::installState,
                        host::setInstallState,
                        host::readinessState,
                        host::surfaceView,
                        host::productBootstrapBlocker,
                        host::terminalScrollOverlay,
                        host::selectionController,
                        host::productShellStatePresenter,
                        host::frameLoopController,
                        host::terminalStatusController,
                        host::userlandSessionCoordinator,
                        host::terminalGestureStateController,
                        host::appendEvent,
                        host::updateStatus,
                        TerminalNativeBridge::nativeCurrentShellVisibleRowsBridge,
                        TerminalNativeBridge::nativeCurrentShellScrollbackCountBridge,
                        TerminalNativeBridge::nativeCurrentShellScrollbackOffsetBridge,
                        TerminalNativeBridge::nativeRestartShellSessionBridge));
    }
}
