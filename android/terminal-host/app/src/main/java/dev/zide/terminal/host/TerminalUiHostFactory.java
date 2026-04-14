package dev.zide.terminal.host;

import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;

import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.host.userland.ProductShellStateBridge;
import dev.zide.terminal.selection.TerminalSelectionController;

/** UI host assembly helpers. */
public final class TerminalUiHostFactory {
    private TerminalUiHostFactory() {
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

    public static TerminalViewModeController createViewModeController(
            View productView,
            View debugView,
            View terminalScrollOverlay,
            FrameLayout productSurfaceContainer,
            TerminalViewModeController.Host host) {
        return new TerminalViewModeController(
                productView,
                debugView,
                terminalScrollOverlay,
                productSurfaceContainer,
                host);
    }

    public static TerminalSurfaceWidgetController createSurfaceWidgetController(
            TerminalSurfaceHostController surfaceHostController,
            TerminalSelectionController selectionController,
            TerminalGestureStateController terminalGestureStateController,
            TerminalSurfaceWidgetController.Host host) {
        return new TerminalSurfaceWidgetController(
                surfaceHostController,
                selectionController,
                terminalGestureStateController,
                host);
    }
}
