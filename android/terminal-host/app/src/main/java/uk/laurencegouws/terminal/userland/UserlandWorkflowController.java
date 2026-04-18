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

        void applyInstallState(UserlandInstallState installState);

        void completeInstall(UserlandReadinessState readinessState);

        void failInstall(UserlandInstallState installState);

        void restartSessionAfterInstall(boolean logRefresh);

        void markPackageDoctorComplete(boolean success);
    }

    private final Host host;

    public UserlandWorkflowController(Host host) {
        this.host = host;
    }

    public void startInstall() {
        final UserlandRelease release = host.release();
        host.applyInstallState(UserlandInstallState.installing("Fetching and staging " + release.artifactName + "..."));
        host.appendEvent("userland.install.begin expected=" + release.artifactVersion);
        new Thread(() -> {
            try {
                final UserlandInstaller.Result result = UserlandInstaller.install(host.context(), release);
                host.handler().post(() -> {
                    host.appendEvent("userland.install.success " + result.detail);
                    host.completeInstall(result.readinessState);
                });
            } catch (IOException err) {
                host.handler().post(() -> {
                    final UserlandInstallState installState = UserlandInstallState.failed(
                            err.getMessage() == null ? "unknown install failure" : err.getMessage());
                    host.appendEvent(
                            "userland.install failed err=" + err.getClass().getSimpleName() + " detail=" + installState.detail);
                    host.failInstall(installState);
                });
            }
        }, "userland-install").start();
    }

    public void runPackageDoctor() {
        host.appendEvent("packages.doctor.begin");
        new Thread(() -> {
            try {
                final String prefixPath = UserlandPolicy.prefixPath(host.context());
                final String doctor = UserlandCommandRunner.runZidePm(
                        host.context(), "zide-pm-doctor", "doctor", "--prefix", prefixPath);
                final String available = UserlandCommandRunner.runZidePm(
                        host.context(), "zide-pm-list", "list-available", "--prefix", prefixPath);
                String installReport;
                try {
                    final String edge = UserlandAndroidTestBinaryPolicy.edgeTestPackageSpec();
                    final String installOut = UserlandCommandRunner.runZidePm(
                            host.context(),
                            "zide-pm-install-edge",
                            "install",
                            "--prefix",
                            prefixPath,
                            edge);
                    installReport = "install " + edge + " ok\n" + installOut.trim();
                } catch (IOException installErr) {
                    final String detail =
                            installErr.getMessage() == null ? installErr.getClass().getSimpleName() : installErr.getMessage();
                    installReport = "install edge package skipped/failed: " + detail;
                }
                final String combined =
                        doctor.trim() + "\n---\n" + available.trim() + "\n---\n" + installReport;
                host.handler().post(() -> {
                    logPackageDoctorOutput(combined);
                    host.appendEvent("packages.doctor.success");
                    host.markPackageDoctorComplete(true);
                });
            } catch (IOException err) {
                host.handler().post(() -> {
                    final String detail = err.getMessage() == null ? err.getClass().getSimpleName() : err.getMessage();
                    host.appendEvent("packages.doctor.output zide-pm failed: " + detail);
                    host.appendEvent("packages.doctor.failed err=" + err.getClass().getSimpleName());
                    host.markPackageDoctorComplete(false);
                });
            }
        }, "packages.doctor.state").start();
    }

    private void logPackageDoctorOutput(String combined) {
        final String[] lines = combined.split("\\R");
        for (int i = 0; i < lines.length; i++) {
            host.appendEvent("packages.doctor.output line=" + (i + 1) + " " + lines[i]);
        }
    }
}
