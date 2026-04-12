package dev.zide.terminal;

final class UserlandInstallState {
    static final String STATUS_IDLE = "idle";
    static final String STATUS_INSTALLING = "installing";
    static final String STATUS_FAILED = "failed";

    final String status;
    final String detail;

    UserlandInstallState(String status, String detail) {
        this.status = status;
        this.detail = detail;
    }

    static UserlandInstallState idle() {
        return new UserlandInstallState(STATUS_IDLE, "");
    }

    static UserlandInstallState installing(String detail) {
        return new UserlandInstallState(STATUS_INSTALLING, detail);
    }

    static UserlandInstallState failed(String detail) {
        return new UserlandInstallState(STATUS_FAILED, detail);
    }

    boolean isInstalling() {
        return STATUS_INSTALLING.equals(status);
    }

    boolean isFailed() {
        return STATUS_FAILED.equals(status);
    }
}
