package uk.laurencegouws.terminal.host.ui;

import android.content.Context;
import android.os.Handler;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.SurfaceStateSnapshotReader;
import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.host.interaction.InteractionAssembly;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandWorkflowController;

/**
 * Immutable dependency bundle for {@link ProductTerminalWidgetAssemblyHost}.
 *
 * <p>Built by the activity during startup; preserves progressive field wiring (e.g. shell input)
 * via suppliers where the underlying field is assigned after earlier assembly steps.</p>
 */
public final class WidgetHostAssemblyContext {
    public final TerminalWidgetSlotId slot;
    public final Context harnessContext;
    public final Handler handler;
    public final ProductHostImeState productHostImeState;
    public final ActivityViewBindings activityViewBindings;
    public final Supplier<ShellInputView> shellInputView;
    public final InteractionAssembly.Result interaction;
    public final Supplier<UserlandReadinessState> currentReadinessState;
    public final Supplier<UserlandInstallState> currentInstallState;
    public final ProductHostStartupBundle hostStartup;
    public final StatusController statusController;
    public final SurfaceStateSnapshotReader surfaceStateSnapshotReader;
    public final ViewportController terminalViewportController;
    public final UserlandWorkflowController userlandWorkflowController;
    public final Consumer<String> sendDirectText;

    public WidgetHostAssemblyContext(
            TerminalWidgetSlotId slot,
            Context harnessContext,
            Handler handler,
            ProductHostImeState productHostImeState,
            ActivityViewBindings activityViewBindings,
            Supplier<ShellInputView> shellInputView,
            InteractionAssembly.Result interaction,
            Supplier<UserlandReadinessState> currentReadinessState,
            Supplier<UserlandInstallState> currentInstallState,
            ProductHostStartupBundle hostStartup,
            StatusController statusController,
            SurfaceStateSnapshotReader surfaceStateSnapshotReader,
            ViewportController terminalViewportController,
            UserlandWorkflowController userlandWorkflowController,
            Consumer<String> sendDirectText) {
        this.slot = slot;
        this.harnessContext = harnessContext;
        this.handler = handler;
        this.productHostImeState = productHostImeState;
        this.activityViewBindings = activityViewBindings;
        this.shellInputView = shellInputView;
        this.interaction = interaction;
        this.currentReadinessState = currentReadinessState;
        this.currentInstallState = currentInstallState;
        this.hostStartup = hostStartup;
        this.statusController = statusController;
        this.surfaceStateSnapshotReader = surfaceStateSnapshotReader;
        this.terminalViewportController = terminalViewportController;
        this.userlandWorkflowController = userlandWorkflowController;
        this.sendDirectText = sendDirectText;
    }
}
