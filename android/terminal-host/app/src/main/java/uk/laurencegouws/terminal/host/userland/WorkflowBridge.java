package uk.laurencegouws.terminal.host.userland;

import android.content.Context;
import android.os.Handler;

import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandRelease;
import uk.laurencegouws.terminal.userland.UserlandWorkflowController;

/**
 * Adapts activity-owned callbacks to {@link UserlandWorkflowController.Host}.
 *
 * <p>Stable harness contract for install, package-doctor, and post-install session restart: see
 * {@code app_architecture/platform/android/USERLAND_HOST_CONTRACT.md}.
 */
public final class WorkflowBridge implements UserlandWorkflowController.Host {
    /** Harness callbacks used by userland install and package workflows. */
    public interface Callbacks {
        UserlandRelease release();

        void appendEvent(String event);

        void applyInstallState(UserlandInstallState installState);

        void completeInstall(UserlandReadinessState readinessState);

        void failInstall(UserlandInstallState installState);

        void restartSessionAfterInstall(boolean logRefresh);

        void markPackageDoctorComplete(boolean success);
    }

    private final Context context;
    private final Handler handler;
    private final Callbacks callbacks;

    public WorkflowBridge(Context context, Handler handler, Callbacks callbacks) {
        this.context = context;
        this.handler = handler;
        this.callbacks = callbacks;
    }

    @Override
    public Context context() {
        return context;
    }

    @Override
    public Handler handler() {
        return handler;
    }

    @Override
    public UserlandRelease release() {
        return callbacks.release();
    }

    @Override
    public void appendEvent(String event) {
        callbacks.appendEvent(event);
    }

    @Override
    public void applyInstallState(UserlandInstallState installState) {
        callbacks.applyInstallState(installState);
    }

    @Override
    public void completeInstall(UserlandReadinessState readinessState) {
        callbacks.completeInstall(readinessState);
    }

    @Override
    public void failInstall(UserlandInstallState installState) {
        callbacks.failInstall(installState);
    }

    @Override
    public void restartSessionAfterInstall(boolean logRefresh) {
        callbacks.restartSessionAfterInstall(logRefresh);
    }

    @Override
    public void markPackageDoctorComplete(boolean success) {
        callbacks.markPackageDoctorComplete(success);
    }
}
