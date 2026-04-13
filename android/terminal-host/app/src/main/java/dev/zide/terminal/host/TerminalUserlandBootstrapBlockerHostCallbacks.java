package dev.zide.terminal.host;

import java.util.function.BiConsumer;
import java.util.function.Consumer;
import java.util.function.Supplier;

import dev.zide.terminal.userland.UserlandBootstrapBlockerController;
import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;
import dev.zide.terminal.userland.UserlandWorkflowController;

/** Functional callback adapter for {@link UserlandBootstrapBlockerController}. */
public final class TerminalUserlandBootstrapBlockerHostCallbacks implements UserlandBootstrapBlockerController.Host {
    private final Supplier<UserlandInstallState> installState;
    private final Supplier<UserlandBootstrapState> bootstrapState;
    private final Supplier<UserlandWorkflowController> workflowController;
    private final Supplier<UserlandSessionCoordinator> sessionCoordinator;
    private final BiConsumer<String, String> showDebugView;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;

    public TerminalUserlandBootstrapBlockerHostCallbacks(
            Supplier<UserlandInstallState> installState,
            Supplier<UserlandBootstrapState> bootstrapState,
            Supplier<UserlandWorkflowController> workflowController,
            Supplier<UserlandSessionCoordinator> sessionCoordinator,
            BiConsumer<String, String> showDebugView,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus) {
        this.installState = installState;
        this.bootstrapState = bootstrapState;
        this.workflowController = workflowController;
        this.sessionCoordinator = sessionCoordinator;
        this.showDebugView = showDebugView;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
    }

    @Override
    public UserlandInstallState installState() {
        return installState.get();
    }

    @Override
    public UserlandBootstrapState bootstrapState() {
        return bootstrapState.get();
    }

    @Override
    public UserlandWorkflowController workflowController() {
        return workflowController.get();
    }

    @Override
    public UserlandSessionCoordinator sessionCoordinator() {
        return sessionCoordinator.get();
    }

    @Override
    public void showDebugView(String eventName, String statusLabel) {
        showDebugView.accept(eventName, statusLabel);
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }
}
