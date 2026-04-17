package uk.laurencegouws.terminal.host.userland;

import android.content.Context;
import android.os.Handler;

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
    private final Consumer<UserlandInstallState> setInstallState;
    private final Consumer<UserlandReadinessState> setReadinessState;
    private final Consumer<UserlandInstallState> applyInstallState;
    private final WorkflowAssembly.RestartSessionCallback restartSession;
    private final WorkflowAssembly.PackageDoctorStateCallback packageDoctorState;

    public WorkflowAssemblyCallbacks(
            Context context,
            Handler handler,
            Supplier<UserlandRelease> userlandRelease,
            Consumer<UserlandRelease> setUserlandRelease,
            Consumer<String> appendEvent,
            Consumer<UserlandInstallState> setInstallState,
            Consumer<UserlandReadinessState> setReadinessState,
            Consumer<UserlandInstallState> applyInstallState,
            WorkflowAssembly.RestartSessionCallback restartSession,
            WorkflowAssembly.PackageDoctorStateCallback packageDoctorState) {
        this.context = context;
        this.handler = handler;
        this.userlandRelease = userlandRelease;
        this.setUserlandRelease = setUserlandRelease;
        this.appendEvent = appendEvent;
        this.setInstallState = setInstallState;
        this.setReadinessState = setReadinessState;
        this.applyInstallState = applyInstallState;
        this.restartSession = restartSession;
        this.packageDoctorState = packageDoctorState;
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
    public void applyInstallState(UserlandInstallState installState) {
        applyInstallState.accept(installState);
    }

    @Override
    public void restartSessionAfterInstall(boolean logRefresh) {
        restartSession.restartAfterInstall(logRefresh);
    }

    @Override
    public void appendEvent(String message) {
        appendEvent.accept(message);
    }

    @Override
    public void markPackageDoctorComplete(boolean success) {
        packageDoctorState.markComplete(success);
    }

}
