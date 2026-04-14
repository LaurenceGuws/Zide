package uk.laurencegouws.terminal.host.userland;

import java.util.function.Consumer;
import java.util.function.Function;

import uk.laurencegouws.terminal.userland.UserlandReadinessState;

/** Functional callback adapter for {@link SessionBridge}. */
public final class SessionCallbacks implements SessionBridge.Callbacks {
    private final Consumer<String> appendEvent;
    private final Function<Integer, String> shellStartStatusLabel;
    private final Consumer<UserlandReadinessState> applyReadinessState;
    private final Runnable refreshProductShellState;
    private final Runnable refreshDebugStatusSurface;
    private final Consumer<String> updateStatus;

    public SessionCallbacks(
            Consumer<String> appendEvent,
            Function<Integer, String> shellStartStatusLabel,
            Consumer<UserlandReadinessState> applyReadinessState,
            Runnable refreshProductShellState,
            Runnable refreshDebugStatusSurface,
            Consumer<String> updateStatus) {
        this.appendEvent = appendEvent;
        this.shellStartStatusLabel = shellStartStatusLabel;
        this.applyReadinessState = applyReadinessState;
        this.refreshProductShellState = refreshProductShellState;
        this.refreshDebugStatusSurface = refreshDebugStatusSurface;
        this.updateStatus = updateStatus;
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public String shellStartStatusLabel(int status) {
        return shellStartStatusLabel.apply(status);
    }

    @Override
    public void applyReadinessState(UserlandReadinessState readinessState) {
        applyReadinessState.accept(readinessState);
    }

    @Override
    public void refreshProductShellState() {
        refreshProductShellState.run();
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
