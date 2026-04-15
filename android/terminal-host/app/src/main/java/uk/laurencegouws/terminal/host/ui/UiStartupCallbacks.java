package uk.laurencegouws.terminal.host.ui;

import android.view.View;
import android.widget.Button;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetController;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsController;
import uk.laurencegouws.terminal.userland.ProductShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;
import uk.laurencegouws.terminal.userland.UserlandWorkflowController;

/** Functional callback adapter for {@link UiStartupAssembly.Host}. */
public final class UiStartupCallbacks implements UiStartupAssembly.Host {
    private final ViewportController viewportController;
    private final ChromeController chromeController;
    private final Button productReadinessRetryButton;
    private final Button productReadinessDebugButton;
    private final Supplier<UserlandInstallState> currentInstallState;
    private final Supplier<UserlandReadinessState> currentReadinessState;
    private final Supplier<UserlandWorkflowController> userlandWorkflowController;
    private final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;
    private final UiStartupAssembly.ShowDebugView showDebugView;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final RuntimeAssetsController runtimeAssetsController;
    private final ViewModeController viewModeController;
    private final SurfaceController surfaceHostController;
    private final SurfaceWidgetController surfaceWidgetController;
    private final ProductShellStatePresenter productShellStatePresenter;
    private final FrameLoopController frameLoopController;
    private final View leftSidebar;

    public UiStartupCallbacks(
            ViewportController viewportController,
            ChromeController chromeController,
            Button productReadinessRetryButton,
            Button productReadinessDebugButton,
            Supplier<UserlandInstallState> currentInstallState,
            Supplier<UserlandReadinessState> currentReadinessState,
            Supplier<UserlandWorkflowController> userlandWorkflowController,
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
            UiStartupAssembly.ShowDebugView showDebugView,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            RuntimeAssetsController runtimeAssetsController,
            ViewModeController viewModeController,
            SurfaceController surfaceHostController,
            SurfaceWidgetController surfaceWidgetController,
            ProductShellStatePresenter productShellStatePresenter,
            FrameLoopController frameLoopController,
            View leftSidebar) {
        this.viewportController = viewportController;
        this.chromeController = chromeController;
        this.productReadinessRetryButton = productReadinessRetryButton;
        this.productReadinessDebugButton = productReadinessDebugButton;
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
        return viewportController;
    }

    @Override
    public ChromeController chromeController() {
        return chromeController;
    }

    @Override
    public Button productReadinessRetryButton() {
        return productReadinessRetryButton;
    }

    @Override
    public Button productReadinessDebugButton() {
        return productReadinessDebugButton;
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
        return runtimeAssetsController;
    }

    @Override
    public ViewModeController viewModeController() {
        return viewModeController;
    }

    @Override
    public SurfaceController surfaceHostController() {
        return surfaceHostController;
    }

    @Override
    public SurfaceWidgetController surfaceWidgetController() {
        return surfaceWidgetController;
    }

    @Override
    public ProductShellStatePresenter productShellStatePresenter() {
        return productShellStatePresenter;
    }

    @Override
    public FrameLoopController frameLoopController() {
        return frameLoopController;
    }

    @Override
    public View leftSidebar() {
        return leftSidebar;
    }
}
