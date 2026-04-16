package uk.laurencegouws.terminal.host.runtime;

import android.view.SurfaceView;
import android.view.View;

import uk.laurencegouws.terminal.debug.NativeStatusLabels;
import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.scroll.ScrollOverlayView;
import uk.laurencegouws.terminal.selection.SelectionController;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/** Owns product runtime orchestration for frame-loop and shell-state refresh flow. */
public final class RuntimeController {
    /** Host callbacks for activity-owned state and native bridge interactions. */
    public interface Host {
        boolean debugViewEnabled();

        boolean nativeLoaded();

        UserlandInstallState installState();

        void setInstallState(UserlandInstallState installState);

        UserlandReadinessState readinessState();

        SurfaceView surfaceView();

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

        int nativeCurrentSessionVisibleRows();

        int nativeCurrentSessionScrollbackCount();

        int nativeCurrentSessionScrollbackOffset();

        int nativeRestartSession();
    }

    private final Host host;

    public RuntimeController(Host host) {
        this.host = host;
    }

    public boolean shouldRunFrameLoop() {
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

    public void refreshShellState() {
        final ShellStatePresenter presenter = host.ShellStatePresenter();
        if (presenter != null) {
            presenter.refresh();
        }
        refreshScrollOverlay();
        final FrameLoopController frameLoopController = host.frameLoopController();
        if (frameLoopController != null) {
            frameLoopController.reevaluate();
        }
    }

    public void refreshDebugStatusSurface() {
        final StatusController statusController = host.StatusController();
        if (statusController != null) {
            statusController.refreshDebugStatusSurface();
        }
    }

    public void handleShellStateEvent(String statusLabel) {
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

    public void refreshScrollOverlay() {
        final ScrollOverlayView scrollOverlay = host.terminalScrollOverlay();
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
                || host.productReadinessBlocker().getVisibility() == View.VISIBLE) {
            scrollOverlay.updateScrollMetrics(0, 0, 0);
            return;
        }
        scrollOverlay.updateScrollMetrics(
                host.nativeCurrentSessionVisibleRows(),
                host.nativeCurrentSessionScrollbackCount(),
                host.nativeCurrentSessionScrollbackOffset());
        final SelectionController selectionController = host.selectionController();
        if (selectionController != null) {
            selectionController.syncChrome();
        }
    }

    public void stopScrollbackFling() {
        final GestureStateController gestureStateController = host.GestureStateController();
        if (gestureStateController != null) {
            gestureStateController.stopScrollbackFling();
        }
    }

    public void applyInstallState(UserlandInstallState installState, String statusLabel) {
        host.setInstallState(installState);
        refreshShellState();
        host.updateStatus(statusLabel);
    }

    public void restartSession(String eventName, String statusLabel, boolean logRefresh) {
        final int status = host.nativeLoaded() ? host.nativeRestartSession() : 0;
        host.appendEvent(eventName + " status=" + NativeStatusLabels.sessionStartStatusLabel(status));
        final UserlandSessionCoordinator sessionCoordinator = host.userlandSessionCoordinator();
        if (sessionCoordinator != null) {
            sessionCoordinator.refreshAndApply(logRefresh);
        }
        host.updateStatus(statusLabel);
    }
}
