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
    private final Context context;
    private final Handler handler;
    private final Supplier<UserlandRelease> userlandRelease;
    private final Consumer<UserlandRelease> setUserlandRelease;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final TextView packageStatusText;
    private final Consumer<UserlandInstallState> setInstallState;
    private final Consumer<UserlandReadinessState> setReadinessState;
    private final BiConsumer<UserlandInstallState, String> applyInstallState;
    private final WorkflowAssembly.RestartSessionCallback restartSession;
    private final BiConsumer<String, String> showDebugView;

    public WorkflowAssemblyCallbacks(
            Context context,
            Handler handler,
            Supplier<UserlandRelease> userlandRelease,
            Consumer<UserlandRelease> setUserlandRelease,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            TextView packageStatusText,
            Consumer<UserlandInstallState> setInstallState,
            Consumer<UserlandReadinessState> setReadinessState,
            BiConsumer<UserlandInstallState, String> applyInstallState,
            WorkflowAssembly.RestartSessionCallback restartSession,
            BiConsumer<String, String> showDebugView) {
        this.context = context;
        this.handler = handler;
        this.userlandRelease = userlandRelease;
        this.setUserlandRelease = setUserlandRelease;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.packageStatusText = packageStatusText;
        this.setInstallState = setInstallState;
        this.setReadinessState = setReadinessState;
        this.applyInstallState = applyInstallState;
        this.restartSession = restartSession;
        this.showDebugView = showDebugView;
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
        applyInstallState.accept(installState, statusLabel);
    }

    @Override
    public void restartSession(String eventName, String statusLabel, boolean logRefresh) {
        restartSession.restart(eventName, statusLabel, logRefresh);
    }

    @Override
    public void showDebugView(String eventName, String statusLabel) {
        showDebugView.accept(eventName, statusLabel);
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
        return packageStatusText;
    }
}
