package uk.laurencegouws.terminal.host.userland;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.userland.UserlandReadinessBlockerController;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Functional callback adapter for {@link UserlandReadinessBlockerController}. */
public final class ReadinessBlockerCallbacks implements UserlandReadinessBlockerController.Host {
    private final Supplier<UserlandInstallState> installState;
    private final Supplier<UserlandReadinessState> readinessState;
    private final Runnable startInstallAction;
    private final Runnable refreshSessionAfterReadinessRetryAction;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;

    public ReadinessBlockerCallbacks(
            Supplier<UserlandInstallState> installState,
            Supplier<UserlandReadinessState> readinessState,
            Runnable startInstallAction,
            Runnable refreshSessionAfterReadinessRetryAction,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus) {
        this.installState = installState;
        this.readinessState = readinessState;
        this.startInstallAction = startInstallAction;
        this.refreshSessionAfterReadinessRetryAction = refreshSessionAfterReadinessRetryAction;
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
    public void startInstall() {
        startInstallAction.run();
    }

    @Override
    public void refreshSessionAfterReadinessRetry() {
        refreshSessionAfterReadinessRetryAction.run();
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
