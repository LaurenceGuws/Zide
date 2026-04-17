package uk.laurencegouws.terminal.host.userland;

import java.util.function.Consumer;

import uk.laurencegouws.terminal.host.runtime.RuntimeStartupForwards;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;

/**
 * Startup-order glue for install completion that updates harness-held readiness
 * snapshots then delegates session restart to {@link RuntimeController}. Keeps
 * install-state mutation adjacent to workflow wiring without growing {@code ZideActivity}.
 */
public final class WorkflowInstallStartupGlue {
    private final Consumer<UserlandInstallState> setInstallState;
    private final Consumer<UserlandReadinessState> setReadinessState;
    private final RuntimeStartupForwards runtimeStartup;

    public WorkflowInstallStartupGlue(
            Consumer<UserlandInstallState> setInstallState,
            Consumer<UserlandReadinessState> setReadinessState,
            RuntimeStartupForwards runtimeStartup) {
        this.setInstallState = setInstallState;
        this.setReadinessState = setReadinessState;
        this.runtimeStartup = runtimeStartup;
    }

    public void completeInstallIfReady(UserlandReadinessState readinessState) {
        setInstallState.accept(UserlandInstallState.idle());
        setReadinessState.accept(readinessState);
        runtimeStartup.restartSessionAfterInstallIfReady(true);
    }

    public void failInstallIfReady(UserlandInstallState installState) {
        runtimeStartup.applyInstallStateIfReady(installState);
    }
}
