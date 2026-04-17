package uk.laurencegouws.terminal.host.debug;

import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.StatusController;

/**
 * Startup-order null-guard forwards into {@link StatusController} for operator
 * telemetry hooks (e.g. package-doctor outcome) during progressive wiring.
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
}
