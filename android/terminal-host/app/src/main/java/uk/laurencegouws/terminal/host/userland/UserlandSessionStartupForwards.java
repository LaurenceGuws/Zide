package uk.laurencegouws.terminal.host.userland;

import java.util.function.Supplier;

import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/**
 * Startup-order null-guard forwards into {@link UserlandSessionCoordinator}.
 */
public final class UserlandSessionStartupForwards {
    private final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;

    public UserlandSessionStartupForwards(
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator) {
        this.userlandSessionCoordinator = userlandSessionCoordinator;
    }

    public void refreshUserlandSessionIfReady() {
        final UserlandSessionCoordinator c = userlandSessionCoordinator.get();
        if (c != null) {
            c.refreshAndApply(false);
        }
    }
}
