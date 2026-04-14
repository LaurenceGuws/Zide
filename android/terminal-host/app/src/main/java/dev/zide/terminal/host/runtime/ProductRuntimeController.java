package dev.zide.terminal.host.runtime;

import android.view.SurfaceView;
import android.view.View;

import dev.zide.terminal.debug.TerminalNativeStatusLabels;
import dev.zide.terminal.debug.TerminalStatusController;
import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.scroll.TerminalScrollOverlayView;
import dev.zide.terminal.selection.TerminalSelectionController;
import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;

/** Owns product runtime orchestration for frame-loop and shell-state refresh flow. */
public final class ProductRuntimeController {
    /** Host callbacks for activity-owned state and native bridge interactions. */
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

        FrameLoopController frameLoopController();

        TerminalStatusController terminalStatusController();

        UserlandSessionCoordinator userlandSessionCoordinator();

        TerminalGestureStateController terminalGestureStateController();

        void appendEvent(String message);

        void updateStatus(String statusLabel);

        int nativeCurrentShellVisibleRows();

        int nativeCurrentShellScrollbackCount();

        int nativeCurrentShellScrollbackOffset();

        int nativeRestartShellSession();
    }

    private final Host host;

    public ProductRuntimeController(Host host) {
        this.host = host;
    }

    public boolean shouldRunProductFrameLoop() {
        final SurfaceView activeSurfaceView = host.surfaceView();
        final UserlandInstallState installState = host.installState();
        final UserlandReadinessState readinessState = host.readinessState();
        return !host.debugViewEnabled()
                && host.nativeLoaded()
                && !installState.isInstalling()
                && !installState.isFailed()
                && readinessState != null
                && readinessState.launchReady
                && readinessState.expectedCurrent
                && activeSurfaceView != null
                && activeSurfaceView.getHolder().getSurface().isValid();
    }

    public void refreshProductShellState() {
        final ProductShellStatePresenter presenter = host.productShellStatePresenter();
        if (presenter != null) {
            presenter.refresh();
        }
        refreshProductScrollOverlay();
        final FrameLoopController frameLoopController = host.frameLoopController();
        if (frameLoopController != null) {
            frameLoopController.reevaluate();
        }
    }

    public void refreshDebugStatusSurface() {
        final TerminalStatusController statusController = host.terminalStatusController();
        if (statusController != null) {
            statusController.refreshDebugStatusSurface();
        }
    }

    public void handleProductShellStateEvent(String statusLabel) {
        final UserlandSessionCoordinator sessionCoordinator = host.userlandSessionCoordinator();
        if (sessionCoordinator != null) {
            sessionCoordinator.refreshAndApply(false);
        }
        final FrameLoopController frameLoopController = host.frameLoopController();
        if (frameLoopController != null) {
            frameLoopController.reevaluate();
        }
        host.updateStatus(statusLabel);
    }

    public void refreshProductScrollOverlay() {
        final TerminalScrollOverlayView scrollOverlay = host.terminalScrollOverlay();
        if (scrollOverlay == null) {
            return;
        }
        final UserlandInstallState installState = host.installState();
        final UserlandReadinessState readinessState = host.readinessState();
        if (host.debugViewEnabled()
                || !host.nativeLoaded()
                || installState.isInstalling()
                || installState.isFailed()
                || readinessState == null
                || !readinessState.launchReady
                || !readinessState.expectedCurrent
                || host.productBootstrapBlocker().getVisibility() == View.VISIBLE) {
            scrollOverlay.updateScrollMetrics(0, 0, 0);
            return;
        }
        scrollOverlay.updateScrollMetrics(
                host.nativeCurrentShellVisibleRows(),
                host.nativeCurrentShellScrollbackCount(),
                host.nativeCurrentShellScrollbackOffset());
        final TerminalSelectionController selectionController = host.selectionController();
        if (selectionController != null) {
            selectionController.syncChrome();
        }
    }

    public void stopScrollbackFling() {
        final TerminalGestureStateController gestureStateController = host.terminalGestureStateController();
        if (gestureStateController != null) {
            gestureStateController.stopScrollbackFling();
        }
    }

    public void applyInstallState(UserlandInstallState installState, String statusLabel) {
        host.setInstallState(installState);
        refreshProductShellState();
        host.updateStatus(statusLabel);
    }

    public void restartShellSession(String eventName, String statusLabel, boolean logRefresh) {
        final int status = host.nativeLoaded() ? host.nativeRestartShellSession() : 0;
        host.appendEvent(eventName + " status=" + TerminalNativeStatusLabels.shellStartStatusLabel(status));
        final UserlandSessionCoordinator sessionCoordinator = host.userlandSessionCoordinator();
        if (sessionCoordinator != null) {
            sessionCoordinator.refreshAndApply(logRefresh);
        }
        host.updateStatus(statusLabel);
    }
}
