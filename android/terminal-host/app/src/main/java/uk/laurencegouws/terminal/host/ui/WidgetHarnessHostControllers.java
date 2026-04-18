package uk.laurencegouws.terminal.host.ui;

import uk.laurencegouws.terminal.host.userland.ShellStateBridge;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;

/**
 * Non-surface harness controllers from {@link WidgetAssembly} (app shell, shell presentation, chrome, view mode).
 *
 * <p>Kept distinct from {@link WidgetSurfaceHostJoin} so {@link TerminalWidgetCompositionAssembly} does not
 * take a full widget result bag when it only joins the surface slice. Activity wiring reads this bundle for
 * shell/chrome/view-mode fields.</p>
 */
public final class WidgetHarnessHostControllers {
    public final AppShellNavigation appShellNavigation;
    public final ShellStateBridge productShellStateHostBridge;
    public final ShellStatePresenter shellStatePresenter;
    public final ChromeController terminalChromeController;
    public final ViewModeController terminalViewModeController;

    public WidgetHarnessHostControllers(
            AppShellNavigation appShellNavigation,
            ShellStateBridge productShellStateHostBridge,
            ShellStatePresenter shellStatePresenter,
            ChromeController terminalChromeController,
            ViewModeController terminalViewModeController) {
        this.appShellNavigation = appShellNavigation;
        this.productShellStateHostBridge = productShellStateHostBridge;
        this.shellStatePresenter = shellStatePresenter;
        this.terminalChromeController = terminalChromeController;
        this.terminalViewModeController = terminalViewModeController;
    }
}
