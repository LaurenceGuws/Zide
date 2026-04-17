package uk.laurencegouws.terminal.userland;

import uk.laurencegouws.terminal.session.ShellSessionController;

/**
 * Owns readiness-state refresh, shell polling, state application, and auto-start telemetry.
 *
 * <p>This is the one owner of the "read staged userland state, poll shell, apply runtime-facing
 * state" pass. It should not perform install work or mutate Android views directly.
 */
public final class UserlandSessionCoordinator {
    /** Host callbacks used for event formatting/logging. */
    public interface Host {
        void appendEvent(String event);

        String sessionStartStatusLabel(int status);

        void applyReadinessState(UserlandReadinessState readinessState);

        void refreshShellState();

        void refreshStatusTelemetry();

        void updateStatus(String statusLabel);
    }

    /** Result from one refresh pass. */
    public static final class RefreshResult {
        public final UserlandReadinessState readinessState;
        public final ShellSessionController.PollResult pollResult;

        public RefreshResult(UserlandReadinessState readinessState, ShellSessionController.PollResult pollResult) {
            this.readinessState = readinessState;
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

    public UserlandReadinessState loadReadinessState() {
        return shellSessionController.loadReadinessState();
    }

    public RefreshResult refresh(boolean logEvent) {
        final UserlandReadinessState readinessState = shellSessionController.loadReadinessState();
        final ShellSessionController.PollResult pollResult = shellSessionController.poll(readinessState);
        applyPollTelemetry(readinessState, pollResult, logEvent);
        return new RefreshResult(readinessState, pollResult);
    }

    public RefreshResult refreshAndApply(boolean logEvent) {
        final RefreshResult refreshResult = refresh(logEvent);
        host.applyReadinessState(refreshResult.readinessState);
        host.refreshShellState();
        host.refreshStatusTelemetry();
        return refreshResult;
    }

    private void applyPollTelemetry(
            UserlandReadinessState readinessState,
            ShellSessionController.PollResult pollResult,
            boolean logEvent) {
        if (pollResult.autoStarted) {
            host.appendEvent("auto.session.start status=" + host.sessionStartStatusLabel(pollResult.autoStartStatus));
        }
        if (pollResult.autoStartBlocked) {
            if (!readinessState.state.equals(lastAutoStartBlockedState)) {
                host.appendEvent(
                        "auto.session.start.blocked=" + readinessState.state +
                                " artifact=" + readinessState.artifact +
                                " version=" + readinessState.version);
                lastAutoStartBlockedState = readinessState.state;
            }
        } else {
            lastAutoStartBlockedState = "";
        }
        if (logEvent) {
            host.appendEvent("shell.session.refresh manual=true alive=" + pollResult.alive + " status="
                    + host.sessionStartStatusLabel(pollResult.status));
        }
    }
}
