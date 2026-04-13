package dev.zide.terminal.userland;

import dev.zide.terminal.session.ShellSessionController;

/**
 * Owns bootstrap-state refresh, shell polling, state application, and auto-start telemetry.
 *
 * <p>This is the one owner of the "read staged userland state, poll shell, apply product/debug
 * state" pass. It should not perform install work or mutate Android views directly.
 */
public final class UserlandSessionCoordinator {
    /** Host callbacks used for event formatting/logging. */
    public interface Host {
        void appendEvent(String event);

        String shellStartStatusLabel(int status);

        void applyBootstrapState(UserlandBootstrapState bootstrapState);

        void refreshProductShellState();

        void refreshDebugStatusSurface();

        void updateStatus(String statusLabel);
    }

    /** Result from one refresh pass. */
    public static final class RefreshResult {
        public final UserlandBootstrapState bootstrapState;
        public final ShellSessionController.PollResult pollResult;

        public RefreshResult(UserlandBootstrapState bootstrapState, ShellSessionController.PollResult pollResult) {
            this.bootstrapState = bootstrapState;
            this.pollResult = pollResult;
        }
    }

    private final ShellSessionController shellSessionController;
    private final Host host;
    private String lastAutoStartBlockedState = "";

    public UserlandSessionCoordinator(ShellSessionController shellSessionController, Host host) {
        this.shellSessionController = shellSessionController;
        this.host = host;
    }

    public UserlandBootstrapState loadBootstrapState() {
        return shellSessionController.loadBootstrapState();
    }

    public RefreshResult refresh(boolean logEvent) {
        final UserlandBootstrapState bootstrapState = shellSessionController.loadBootstrapState();
        final ShellSessionController.PollResult pollResult = shellSessionController.poll(bootstrapState);
        applyPollTelemetry(bootstrapState, pollResult, logEvent);
        return new RefreshResult(bootstrapState, pollResult);
    }

    public RefreshResult refreshAndApply(boolean logEvent) {
        final RefreshResult refreshResult = refresh(logEvent);
        host.applyBootstrapState(refreshResult.bootstrapState);
        host.refreshProductShellState();
        host.refreshDebugStatusSurface();
        return refreshResult;
    }

    private void applyPollTelemetry(
            UserlandBootstrapState bootstrapState,
            ShellSessionController.PollResult pollResult,
            boolean logEvent) {
        if (pollResult.autoStarted) {
            host.appendEvent("auto.shellStart status=" + host.shellStartStatusLabel(pollResult.autoStartStatus));
        }
        if (pollResult.autoStartBlocked) {
            if (!bootstrapState.state.equals(lastAutoStartBlockedState)) {
                host.appendEvent(
                        "auto.shellStart blocked=" + bootstrapState.state +
                                " artifact=" + bootstrapState.artifact +
                                " version=" + bootstrapState.version);
                lastAutoStartBlockedState = bootstrapState.state;
            }
        } else {
            lastAutoStartBlockedState = "";
        }
        if (logEvent) {
            host.appendEvent("shell.sessionRefresh manual=true alive=" + pollResult.alive + " status="
                    + host.shellStartStatusLabel(pollResult.status));
        }
    }
}
