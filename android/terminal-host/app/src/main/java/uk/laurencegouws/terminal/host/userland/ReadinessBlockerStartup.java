package uk.laurencegouws.terminal.host.userland;

import android.widget.Button;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandReadinessBlockerController;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;

/**
 * Harness-owned wiring for {@link UserlandReadinessBlockerController}; keeps install/session
 * orchestration entrypoints in {@code host.userland} instead of {@code host.ui} startup assembly.
 */
public final class ReadinessBlockerStartup {
    private ReadinessBlockerStartup() {
    }

    /** Binds the product readiness retry control; returns the controller for tests or lifecycle if needed. */
    public static UserlandReadinessBlockerController bind(
            Button retryButton,
            Supplier<UserlandInstallState> installState,
            Supplier<UserlandReadinessState> readinessState,
            Runnable startInstall,
            Runnable refreshSessionAfterReadinessRetry,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus) {
        final UserlandReadinessBlockerController controller = new UserlandReadinessBlockerController(
                retryButton,
                new ReadinessBlockerCallbacks(
                        installState,
                        readinessState,
                        startInstall,
                        refreshSessionAfterReadinessRetry,
                        appendEvent,
                        updateStatus));
        controller.bind();
        return controller;
    }
}
