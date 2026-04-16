package uk.laurencegouws.terminal.host.userland;

import java.util.function.Consumer;
import java.util.function.IntFunction;

import uk.laurencegouws.terminal.userland.UserlandReadinessState;

/** Functional callback adapter for {@link SessionBridge}. */
public final class SessionCallbacks implements SessionBridge.Callbacks {
    private final Consumer<String> appendEvent;
    private final IntFunction<String> sessionStartStatusLabel;
    private final Consumer<UserlandReadinessState> applyReadinessState;
    private final Runnable refreshShellState;
    private final Runnable refreshDebugStatusSurface;
    private final Consumer<String> updateStatus;

    public SessionCallbacks(
            Consumer<String> appendEvent,
            IntFunction<String> sessionStartStatusLabel,
            Consumer<UserlandReadinessState> applyReadinessState,
            Runnable refreshShellState,
            Runnable refreshDebugStatusSurface,
            Consumer<String> updateStatus) {
        this.appendEvent = appendEvent;
        this.sessionStartStatusLabel = sessionStartStatusLabel;
        this.applyReadinessState = applyReadinessState;
        this.refreshShellState = refreshShellState;
        this.refreshDebugStatusSurface = refreshDebugStatusSurface;
        this.updateStatus = updateStatus;
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public String sessionStartStatusLabel(int status) {
        return sessionStartStatusLabel.apply(status);
    }

    @Override
    public void applyReadinessState(UserlandReadinessState readinessState) {
        applyReadinessState.accept(readinessState);
    }

    @Override
    public void refreshShellState() {
        refreshShellState.run();
    }

    @Override
    public void refreshDebugStatusSurface() {
        refreshDebugStatusSurface.run();
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }
}
