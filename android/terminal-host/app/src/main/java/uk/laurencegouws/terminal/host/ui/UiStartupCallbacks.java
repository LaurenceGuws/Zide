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
    public static final class UiRuntimeBundle {
        final Supplier<RuntimeAssetsController> runtimeAssetsController;
        final Supplier<ViewModeController> viewModeController;
        final Supplier<SurfaceController> surfaceHostController;
        final Supplier<SurfaceWidgetController> surfaceWidgetController;
        final Supplier<ProductShellStatePresenter> productShellStatePresenter;
        final Supplier<FrameLoopController> frameLoopController;
        final Supplier<View> leftSidebar;

        private UiRuntimeBundle(
                Supplier<RuntimeAssetsController> runtimeAssetsController,
                Supplier<ViewModeController> viewModeController,
                Supplier<SurfaceController> surfaceHostController,
                Supplier<SurfaceWidgetController> surfaceWidgetController,
                Supplier<ProductShellStatePresenter> productShellStatePresenter,
                Supplier<FrameLoopController> frameLoopController,
                Supplier<View> leftSidebar) {
            this.runtimeAssetsController = runtimeAssetsController;
            this.viewModeController = viewModeController;
            this.surfaceHostController = surfaceHostController;
            this.surfaceWidgetController = surfaceWidgetController;
            this.productShellStatePresenter = productShellStatePresenter;
            this.frameLoopController = frameLoopController;
            this.leftSidebar = leftSidebar;
        }

        public static UiRuntimeBundle of(
                Supplier<RuntimeAssetsController> runtimeAssetsController,
                Supplier<ViewModeController> viewModeController,
                Supplier<SurfaceController> surfaceHostController,
                Supplier<SurfaceWidgetController> surfaceWidgetController,
                Supplier<ProductShellStatePresenter> productShellStatePresenter,
                Supplier<FrameLoopController> frameLoopController,
                Supplier<View> leftSidebar) {
            return new UiRuntimeBundle(
                    runtimeAssetsController,
                    viewModeController,
                    surfaceHostController,
                    surfaceWidgetController,
                    productShellStatePresenter,
                    frameLoopController,
                    leftSidebar);
        }
    }

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
    private final UiRuntimeBundle uiRuntimeBundle;

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
            UiRuntimeBundle uiRuntimeBundle) {
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
        this.uiRuntimeBundle = uiRuntimeBundle;
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
        return uiRuntimeBundle.runtimeAssetsController.get();
    }

    @Override
    public ViewModeController viewModeController() {
        return uiRuntimeBundle.viewModeController.get();
    }

    @Override
    public SurfaceController surfaceHostController() {
        return uiRuntimeBundle.surfaceHostController.get();
    }

    @Override
    public SurfaceWidgetController surfaceWidgetController() {
        return uiRuntimeBundle.surfaceWidgetController.get();
    }

    @Override
    public ProductShellStatePresenter productShellStatePresenter() {
        return uiRuntimeBundle.productShellStatePresenter.get();
    }

    @Override
    public FrameLoopController frameLoopController() {
        return uiRuntimeBundle.frameLoopController.get();
    }

    @Override
    public View leftSidebar() {
        return uiRuntimeBundle.leftSidebar.get();
    }
}
