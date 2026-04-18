package uk.laurencegouws.terminal.host.ui;

import uk.laurencegouws.terminal.host.interaction.InteractionAssembly;

/**
 * Harness-owned onCreate assembly phases for {@link ZideActivity}, ordered by
 * {@link ProductHostOnCreateStartupCoordinator}. Implementations live on the activity
 * wiring edge; this type is the typed seam for progressive startup without making
 * the activity the choreography owner.
 */
public interface ProductHostOnCreateStartupSteps {
    void initializeStatusAndViewControllers();

    InteractionAssembly.Result assembleInteraction();

    void assembleUserlandWorkflowControllers();

    void assembleSessionControllers();

    void applyTerminalWidgetComposition(InteractionAssembly.Result interaction);

    void assembleRuntimeController();

    void assembleActivityLifecycleController();

    void loadInitialReadinessState();

    void installInputControllers();

    void bindAndStartUiControllers();

    void onTerminalLifecycleControllerCreate();
}
