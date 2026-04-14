package uk.laurencegouws.terminal.host.userland;

import android.content.Context;
import android.os.Handler;
import android.widget.TextView;

import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsController;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsBridge;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsCallbacks;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandRelease;
import uk.laurencegouws.terminal.userland.UserlandWorkflowController;

/** Owns userland runtime-assets/workflow host assembly for activity wiring. */
public final class WorkflowAssembly {
    /** Activity callbacks required for userland workflow assembly. */
    public interface Host {
        Context context();

        Handler handler();

        UserlandRelease userlandRelease();

        void setUserlandRelease(UserlandRelease userlandRelease);

        void setInstallState(UserlandInstallState installState);

        void setReadinessState(UserlandReadinessState readinessState);

        void applyInstallState(UserlandInstallState installState, String statusLabel);

        void restartSession(String eventName, String statusLabel, boolean logRefresh);

        void showDebugView(String eventName, String statusLabel);

        void appendEvent(String message);

        void updateStatus(String statusLabel);

        TextView packageStatusText();
    }

    /** Immutable assembled userland workflow result. */
    public static final class Result {
        public final RuntimeAssetsController runtimeAssetsController;
        public final WorkflowBridge userlandWorkflowHostBridge;
        public final UserlandWorkflowController userlandWorkflowController;

        private Result(
                RuntimeAssetsController runtimeAssetsController,
                WorkflowBridge userlandWorkflowHostBridge,
                UserlandWorkflowController userlandWorkflowController) {
            this.runtimeAssetsController = runtimeAssetsController;
            this.userlandWorkflowHostBridge = userlandWorkflowHostBridge;
            this.userlandWorkflowController = userlandWorkflowController;
        }
    }

    private WorkflowAssembly() {
    }

    public static Result assemble(Host host) {
        final RuntimeAssetsController runtimeAssetsController = new RuntimeAssetsController(
                new RuntimeAssetsBridge(
                        host.context(),
                        new RuntimeAssetsCallbacks(host::appendEvent)));
        host.setUserlandRelease(runtimeAssetsController.loadUserlandRelease());
        final WorkflowBridge userlandWorkflowHostBridge = new WorkflowBridge(
                host.context(),
                host.handler(),
                new WorkflowCallbacks(
                        host::userlandRelease,
                        host::appendEvent,
                        host::applyInstallState,
                        host::setInstallState,
                        host::setReadinessState,
                        host::restartSession,
                        host::showDebugView,
                        host.packageStatusText(),
                        host::updateStatus));
        return new Result(
                runtimeAssetsController,
                userlandWorkflowHostBridge,
                new UserlandWorkflowController(userlandWorkflowHostBridge));
    }
}
