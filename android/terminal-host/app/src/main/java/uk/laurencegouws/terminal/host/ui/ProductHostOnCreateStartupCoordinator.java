package uk.laurencegouws.terminal.host.ui;

import uk.laurencegouws.terminal.host.interaction.InteractionAssembly;

/**
 * Owns the product onCreate startup <em>call order</em> for the terminal host activity.
 * Harness assembly bodies remain on {@link uk.laurencegouws.terminal.ZideActivity}
 * (wiring edge); this class is choreography only — no widened globals and no policy.
 */
public final class ProductHostOnCreateStartupCoordinator {
    private ProductHostOnCreateStartupCoordinator() {
    }

    /**
     * Runs the fixed startup sequence. Order must match the B23 super-gate list.
     */
    public static void run(final ProductHostOnCreateStartupSteps steps) {
        steps.initializeStatusAndViewControllers();
        final InteractionAssembly.Result interaction = steps.assembleInteraction();
        steps.assembleUserlandWorkflowControllers();
        steps.assembleSessionControllers();
        steps.applyTerminalWidgetComposition(interaction);
        steps.assembleRuntimeController();
        steps.assembleActivityLifecycleController();
        steps.loadInitialReadinessState();
        steps.installInputControllers();
        steps.bindAndStartUiControllers();
        steps.onTerminalLifecycleControllerCreate();
    }
}
