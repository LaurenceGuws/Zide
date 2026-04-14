package dev.zide.terminal.host;

import android.content.Context;
import android.os.Handler;
import android.widget.TextView;

import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandRelease;
import dev.zide.terminal.userland.UserlandWorkflowController;

/** Owns userland runtime-assets/workflow host assembly for activity wiring. */
public final class TerminalUserlandWorkflowAssembly {
    /** Activity callbacks required for userland workflow assembly. */
    public interface Host {
        Context context();

        Handler handler();

        UserlandRelease userlandRelease();

        void setUserlandRelease(UserlandRelease userlandRelease);

        void setInstallState(UserlandInstallState installState);

        void setBootstrapState(UserlandBootstrapState bootstrapState);

        void applyInstallState(UserlandInstallState installState, String statusLabel);

        void restartShellSession(String eventName, String statusLabel, boolean logRefresh);

        void showDebugView(String eventName, String statusLabel);

        void appendEvent(String message);

        void updateStatus(String statusLabel);

        TextView packageStatusText();
    }

    /** Immutable assembled userland workflow result. */
    public static final class Result {
        public final TerminalRuntimeAssetsController runtimeAssetsController;
        public final TerminalUserlandWorkflowHostBridge userlandWorkflowHostBridge;
        public final UserlandWorkflowController userlandWorkflowController;

        private Result(
                TerminalRuntimeAssetsController runtimeAssetsController,
                TerminalUserlandWorkflowHostBridge userlandWorkflowHostBridge,
                UserlandWorkflowController userlandWorkflowController) {
            this.runtimeAssetsController = runtimeAssetsController;
            this.userlandWorkflowHostBridge = userlandWorkflowHostBridge;
            this.userlandWorkflowController = userlandWorkflowController;
        }
    }

    private TerminalUserlandWorkflowAssembly() {
    }

    public static Result assemble(Host host) {
        final TerminalRuntimeAssetsController runtimeAssetsController = new TerminalRuntimeAssetsController(
                new TerminalRuntimeAssetsHostBridge(
                        host.context(),
                        new TerminalRuntimeAssetsHostCallbacks(host::appendEvent)));
        host.setUserlandRelease(runtimeAssetsController.loadUserlandRelease());
        final TerminalUserlandWorkflowHostBridge userlandWorkflowHostBridge = new TerminalUserlandWorkflowHostBridge(
                host.context(),
                host.handler(),
                new TerminalUserlandWorkflowHostCallbacks(
                        host::userlandRelease,
                        host::appendEvent,
                        host::applyInstallState,
                        host::setInstallState,
                        host::setBootstrapState,
                        host::restartShellSession,
                        host::showDebugView,
                        host.packageStatusText(),
                        host::updateStatus));
        return new Result(
                runtimeAssetsController,
                userlandWorkflowHostBridge,
                new UserlandWorkflowController(userlandWorkflowHostBridge));
    }
}
