package dev.zide.terminal.host;

import android.view.View;
import android.widget.Button;

import java.util.function.Consumer;
import java.util.function.Supplier;

import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;
import dev.zide.terminal.userland.UserlandWorkflowController;

/** Functional callback adapter for {@link TerminalUiStartupAssembly.Host}. */
public final class TerminalUiStartupHostCallbacks implements TerminalUiStartupAssembly.Host {
    private final Supplier<TerminalViewportController> viewportController;
    private final Supplier<TerminalChromeController> chromeController;
    private final Supplier<Button> productBootstrapRetryButton;
    private final Supplier<Button> productBootstrapDebugButton;
    private final Supplier<UserlandInstallState> currentInstallState;
    private final Supplier<UserlandBootstrapState> currentBootstrapState;
    private final Supplier<UserlandWorkflowController> userlandWorkflowController;
    private final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;
    private final TerminalUiStartupAssembly.ShowDebugView showDebugView;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Supplier<TerminalRuntimeAssetsController> runtimeAssetsController;
    private final Supplier<TerminalViewModeController> viewModeController;
    private final Supplier<TerminalSurfaceHostController> surfaceHostController;
    private final Supplier<TerminalSurfaceWidgetController> surfaceWidgetController;
    private final Supplier<ProductShellStatePresenter> productShellStatePresenter;
    private final Supplier<TerminalFrameLoopController> frameLoopController;
    private final Supplier<View> leftSidebar;

    public TerminalUiStartupHostCallbacks(
            Supplier<TerminalViewportController> viewportController,
            Supplier<TerminalChromeController> chromeController,
            Supplier<Button> productBootstrapRetryButton,
            Supplier<Button> productBootstrapDebugButton,
            Supplier<UserlandInstallState> currentInstallState,
            Supplier<UserlandBootstrapState> currentBootstrapState,
            Supplier<UserlandWorkflowController> userlandWorkflowController,
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
            TerminalUiStartupAssembly.ShowDebugView showDebugView,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Supplier<TerminalRuntimeAssetsController> runtimeAssetsController,
            Supplier<TerminalViewModeController> viewModeController,
            Supplier<TerminalSurfaceHostController> surfaceHostController,
            Supplier<TerminalSurfaceWidgetController> surfaceWidgetController,
            Supplier<ProductShellStatePresenter> productShellStatePresenter,
            Supplier<TerminalFrameLoopController> frameLoopController,
            Supplier<View> leftSidebar) {
        this.viewportController = viewportController;
        this.chromeController = chromeController;
        this.productBootstrapRetryButton = productBootstrapRetryButton;
        this.productBootstrapDebugButton = productBootstrapDebugButton;
        this.currentInstallState = currentInstallState;
        this.currentBootstrapState = currentBootstrapState;
        this.userlandWorkflowController = userlandWorkflowController;
        this.userlandSessionCoordinator = userlandSessionCoordinator;
        this.showDebugView = showDebugView;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.runtimeAssetsController = runtimeAssetsController;
        this.viewModeController = viewModeController;
        this.surfaceHostController = surfaceHostController;
        this.surfaceWidgetController = surfaceWidgetController;
        this.productShellStatePresenter = productShellStatePresenter;
        this.frameLoopController = frameLoopController;
        this.leftSidebar = leftSidebar;
    }

    @Override
    public TerminalViewportController viewportController() {
        return viewportController.get();
    }

    @Override
    public TerminalChromeController chromeController() {
        return chromeController.get();
    }

    @Override
    public Button productBootstrapRetryButton() {
        return productBootstrapRetryButton.get();
    }

    @Override
    public Button productBootstrapDebugButton() {
        return productBootstrapDebugButton.get();
    }

    @Override
    public Supplier<UserlandInstallState> currentInstallState() {
        return currentInstallState;
    }

    @Override
    public Supplier<UserlandBootstrapState> currentBootstrapState() {
        return currentBootstrapState;
    }

    @Override
    public Supplier<UserlandWorkflowController> userlandWorkflowController() {
        return userlandWorkflowController;
    }

    @Override
    public Supplier<UserlandSessionCoordinator> userlandSessionCoordinator() {
        return userlandSessionCoordinator;
    }

    @Override
    public TerminalUiStartupAssembly.ShowDebugView showDebugView() {
        return showDebugView;
    }

    @Override
    public Consumer<String> appendEvent() {
        return appendEvent;
    }

    @Override
    public Consumer<String> updateStatus() {
        return updateStatus;
    }

    @Override
    public TerminalRuntimeAssetsController runtimeAssetsController() {
        return runtimeAssetsController.get();
    }

    @Override
    public TerminalViewModeController viewModeController() {
        return viewModeController.get();
    }

    @Override
    public TerminalSurfaceHostController surfaceHostController() {
        return surfaceHostController.get();
    }

    @Override
    public TerminalSurfaceWidgetController surfaceWidgetController() {
        return surfaceWidgetController.get();
    }

    @Override
    public ProductShellStatePresenter productShellStatePresenter() {
        return productShellStatePresenter.get();
    }

    @Override
    public TerminalFrameLoopController frameLoopController() {
        return frameLoopController.get();
    }

    @Override
    public View leftSidebar() {
        return leftSidebar.get();
    }
}
