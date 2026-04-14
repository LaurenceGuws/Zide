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
    public static final class WorkflowHostBundle {
        final Supplier<Context> context;
        final Supplier<Handler> handler;
        final Supplier<UserlandRelease> userlandRelease;
        final Consumer<UserlandRelease> setUserlandRelease;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;
        final Supplier<TextView> packageStatusText;

        private WorkflowHostBundle(
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

        public static WorkflowHostBundle of(
                Supplier<Context> context,
                Supplier<Handler> handler,
                Supplier<UserlandRelease> userlandRelease,
                Consumer<UserlandRelease> setUserlandRelease,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                Supplier<TextView> packageStatusText) {
            return new WorkflowHostBundle(
                    context,
                    handler,
                    userlandRelease,
                    setUserlandRelease,
                    appendEvent,
                    updateStatus,
                    packageStatusText);
        }
    }

    public static final class WorkflowActionBundle {
        final BiConsumer<UserlandInstallState, String> applyInstallState;
        final WorkflowCallbacks.RestartSessionCallback restartSession;
        final BiConsumer<String, String> showDebugView;

        private WorkflowActionBundle(
                BiConsumer<UserlandInstallState, String> applyInstallState,
                WorkflowCallbacks.RestartSessionCallback restartSession,
                BiConsumer<String, String> showDebugView) {
            this.applyInstallState = applyInstallState;
            this.restartSession = restartSession;
            this.showDebugView = showDebugView;
        }

        public static WorkflowActionBundle of(
                BiConsumer<UserlandInstallState, String> applyInstallState,
                WorkflowCallbacks.RestartSessionCallback restartSession,
                BiConsumer<String, String> showDebugView) {
            return new WorkflowActionBundle(
                    applyInstallState,
                    restartSession,
                    showDebugView);
        }
    }

    public static final class WorkflowRuntimeBundle {
        final Consumer<UserlandInstallState> setInstallState;
        final Consumer<UserlandReadinessState> setReadinessState;
        final WorkflowActionBundle workflowActionBundle;

        private WorkflowRuntimeBundle(
                Consumer<UserlandInstallState> setInstallState,
                Consumer<UserlandReadinessState> setReadinessState,
                WorkflowActionBundle workflowActionBundle) {
            this.setInstallState = setInstallState;
            this.setReadinessState = setReadinessState;
            this.workflowActionBundle = workflowActionBundle;
        }

        public static WorkflowRuntimeBundle of(
                Consumer<UserlandInstallState> setInstallState,
                Consumer<UserlandReadinessState> setReadinessState,
                WorkflowActionBundle workflowActionBundle) {
            return new WorkflowRuntimeBundle(
                    setInstallState,
                    setReadinessState,
                    workflowActionBundle);
        }
    }

    private final WorkflowHostBundle workflowHostBundle;
    private final WorkflowRuntimeBundle workflowRuntimeBundle;

    public WorkflowAssemblyCallbacks(
            WorkflowHostBundle workflowHostBundle,
            WorkflowRuntimeBundle workflowRuntimeBundle) {
        this.workflowHostBundle = workflowHostBundle;
        this.workflowRuntimeBundle = workflowRuntimeBundle;
    }

    @Override
    public Context context() {
        return workflowHostBundle.context.get();
    }

    @Override
    public Handler handler() {
        return workflowHostBundle.handler.get();
    }

    @Override
    public UserlandRelease userlandRelease() {
        return workflowHostBundle.userlandRelease.get();
    }

    @Override
    public void setUserlandRelease(UserlandRelease userlandRelease) {
        workflowHostBundle.setUserlandRelease.accept(userlandRelease);
    }

    @Override
    public void setInstallState(UserlandInstallState installState) {
        workflowRuntimeBundle.setInstallState.accept(installState);
    }

    @Override
    public void setReadinessState(UserlandReadinessState readinessState) {
        workflowRuntimeBundle.setReadinessState.accept(readinessState);
    }

    @Override
    public void applyInstallState(UserlandInstallState installState, String statusLabel) {
        workflowRuntimeBundle.workflowActionBundle.applyInstallState.accept(installState, statusLabel);
    }

    @Override
    public void restartSession(String eventName, String statusLabel, boolean logRefresh) {
        workflowRuntimeBundle.workflowActionBundle.restartSession.restart(eventName, statusLabel, logRefresh);
    }

    @Override
    public void showDebugView(String eventName, String statusLabel) {
        workflowRuntimeBundle.workflowActionBundle.showDebugView.accept(eventName, statusLabel);
    }

    @Override
    public void appendEvent(String message) {
        workflowHostBundle.appendEvent.accept(message);
    }

    @Override
    public void updateStatus(String statusLabel) {
        workflowHostBundle.updateStatus.accept(statusLabel);
    }

    @Override
    public TextView packageStatusText() {
        return workflowHostBundle.packageStatusText.get();
    }
}
