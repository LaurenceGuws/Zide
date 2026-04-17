package uk.laurencegouws.terminal.host.ui;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.host.debug.StatusTelemetryStartupForwards;
import uk.laurencegouws.terminal.host.input.InputChromeStartupForwards;
import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.runtime.FrameLoopStartupForwards;
import uk.laurencegouws.terminal.host.runtime.RuntimeController;
import uk.laurencegouws.terminal.host.runtime.RuntimeStartupForwards;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceStartupForwards;
import uk.laurencegouws.terminal.host.userland.UserlandSessionStartupForwards;
import uk.laurencegouws.terminal.host.userland.WorkflowInstallStartupGlue;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;
import uk.laurencegouws.terminal.input.HardwareKeyboardController;
import uk.laurencegouws.terminal.input.ImeFocusRecoveryController;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;

/**
 * Aggregates owner-aligned startup forwarders for {@code ZideActivity} wiring.
 *
 * <p>This is not a second activity backbone: each field delegates to one domain
 * (runtime, frame loop, surface, userland session, input/chrome, telemetry,
 * workflow install completion). It exists only because controller references are
 * assigned progressively during {@code onCreate} and early callbacks must remain
 * null-safe until their owner exists.
 */
public final class ProductHostStartupBundle {
    public final RuntimeStartupForwards runtime;
    public final FrameLoopStartupForwards frameLoop;
    public final SurfaceStartupForwards surface;
    public final UserlandSessionStartupForwards userlandSession;
    public final InputChromeStartupForwards inputChrome;
    public final StatusTelemetryStartupForwards telemetry;
    public final WorkflowInstallStartupGlue workflowInstall;

    private ProductHostStartupBundle(
            RuntimeStartupForwards runtime,
            FrameLoopStartupForwards frameLoop,
            SurfaceStartupForwards surface,
            UserlandSessionStartupForwards userlandSession,
            InputChromeStartupForwards inputChrome,
            StatusTelemetryStartupForwards telemetry,
            WorkflowInstallStartupGlue workflowInstall) {
        this.runtime = runtime;
        this.frameLoop = frameLoop;
        this.surface = surface;
        this.userlandSession = userlandSession;
        this.inputChrome = inputChrome;
        this.telemetry = telemetry;
        this.workflowInstall = workflowInstall;
    }

    public static ProductHostStartupBundle create(
            Supplier<RuntimeController> runtimeController,
            Supplier<FrameLoopController> frameLoopController,
            Supplier<SurfaceController> surfaceHostController,
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
            Supplier<HardwareKeyboardController> hardwareKeyboardController,
            Supplier<ImeFocusRecoveryController> imeFocusRecoveryController,
            Supplier<ChromeController> chromeController,
            Supplier<StatusController> statusController,
            Consumer<UserlandInstallState> setInstallState,
            Consumer<UserlandReadinessState> setReadinessState) {
        final RuntimeStartupForwards runtime = new RuntimeStartupForwards(runtimeController);
        return new ProductHostStartupBundle(
                runtime,
                new FrameLoopStartupForwards(frameLoopController),
                new SurfaceStartupForwards(surfaceHostController),
                new UserlandSessionStartupForwards(userlandSessionCoordinator),
                new InputChromeStartupForwards(
                        hardwareKeyboardController,
                        imeFocusRecoveryController,
                        chromeController),
                new StatusTelemetryStartupForwards(statusController),
                new WorkflowInstallStartupGlue(
                        setInstallState,
                        setReadinessState,
                        runtime));
    }
}
