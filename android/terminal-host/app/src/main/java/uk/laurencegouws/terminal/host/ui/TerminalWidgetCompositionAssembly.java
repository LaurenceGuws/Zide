package uk.laurencegouws.terminal.host.ui;

import uk.laurencegouws.terminal.host.interaction.InteractionAssembly;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;

/**
 * Harness-owned composition seam for one terminal widget product instance.
 *
 * <p>Combines {@link InteractionAssembly} (selection + gesture) with {@link WidgetAssembly}
 * surface/chrome results into a {@link TerminalWidgetInstance}. {@link WidgetAssembly.Result}
 * remains the widget/chrome assembly output; this type performs the harness-owned join into the
 * portable instance holder without making {@code WidgetAssembly.Result} act as a terminal-instance
 * factory by itself.</p>
 *
 * <p>Future multi-view hosting would compose additional {@link TerminalWidgetInstance} values
 * through the same kind of seam; this class does not implement tab product behavior.</p>
 */
public final class TerminalWidgetCompositionAssembly {
    private TerminalWidgetCompositionAssembly() {
    }

    /**
     * Harness controllers co-hosted with the portable {@link TerminalWidgetInstance} (shell
     * presentation + app-shell chrome).
     */
    public static final class Result {
        public final ShellStatePresenter ShellStatePresenter;
        public final ChromeController terminalChromeController;
        public final ViewModeController terminalViewModeController;
        public final TerminalWidgetInstance terminalWidget;

        Result(
                ShellStatePresenter shellStatePresenter,
                ChromeController terminalChromeController,
                ViewModeController terminalViewModeController,
                TerminalWidgetInstance terminalWidget) {
            this.ShellStatePresenter = shellStatePresenter;
            this.terminalChromeController = terminalChromeController;
            this.terminalViewModeController = terminalViewModeController;
            this.terminalWidget = terminalWidget;
        }
    }

    /**
     * Joins interaction and widget assembly results into one {@link TerminalWidgetInstance} and
     * the co-hosted harness chrome/shell controllers.
     */
    public static Result compose(
            InteractionAssembly.Result interaction,
            WidgetAssembly.Result widget) {
        final TerminalWidgetInstance terminalWidget = new TerminalWidgetInstance(
                interaction.selectionController,
                interaction.GestureStateController,
                widget.surfaceHostBridge,
                widget.surfaceHostController,
                widget.terminalSurfaceWidgetController);
        return new Result(
                widget.ShellStatePresenter,
                widget.terminalChromeController,
                widget.terminalViewModeController,
                terminalWidget);
    }
}
