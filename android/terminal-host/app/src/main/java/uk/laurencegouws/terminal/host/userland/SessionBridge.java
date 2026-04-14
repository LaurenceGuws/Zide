package uk.laurencegouws.terminal.host.userland;

import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/**
 * Adapts activity-owned callbacks to {@link UserlandSessionCoordinator.Host}.
 */
public final class SessionBridge implements UserlandSessionCoordinator.Host {
    /** Activity callbacks used by session refresh/apply telemetry flow. */
    public interface Callbacks {
        void appendEvent(String event);

        String sessionStartStatusLabel(int status);

        void applyReadinessState(UserlandReadinessState readinessState);

        void refreshProductShellState();

        void refreshDebugStatusSurface();

        void updateStatus(String statusLabel);
    }

    private final Callbacks callbacks;

    public SessionBridge(Callbacks callbacks) {
        this.callbacks = callbacks;
    }

    @Override
    public void appendEvent(String event) {
        callbacks.appendEvent(event);
    }

    @Override
    public String sessionStartStatusLabel(int status) {
        return callbacks.sessionStartStatusLabel(status);
    }

    @Override
    public void applyReadinessState(UserlandReadinessState readinessState) {
        callbacks.applyReadinessState(readinessState);
    }

    @Override
    public void refreshProductShellState() {
        callbacks.refreshProductShellState();
    }

    @Override
    public void refreshDebugStatusSurface() {
        callbacks.refreshDebugStatusSurface();
    }

    @Override
    public void updateStatus(String statusLabel) {
        callbacks.updateStatus(statusLabel);
    }
}
