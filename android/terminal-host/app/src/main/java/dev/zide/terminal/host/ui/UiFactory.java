package dev.zide.terminal.host.ui;

import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;

import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.host.surface.SurfaceController;
import dev.zide.terminal.host.surface.SurfaceWidgetController;
import dev.zide.terminal.host.userland.ProductShellStateBridge;
import dev.zide.terminal.selection.TerminalSelectionController;

/** UI host assembly helpers. */
public final class UiFactory {
    private UiFactory() {
    }

    public static ProductShellStateBridge createProductShellStateHostBridge(
            View productBootstrapBlocker,
            View terminalScrollOverlay,
            TextView productBootstrapTitle,
            TextView productBootstrapDetail,
            android.widget.Button productBootstrapRetryButton,
            ProductShellStateBridge.Callbacks callbacks) {
        return new ProductShellStateBridge(
                productBootstrapBlocker,
                terminalScrollOverlay,
                productBootstrapTitle,
                productBootstrapDetail,
                productBootstrapRetryButton,
                callbacks);
    }

    public static ViewModeController createViewModeController(
            View productView,
            View debugView,
            View terminalScrollOverlay,
            FrameLayout productSurfaceContainer,
            ViewModeController.Host host) {
        return new ViewModeController(
                productView,
                debugView,
                terminalScrollOverlay,
                productSurfaceContainer,
                host);
    }

    public static SurfaceWidgetController createSurfaceWidgetController(
            SurfaceController surfaceHostController,
            TerminalSelectionController selectionController,
            TerminalGestureStateController terminalGestureStateController,
            SurfaceWidgetController.Host host) {
        return new SurfaceWidgetController(
                surfaceHostController,
                selectionController,
                terminalGestureStateController,
                host);
    }
}
