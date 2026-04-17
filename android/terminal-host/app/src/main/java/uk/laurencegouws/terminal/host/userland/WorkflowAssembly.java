package uk.laurencegouws.terminal.host.userland;

import android.content.Context;
import android.os.Handler;

import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsController;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsBridge;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsCallbacks;
import uk.laurencegouws.terminal.userland.UserlandRelease;
import uk.laurencegouws.terminal.userland.UserlandWorkflowController;

/** Owns userland runtime-assets/workflow host assembly for activity wiring. */
public final class WorkflowAssembly {
    /** Functional callback for shell restart requests. */
    public interface RestartSessionCallback {
        void restart(String eventName, String statusLabel, boolean logRefresh);
    }

    /** Activity callbacks required for userland workflow assembly. */
    public interface Host extends WorkflowBridge.Callbacks {
        Context context();

        Handler handler();

        void setUserlandRelease(UserlandRelease userlandRelease);
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
                host);
        return new Result(
                runtimeAssetsController,
                userlandWorkflowHostBridge,
                new UserlandWorkflowController(userlandWorkflowHostBridge));
    }
}
