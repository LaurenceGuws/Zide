package uk.laurencegouws.terminal.host.ui;

import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;

import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetController;
import uk.laurencegouws.terminal.host.userland.ShellStateBridge;
import uk.laurencegouws.terminal.selection.SelectionController;

/** UI host assembly helpers. */
public final class UiFactory {
    private UiFactory() {
    }

    public static ShellStateBridge createShellStateHostBridge(
            View productReadinessBlocker,
            View terminalScrollOverlay,
            TextView productReadinessTitle,
            TextView productReadinessDetail,
            android.widget.Button productReadinessRetryButton,
            ShellStateBridge.Callbacks callbacks) {
        return new ShellStateBridge(
                productReadinessBlocker,
                terminalScrollOverlay,
                productReadinessTitle,
                productReadinessDetail,
                productReadinessRetryButton,
                callbacks);
    }

    public static ViewModeController createViewModeController(
            View productView,
            FrameLayout productSurfaceContainer,
            AppShellNavigation appShellNavigation,
            TerminalWidgetSlotId terminalWidgetSlot,
            ViewModeController.Host host) {
        return new ViewModeController(
                productView,
                productSurfaceContainer,
                appShellNavigation,
                terminalWidgetSlot,
                host);
    }

    public static SurfaceWidgetController createSurfaceWidgetController(
            SurfaceController surfaceHostController,
            SelectionController selectionController,
            GestureStateController GestureStateController,
            SurfaceWidgetController.Host host) {
        return new SurfaceWidgetController(
                surfaceHostController,
                selectionController,
                GestureStateController,
                host);
    }
}
