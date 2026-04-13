package dev.zide.terminal.host;

import android.content.Context;
import android.os.Handler;

import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandRelease;
import dev.zide.terminal.userland.UserlandWorkflowController;

/**
 * Adapts activity-owned callbacks to {@link UserlandWorkflowController.Host}.
 */
public final class TerminalUserlandWorkflowHostBridge implements UserlandWorkflowController.Host {
    /** Activity callbacks used by userland install and package workflows. */
    public interface Callbacks {
        UserlandRelease release();

        void appendEvent(String event);

        void applyInstallState(UserlandInstallState installState, String statusLabel);

        void setInstallState(UserlandInstallState installState);

        void setBootstrapState(UserlandBootstrapState bootstrapState);

        void restartShellSession(String eventName, String statusLabel, boolean logRefresh);

        void showDebugView(String eventName, String statusLabel);

        void setPackageStatusText(String text);

        void updateStatus(String statusLabel);
    }

    private final Context context;
    private final Handler handler;
    private final Callbacks callbacks;

    public TerminalUserlandWorkflowHostBridge(Context context, Handler handler, Callbacks callbacks) {
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
    public void applyInstallState(UserlandInstallState installState, String statusLabel) {
        callbacks.applyInstallState(installState, statusLabel);
    }

    @Override
    public void setInstallState(UserlandInstallState installState) {
        callbacks.setInstallState(installState);
    }

    @Override
    public void setBootstrapState(UserlandBootstrapState bootstrapState) {
        callbacks.setBootstrapState(bootstrapState);
    }

    @Override
    public void restartShellSession(String eventName, String statusLabel, boolean logRefresh) {
        callbacks.restartShellSession(eventName, statusLabel, logRefresh);
    }

    @Override
    public void showDebugView(String eventName, String statusLabel) {
        callbacks.showDebugView(eventName, statusLabel);
    }

    @Override
    public void setPackageStatusText(String text) {
        callbacks.setPackageStatusText(text);
    }

    @Override
    public void updateStatus(String statusLabel) {
        callbacks.updateStatus(statusLabel);
    }
}
