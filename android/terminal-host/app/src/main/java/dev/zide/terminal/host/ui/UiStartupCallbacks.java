package dev.zide.terminal.host.ui;

import android.view.View;
import android.widget.Button;

import java.util.function.Consumer;
import java.util.function.Supplier;

import dev.zide.terminal.host.runtime.FrameLoopController;
import dev.zide.terminal.host.surface.SurfaceController;
import dev.zide.terminal.host.surface.SurfaceWidgetController;
import dev.zide.terminal.host.runtime.RuntimeAssetsController;
import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;
import dev.zide.terminal.userland.UserlandWorkflowController;

/** Functional callback adapter for {@link UiStartupAssembly.Host}. */
public final class UiStartupCallbacks implements UiStartupAssembly.Host {
    private final Supplier<ViewportController> viewportController;
    private final Supplier<ChromeController> chromeController;
    private final Supplier<Button> productBootstrapRetryButton;
    private final Supplier<Button> productBootstrapDebugButton;
    private final Supplier<UserlandInstallState> currentInstallState;
    private final Supplier<UserlandReadinessState> currentReadinessState;
    private final Supplier<UserlandWorkflowController> userlandWorkflowController;
    private final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;
    private final UiStartupAssembly.ShowDebugView showDebugView;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Supplier<RuntimeAssetsController> runtimeAssetsController;
    private final Supplier<ViewModeController> viewModeController;
    private final Supplier<SurfaceController> surfaceHostController;
    private final Supplier<SurfaceWidgetController> surfaceWidgetController;
    private final Supplier<ProductShellStatePresenter> productShellStatePresenter;
    private final Supplier<FrameLoopController> frameLoopController;
    private final Supplier<View> leftSidebar;

    public UiStartupCallbacks(
            Supplier<ViewportController> viewportController,
            Supplier<ChromeController> chromeController,
            Supplier<Button> productBootstrapRetryButton,
            Supplier<Button> productBootstrapDebugButton,
            Supplier<UserlandInstallState> currentInstallState,
            Supplier<UserlandReadinessState> currentReadinessState,
            Supplier<UserlandWorkflowController> userlandWorkflowController,
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
            UiStartupAssembly.ShowDebugView showDebugView,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Supplier<RuntimeAssetsController> runtimeAssetsController,
            Supplier<ViewModeController> viewModeController,
            Supplier<SurfaceController> surfaceHostController,
            Supplier<SurfaceWidgetController> surfaceWidgetController,
            Supplier<ProductShellStatePresenter> productShellStatePresenter,
            Supplier<FrameLoopController> frameLoopController,
            Supplier<View> leftSidebar) {
        this.viewportController = viewportController;
        this.chromeController = chromeController;
        this.productBootstrapRetryButton = productBootstrapRetryButton;
        this.productBootstrapDebugButton = productBootstrapDebugButton;
        this.currentInstallState = currentInstallState;
        this.currentReadinessState = currentReadinessState;
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
    public ViewportController viewportController() {
        return viewportController.get();
    }

    @Override
    public ChromeController chromeController() {
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
    public Supplier<UserlandReadinessState> currentReadinessState() {
        return currentReadinessState;
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
    public UiStartupAssembly.ShowDebugView showDebugView() {
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
    public RuntimeAssetsController runtimeAssetsController() {
        return runtimeAssetsController.get();
    }

    @Override
    public ViewModeController viewModeController() {
        return viewModeController.get();
    }

    @Override
    public SurfaceController surfaceHostController() {
        return surfaceHostController.get();
    }

    @Override
    public SurfaceWidgetController surfaceWidgetController() {
        return surfaceWidgetController.get();
    }

    @Override
    public ProductShellStatePresenter productShellStatePresenter() {
        return productShellStatePresenter.get();
    }

    @Override
    public FrameLoopController frameLoopController() {
        return frameLoopController.get();
    }

    @Override
    public View leftSidebar() {
        return leftSidebar.get();
    }
}
