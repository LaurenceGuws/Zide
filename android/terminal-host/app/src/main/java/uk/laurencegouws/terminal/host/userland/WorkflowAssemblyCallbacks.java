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

    private final Supplier<Context> context;
    private final Supplier<Handler> handler;
    private final Supplier<UserlandRelease> userlandRelease;
    private final Consumer<UserlandRelease> setUserlandRelease;
    private final Consumer<UserlandInstallState> setInstallState;
    private final Consumer<UserlandReadinessState> setReadinessState;
    private final WorkflowActionBundle workflowActionBundle;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Supplier<TextView> packageStatusText;

    public WorkflowAssemblyCallbacks(
            Supplier<Context> context,
            Supplier<Handler> handler,
            Supplier<UserlandRelease> userlandRelease,
            Consumer<UserlandRelease> setUserlandRelease,
            Consumer<UserlandInstallState> setInstallState,
            Consumer<UserlandReadinessState> setReadinessState,
            WorkflowActionBundle workflowActionBundle,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Supplier<TextView> packageStatusText) {
        this.context = context;
        this.handler = handler;
        this.userlandRelease = userlandRelease;
        this.setUserlandRelease = setUserlandRelease;
        this.setInstallState = setInstallState;
        this.setReadinessState = setReadinessState;
        this.workflowActionBundle = workflowActionBundle;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.packageStatusText = packageStatusText;
    }

    @Override
    public Context context() {
        return context.get();
    }

    @Override
    public Handler handler() {
        return handler.get();
    }

    @Override
    public UserlandRelease userlandRelease() {
        return userlandRelease.get();
    }

    @Override
    public void setUserlandRelease(UserlandRelease userlandRelease) {
        setUserlandRelease.accept(userlandRelease);
    }

    @Override
    public void setInstallState(UserlandInstallState installState) {
        setInstallState.accept(installState);
    }

    @Override
    public void setReadinessState(UserlandReadinessState readinessState) {
        setReadinessState.accept(readinessState);
    }

    @Override
    public void applyInstallState(UserlandInstallState installState, String statusLabel) {
        workflowActionBundle.applyInstallState.accept(installState, statusLabel);
    }

    @Override
    public void restartSession(String eventName, String statusLabel, boolean logRefresh) {
        workflowActionBundle.restartSession.restart(eventName, statusLabel, logRefresh);
    }

    @Override
    public void showDebugView(String eventName, String statusLabel) {
        workflowActionBundle.showDebugView.accept(eventName, statusLabel);
    }

    @Override
    public void appendEvent(String message) {
        appendEvent.accept(message);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }

    @Override
    public TextView packageStatusText() {
        return packageStatusText.get();
    }
}
