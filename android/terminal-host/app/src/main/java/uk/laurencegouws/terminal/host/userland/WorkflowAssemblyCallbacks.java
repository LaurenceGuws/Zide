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
    private final Consumer<UserlandInstallState> applyInstallState;
    private final Consumer<UserlandReadinessState> completeInstall;
    private final Consumer<UserlandInstallState> failInstall;
    private final WorkflowAssembly.RestartSessionCallback restartSession;
    private final WorkflowAssembly.PackageDoctorStateCallback packageDoctorState;
    private final WorkflowAssembly.EdgeTestBinaryInstallStateCallback edgeTestBinaryInstallState;

    public WorkflowAssemblyCallbacks(
            Context context,
            Handler handler,
            Supplier<UserlandRelease> userlandRelease,
            Consumer<UserlandRelease> setUserlandRelease,
            Consumer<String> appendEvent,
            Consumer<UserlandInstallState> applyInstallState,
            Consumer<UserlandReadinessState> completeInstall,
            Consumer<UserlandInstallState> failInstall,
            WorkflowAssembly.RestartSessionCallback restartSession,
            WorkflowAssembly.PackageDoctorStateCallback packageDoctorState,
            WorkflowAssembly.EdgeTestBinaryInstallStateCallback edgeTestBinaryInstallState) {
        this.context = context;
        this.handler = handler;
        this.userlandRelease = userlandRelease;
        this.setUserlandRelease = setUserlandRelease;
        this.appendEvent = appendEvent;
        this.applyInstallState = applyInstallState;
        this.completeInstall = completeInstall;
        this.failInstall = failInstall;
        this.restartSession = restartSession;
        this.packageDoctorState = packageDoctorState;
        this.edgeTestBinaryInstallState = edgeTestBinaryInstallState;
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
    public void completeInstall(UserlandReadinessState readinessState) {
        completeInstall.accept(readinessState);
    }

    @Override
    public void failInstall(UserlandInstallState installState) {
        failInstall.accept(installState);
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

    @Override
    public void markAndroidEdgeTestBinaryInstallComplete(boolean success) {
        edgeTestBinaryInstallState.markComplete(success);
    }

    @Override
    public void markAndroidEdgeTestBinaryInstallNoCandidate() {
        edgeTestBinaryInstallState.markNoCandidate();
    }

}
