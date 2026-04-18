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
 * <p>App-shell terminal-view policy (activation + chrome drawer sidebar reads/writes) is
 * {@link #appShellTerminalViewPolicy}; chrome is wired through that policy without exposing raw
 * {@link AppShellNavigation} on the harness bundle.</p>
 */
public final class WidgetHarnessHostControllers {
    public final AppShellTerminalViewPolicy appShellTerminalViewPolicy;
    public final ShellStateBridge productShellStateHostBridge;
    public final ShellStatePresenter shellStatePresenter;
    public final ChromeController terminalChromeController;
    public final ViewModeController terminalViewModeController;

    public WidgetHarnessHostControllers(
            AppShellTerminalViewPolicy appShellTerminalViewPolicy,
            ShellStateBridge productShellStateHostBridge,
            ShellStatePresenter shellStatePresenter,
            ChromeController terminalChromeController,
            ViewModeController terminalViewModeController) {
        this.appShellTerminalViewPolicy = appShellTerminalViewPolicy;
        this.productShellStateHostBridge = productShellStateHostBridge;
        this.shellStatePresenter = shellStatePresenter;
        this.terminalChromeController = terminalChromeController;
        this.terminalViewModeController = terminalViewModeController;
    }
}
