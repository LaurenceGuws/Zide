package uk.laurencegouws.terminal.host.userland;

import android.content.Context;
import android.os.Handler;
import android.widget.TextView;

import java.util.function.BiConsumer;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandRelease;

/** Functional callback adapter for {@link WorkflowAssembly.Host}. */
public final class WorkflowAssemblyCallbacks implements WorkflowAssembly.Host {
    public static final class WorkflowHostCallbacks {
        final Supplier<Context> context;
        final Supplier<Handler> handler;
        final Supplier<UserlandRelease> userlandRelease;
        final Consumer<UserlandRelease> setUserlandRelease;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;
        final Supplier<TextView> packageStatusText;

        private WorkflowHostCallbacks(
                Supplier<Context> context,
                Supplier<Handler> handler,
                Supplier<UserlandRelease> userlandRelease,
                Consumer<UserlandRelease> setUserlandRelease,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                Supplier<TextView> packageStatusText) {
            this.context = context;
            this.handler = handler;
            this.userlandRelease = userlandRelease;
            this.setUserlandRelease = setUserlandRelease;
            this.appendEvent = appendEvent;
            this.updateStatus = updateStatus;
            this.packageStatusText = packageStatusText;
        }

        public static WorkflowHostCallbacks of(
                Supplier<Context> context,
                Supplier<Handler> handler,
                Supplier<UserlandRelease> userlandRelease,
                Consumer<UserlandRelease> setUserlandRelease,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                Supplier<TextView> packageStatusText) {
            return new WorkflowHostCallbacks(
                    context,
                    handler,
                    userlandRelease,
                    setUserlandRelease,
                    appendEvent,
                    updateStatus,
                    packageStatusText);
        }
    }

    public static final class WorkflowActionCallbacks {
        final BiConsumer<UserlandInstallState, String> applyInstallState;
        final WorkflowCallbacks.RestartSessionCallback restartSession;
        final BiConsumer<String, String> showDebugView;

        private WorkflowActionCallbacks(
                BiConsumer<UserlandInstallState, String> applyInstallState,
                WorkflowCallbacks.RestartSessionCallback restartSession,
                BiConsumer<String, String> showDebugView) {
            this.applyInstallState = applyInstallState;
            this.restartSession = restartSession;
            this.showDebugView = showDebugView;
        }

        public static WorkflowActionCallbacks of(
                BiConsumer<UserlandInstallState, String> applyInstallState,
                WorkflowCallbacks.RestartSessionCallback restartSession,
                BiConsumer<String, String> showDebugView) {
            return new WorkflowActionCallbacks(
                    applyInstallState,
                    restartSession,
                    showDebugView);
        }
    }

    public static final class WorkflowRuntimeCallbacks {
        final Consumer<UserlandInstallState> setInstallState;
        final Consumer<UserlandReadinessState> setReadinessState;
        final WorkflowActionCallbacks workflowActionCallbacks;

        private WorkflowRuntimeCallbacks(
                Consumer<UserlandInstallState> setInstallState,
                Consumer<UserlandReadinessState> setReadinessState,
                WorkflowActionCallbacks workflowActionCallbacks) {
            this.setInstallState = setInstallState;
            this.setReadinessState = setReadinessState;
            this.workflowActionCallbacks = workflowActionCallbacks;
        }

        public static WorkflowRuntimeCallbacks of(
                Consumer<UserlandInstallState> setInstallState,
                Consumer<UserlandReadinessState> setReadinessState,
                WorkflowActionCallbacks workflowActionCallbacks) {
            return new WorkflowRuntimeCallbacks(
                    setInstallState,
                    setReadinessState,
                    workflowActionCallbacks);
        }
    }

    private final WorkflowHostCallbacks workflowHostCallbacks;
    private final WorkflowRuntimeCallbacks workflowRuntimeCallbacks;

    public WorkflowAssemblyCallbacks(
            WorkflowHostCallbacks workflowHostCallbacks,
            WorkflowRuntimeCallbacks workflowRuntimeCallbacks) {
        this.workflowHostCallbacks = workflowHostCallbacks;
        this.workflowRuntimeCallbacks = workflowRuntimeCallbacks;
    }

    @Override
    public Context context() {
        return workflowHostCallbacks.context.get();
    }

    @Override
    public Handler handler() {
        return workflowHostCallbacks.handler.get();
    }

    @Override
    public UserlandRelease userlandRelease() {
        return workflowHostCallbacks.userlandRelease.get();
    }

    @Override
    public void setUserlandRelease(UserlandRelease userlandRelease) {
        workflowHostCallbacks.setUserlandRelease.accept(userlandRelease);
    }

    @Override
    public void setInstallState(UserlandInstallState installState) {
        workflowRuntimeCallbacks.setInstallState.accept(installState);
    }

    @Override
    public void setReadinessState(UserlandReadinessState readinessState) {
        workflowRuntimeCallbacks.setReadinessState.accept(readinessState);
    }

    @Override
    public void applyInstallState(UserlandInstallState installState, String statusLabel) {
        workflowRuntimeCallbacks.workflowActionCallbacks.applyInstallState.accept(installState, statusLabel);
    }

    @Override
    public void restartSession(String eventName, String statusLabel, boolean logRefresh) {
        workflowRuntimeCallbacks.workflowActionCallbacks.restartSession.restart(eventName, statusLabel, logRefresh);
    }

    @Override
    public void showDebugView(String eventName, String statusLabel) {
        workflowRuntimeCallbacks.workflowActionCallbacks.showDebugView.accept(eventName, statusLabel);
    }

    @Override
    public void appendEvent(String message) {
        workflowHostCallbacks.appendEvent.accept(message);
    }

    @Override
    public void updateStatus(String statusLabel) {
        workflowHostCallbacks.updateStatus.accept(statusLabel);
    }

    @Override
    public TextView packageStatusText() {
        return workflowHostCallbacks.packageStatusText.get();
    }
}
