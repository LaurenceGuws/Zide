package uk.laurencegouws.terminal.userland;

import android.content.Context;
import android.os.Handler;
import java.io.IOException;

/** Owns asynchronous userland install and package-doctor workflow execution. */
public final class UserlandWorkflowController {
    /** Host callbacks for UI/state integration. */
    public interface Host {
        Context context();

        Handler handler();

        UserlandRelease release();

        void appendEvent(String event);

        void applyInstallState(UserlandInstallState installState, String statusLabel);

        void setInstallState(UserlandInstallState installState);

        void setReadinessState(UserlandReadinessState readinessState);

        void restartShellSession(String eventName, String statusLabel, boolean logRefresh);

        void showDebugView(String eventName, String statusLabel);

        void setPackageStatusText(String text);

        void updateStatus(String statusLabel);
    }

    private final Host host;

    public UserlandWorkflowController(Host host) {
        this.host = host;
    }

    public void startInstall() {
        final UserlandRelease release = host.release();
        host.applyInstallState(
                UserlandInstallState.installing("Fetching and staging " + release.artifactName + "..."),
                "userland-install-started");
        host.appendEvent("userland.install begin expected=" + release.artifactVersion);
        new Thread(() -> {
            try {
                final UserlandInstaller.Result result = UserlandInstaller.install(host.context(), release);
                host.handler().post(() -> {
                    host.setInstallState(UserlandInstallState.idle());
                    host.setReadinessState(result.readinessState);
                    host.appendEvent("userland.install success " + result.detail);
                    host.restartShellSession("userland.install sessionRestart", "userland-install-succeeded-restarted", true);
                });
            } catch (IOException err) {
                host.handler().post(() -> {
                    final UserlandInstallState installState = UserlandInstallState.failed(
                            err.getMessage() == null ? "unknown install failure" : err.getMessage());
                    host.appendEvent(
                            "userland.install failed err=" + err.getClass().getSimpleName() + " detail=" + installState.detail);
                    host.applyInstallState(installState, "userland-install-failed");
                });
            }
        }, "userland-install").start();
    }

    public void runPackageDoctor() {
        host.setPackageStatusText("Running zide-pm...");
        host.showDebugView("packages.doctor begin", "packages-doctor");
        new Thread(() -> {
            try {
                final String prefixPath = UserlandPolicy.prefixPath(host.context());
                final String doctor = UserlandCommandRunner.runZidePm(
                        host.context(), "zide-pm-doctor", "doctor", "--prefix", prefixPath);
                final String available = UserlandCommandRunner.runZidePm(
                        host.context(), "zide-pm-list", "list-available", "--prefix", prefixPath);
                final String combined = doctor.trim() + "\n---\n" + available.trim();
                host.handler().post(() -> {
                    host.setPackageStatusText(combined);
                    host.appendEvent("packages.doctor success");
                    host.updateStatus("packages-doctor");
                });
            } catch (IOException err) {
                host.handler().post(() -> {
                    final String detail = err.getMessage() == null ? err.getClass().getSimpleName() : err.getMessage();
                    host.setPackageStatusText("zide-pm failed: " + detail);
                    host.appendEvent("packages.doctor failed err=" + err.getClass().getSimpleName());
                    host.updateStatus("packages-doctor-failed");
                });
            }
        }, "packages-doctor").start();
    }
}
