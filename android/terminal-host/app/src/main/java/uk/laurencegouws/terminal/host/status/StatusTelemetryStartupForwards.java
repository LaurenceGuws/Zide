package uk.laurencegouws.terminal.host.status;

import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.StatusController;

/**
 * Startup-order null-guard forwards into {@link StatusController} for operator
 * telemetry hooks (e.g. package-doctor outcome) during progressive wiring.
 *
 * <p>Lives under {@code host.status} because this is status/operator telemetry,
 * not debug-view UI ownership.
 */
public final class StatusTelemetryStartupForwards {
    private final Supplier<StatusController> statusController;

    public StatusTelemetryStartupForwards(Supplier<StatusController> statusController) {
        this.statusController = statusController;
    }

    public void markPackageDoctorCompleteIfReady(boolean success) {
        final StatusController s = statusController.get();
        if (s != null) {
            s.recordPackageDoctorOutcome(success);
        }
    }

    public void markAndroidEdgeTestBinaryInstallCompleteIfReady(boolean success) {
        final StatusController s = statusController.get();
        if (s != null) {
            s.recordAndroidEdgeTestBinaryInstallOutcome(success);
        }
    }
}
