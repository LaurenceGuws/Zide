package uk.laurencegouws.terminal.host.userland;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.userland.UserlandReadinessBlockerController;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;
import uk.laurencegouws.terminal.userland.UserlandWorkflowController;

/** Functional callback adapter for {@link UserlandReadinessBlockerController}. */
public final class ReadinessBlockerCallbacks implements UserlandReadinessBlockerController.Host {
    private final Supplier<UserlandInstallState> installState;
    private final Supplier<UserlandReadinessState> readinessState;
    private final UserlandWorkflowController workflowController;
    private final UserlandSessionCoordinator sessionCoordinator;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;

    public ReadinessBlockerCallbacks(
            Supplier<UserlandInstallState> installState,
            Supplier<UserlandReadinessState> readinessState,
            UserlandWorkflowController workflowController,
            UserlandSessionCoordinator sessionCoordinator,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus) {
        this.installState = installState;
        this.readinessState = readinessState;
        this.workflowController = workflowController;
        this.sessionCoordinator = sessionCoordinator;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
    }

    @Override
    public UserlandInstallState installState() {
        return installState.get();
    }

    @Override
    public UserlandReadinessState readinessState() {
        return readinessState.get();
    }

    @Override
    public UserlandWorkflowController workflowController() {
        return workflowController;
    }

    @Override
    public UserlandSessionCoordinator sessionCoordinator() {
        return sessionCoordinator;
    }

    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }
}
