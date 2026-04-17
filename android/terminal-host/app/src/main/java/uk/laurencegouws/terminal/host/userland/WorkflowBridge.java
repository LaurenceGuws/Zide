package uk.laurencegouws.terminal.host.userland;

import android.content.Context;
import android.os.Handler;

import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandRelease;
import uk.laurencegouws.terminal.userland.UserlandWorkflowController;

/**
 * Adapts activity-owned callbacks to {@link UserlandWorkflowController.Host}.
 */
public final class WorkflowBridge implements UserlandWorkflowController.Host {
    /** Activity callbacks used by userland install and package workflows. */
    public interface Callbacks {
        UserlandRelease release();

        void appendEvent(String event);

        void applyInstallState(UserlandInstallState installState);

        void setInstallState(UserlandInstallState installState);

        void setReadinessState(UserlandReadinessState readinessState);

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
    public void setInstallState(UserlandInstallState installState) {
        callbacks.setInstallState(installState);
    }

    @Override
    public void setReadinessState(UserlandReadinessState readinessState) {
        callbacks.setReadinessState(readinessState);
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
