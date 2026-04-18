package uk.laurencegouws.terminal.host.ui;

import uk.laurencegouws.terminal.host.userland.ShellStateBridge;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;

/**
 * Non-surface harness controllers from {@link WidgetAssembly} (app shell, shell presentation, chrome, view mode).
 *
 * <p>Kept distinct from {@link WidgetSurfaceHostJoin} so {@link TerminalWidgetCompositionAssembly} does not
 * take a full widget result bag when it only joins the surface slice. Activity wiring reads this bundle for
 * shell/chrome/view-mode fields.</p>
 *
 * <p>App-shell <strong>selection</strong> (which product terminal slot is routed for shell view) is
 * {@link #appShellTerminalSelectionPolicy}. <strong>Activation</strong> (active shell view + drawer chrome)
 * is {@link #appShellTerminalViewPolicy}. Chrome is wired through the activation policy without exposing raw
 * {@link AppShellNavigation} on the harness bundle.</p>
 */
public final class WidgetHarnessHostControllers {
    public final AppShellTerminalSelectionPolicy appShellTerminalSelectionPolicy;
    public final AppShellTerminalViewPolicy appShellTerminalViewPolicy;
    public final ShellStateBridge productShellStateHostBridge;
    public final ShellStatePresenter shellStatePresenter;
    public final ChromeController terminalChromeController;
    public final ViewModeController terminalViewModeController;

    public WidgetHarnessHostControllers(
            AppShellTerminalSelectionPolicy appShellTerminalSelectionPolicy,
            AppShellTerminalViewPolicy appShellTerminalViewPolicy,
            ShellStateBridge productShellStateHostBridge,
            ShellStatePresenter shellStatePresenter,
            ChromeController terminalChromeController,
            ViewModeController terminalViewModeController) {
        this.appShellTerminalSelectionPolicy = appShellTerminalSelectionPolicy;
        this.appShellTerminalViewPolicy = appShellTerminalViewPolicy;
        this.productShellStateHostBridge = productShellStateHostBridge;
        this.shellStatePresenter = shellStatePresenter;
        this.terminalChromeController = terminalChromeController;
        this.terminalViewModeController = terminalViewModeController;
    }
}
