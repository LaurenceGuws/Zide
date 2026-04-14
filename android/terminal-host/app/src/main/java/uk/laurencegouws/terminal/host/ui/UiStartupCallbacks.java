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
    public static final class UiHostCallbacks {
        final Supplier<ViewportController> viewportController;
        final Supplier<ChromeController> chromeController;
        final Supplier<Button> productBootstrapRetryButton;
        final Supplier<Button> productBootstrapDebugButton;
        final Supplier<UserlandInstallState> currentInstallState;
        final Supplier<UserlandReadinessState> currentReadinessState;
        final Supplier<UserlandWorkflowController> userlandWorkflowController;
        final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;
        final UiStartupAssembly.ShowDebugView showDebugView;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;

        private UiHostCallbacks(
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
                Consumer<String> updateStatus) {
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
        }

        public static UiHostCallbacks of(
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
                Consumer<String> updateStatus) {
            return new UiHostCallbacks(
                    viewportController,
                    chromeController,
                    productBootstrapRetryButton,
                    productBootstrapDebugButton,
                    currentInstallState,
                    currentReadinessState,
                    userlandWorkflowController,
                    userlandSessionCoordinator,
                    showDebugView,
                    appendEvent,
                    updateStatus);
        }
    }

    public static final class UiRuntimeCallbacks {
        final Supplier<RuntimeAssetsController> runtimeAssetsController;
        final Supplier<ViewModeController> viewModeController;
        final Supplier<SurfaceController> surfaceHostController;
        final Supplier<SurfaceWidgetController> surfaceWidgetController;
        final Supplier<ProductShellStatePresenter> productShellStatePresenter;
        final Supplier<FrameLoopController> frameLoopController;
        final Supplier<View> leftSidebar;

        private UiRuntimeCallbacks(
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

        public static UiRuntimeCallbacks of(
                Supplier<RuntimeAssetsController> runtimeAssetsController,
                Supplier<ViewModeController> viewModeController,
                Supplier<SurfaceController> surfaceHostController,
                Supplier<SurfaceWidgetController> surfaceWidgetController,
                Supplier<ProductShellStatePresenter> productShellStatePresenter,
                Supplier<FrameLoopController> frameLoopController,
                Supplier<View> leftSidebar) {
            return new UiRuntimeCallbacks(
                    runtimeAssetsController,
                    viewModeController,
                    surfaceHostController,
                    surfaceWidgetController,
                    productShellStatePresenter,
                    frameLoopController,
                    leftSidebar);
        }
    }

    private final UiHostCallbacks uiHostCallbacks;
    private final UiRuntimeCallbacks uiRuntimeCallbacks;

    public UiStartupCallbacks(
            UiHostCallbacks uiHostCallbacks,
            UiRuntimeCallbacks uiRuntimeCallbacks) {
        this.uiHostCallbacks = uiHostCallbacks;
        this.uiRuntimeCallbacks = uiRuntimeCallbacks;
    }

    @Override
    public ViewportController viewportController() {
        return uiHostCallbacks.viewportController.get();
    }

    @Override
    public ChromeController chromeController() {
        return uiHostCallbacks.chromeController.get();
    }

    @Override
    public Button productBootstrapRetryButton() {
        return uiHostCallbacks.productBootstrapRetryButton.get();
    }

    @Override
    public Button productBootstrapDebugButton() {
        return uiHostCallbacks.productBootstrapDebugButton.get();
    }

    @Override
    public Supplier<UserlandInstallState> currentInstallState() {
        return uiHostCallbacks.currentInstallState;
    }

    @Override
    public Supplier<UserlandReadinessState> currentReadinessState() {
        return uiHostCallbacks.currentReadinessState;
    }

    @Override
    public Supplier<UserlandWorkflowController> userlandWorkflowController() {
        return uiHostCallbacks.userlandWorkflowController;
    }

    @Override
    public Supplier<UserlandSessionCoordinator> userlandSessionCoordinator() {
        return uiHostCallbacks.userlandSessionCoordinator;
    }

    @Override
    public UiStartupAssembly.ShowDebugView showDebugView() {
        return uiHostCallbacks.showDebugView;
    }

    @Override
    public Consumer<String> appendEvent() {
        return uiHostCallbacks.appendEvent;
    }

    @Override
    public Consumer<String> updateStatus() {
        return uiHostCallbacks.updateStatus;
    }

    @Override
    public RuntimeAssetsController runtimeAssetsController() {
        return uiRuntimeCallbacks.runtimeAssetsController.get();
    }

    @Override
    public ViewModeController viewModeController() {
        return uiRuntimeCallbacks.viewModeController.get();
    }

    @Override
    public SurfaceController surfaceHostController() {
        return uiRuntimeCallbacks.surfaceHostController.get();
    }

    @Override
    public SurfaceWidgetController surfaceWidgetController() {
        return uiRuntimeCallbacks.surfaceWidgetController.get();
    }

    @Override
    public ProductShellStatePresenter productShellStatePresenter() {
        return uiRuntimeCallbacks.productShellStatePresenter.get();
    }

    @Override
    public FrameLoopController frameLoopController() {
        return uiRuntimeCallbacks.frameLoopController.get();
    }

    @Override
    public View leftSidebar() {
        return uiRuntimeCallbacks.leftSidebar.get();
    }
}
