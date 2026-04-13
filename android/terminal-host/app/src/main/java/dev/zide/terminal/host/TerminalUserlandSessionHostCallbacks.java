package dev.zide.terminal.host;

import java.util.function.Consumer;
import java.util.function.Function;

import dev.zide.terminal.userland.UserlandBootstrapState;

/** Functional callback adapter for {@link TerminalUserlandSessionHostBridge}. */
public final class TerminalUserlandSessionHostCallbacks implements TerminalUserlandSessionHostBridge.Callbacks {
    private final Consumer<String> appendEvent;
    private final Function<Integer, String> shellStartStatusLabel;
    private final Consumer<UserlandBootstrapState> applyBootstrapState;
    private final Runnable refreshProductShellState;
    private final Runnable refreshDebugStatusSurface;
    private final Consumer<String> updateStatus;

    public TerminalUserlandSessionHostCallbacks(
            Consumer<String> appendEvent,
            Function<Integer, String> shellStartStatusLabel,
            Consumer<UserlandBootstrapState> applyBootstrapState,
            Runnable refreshProductShellState,
            Runnable refreshDebugStatusSurface,
            Consumer<String> updateStatus) {
        this.appendEvent = appendEvent;
        this.shellStartStatusLabel = shellStartStatusLabel;
        this.applyBootstrapState = applyBootstrapState;
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
    public void applyBootstrapState(UserlandBootstrapState bootstrapState) {
        applyBootstrapState.accept(bootstrapState);
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
