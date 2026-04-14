package uk.laurencegouws.terminal.userland;

/**
 * Immutable UI-facing state for one in-app userland install/update operation.
 *
 * <p>This is presentation state only; install execution belongs to {@link UserlandWorkflowController}
 * and archive extraction belongs to {@link UserlandInstaller}.
 */
public final class UserlandInstallState {
    public static final String STATUS_IDLE = "idle";
    public static final String STATUS_INSTALLING = "installing";
    public static final String STATUS_FAILED = "failed";

    public final String status;
    public final String detail;

    public UserlandInstallState(String status, String detail) {
        this.status = status;
        this.detail = detail;
    }

    public static UserlandInstallState idle() {
        return new UserlandInstallState(STATUS_IDLE, "");
    }

    public static UserlandInstallState installing(String detail) {
        return new UserlandInstallState(STATUS_INSTALLING, detail);
    }

    public static UserlandInstallState failed(String detail) {
        return new UserlandInstallState(STATUS_FAILED, detail);
    }

    public boolean isInstalling() {
        return STATUS_INSTALLING.equals(status);
    }

    public boolean isFailed() {
        return STATUS_FAILED.equals(status);
    }
}
