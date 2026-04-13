package dev.zide.terminal.host;

import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;

/**
 * Adapts activity-owned callbacks to {@link UserlandSessionCoordinator.Host}.
 */
public final class TerminalUserlandSessionHostBridge implements UserlandSessionCoordinator.Host {
    /** Activity callbacks used by session refresh/apply telemetry flow. */
    public interface Callbacks {
        void appendEvent(String event);

        String shellStartStatusLabel(int status);

        void applyBootstrapState(UserlandBootstrapState bootstrapState);

        void refreshProductShellState();

        void refreshDebugStatusSurface();

        void updateStatus(String statusLabel);
    }

    private final Callbacks callbacks;

    public TerminalUserlandSessionHostBridge(Callbacks callbacks) {
        this.callbacks = callbacks;
    }

    @Override
    public void appendEvent(String event) {
        callbacks.appendEvent(event);
    }

    @Override
    public String shellStartStatusLabel(int status) {
        return callbacks.shellStartStatusLabel(status);
    }

    @Override
    public void applyBootstrapState(UserlandBootstrapState bootstrapState) {
        callbacks.applyBootstrapState(bootstrapState);
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
