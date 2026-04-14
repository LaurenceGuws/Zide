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
    public static final class UiHostBundle {
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

        private UiHostBundle(
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

        public static UiHostBundle of(
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
            return new UiHostBundle(
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

    private final UiHostBundle uiHostBundle;
    private final UiRuntimeBundle uiRuntimeBundle;

    public UiStartupCallbacks(
            UiHostBundle uiHostBundle,
            UiRuntimeBundle uiRuntimeBundle) {
        this.uiHostBundle = uiHostBundle;
        this.uiRuntimeBundle = uiRuntimeBundle;
    }

    @Override
    public ViewportController viewportController() {
        return uiHostBundle.viewportController.get();
    }

    @Override
    public ChromeController chromeController() {
        return uiHostBundle.chromeController.get();
    }

    @Override
    public Button productBootstrapRetryButton() {
        return uiHostBundle.productBootstrapRetryButton.get();
    }

    @Override
    public Button productBootstrapDebugButton() {
        return uiHostBundle.productBootstrapDebugButton.get();
    }

    @Override
    public Supplier<UserlandInstallState> currentInstallState() {
        return uiHostBundle.currentInstallState;
    }

    @Override
    public Supplier<UserlandReadinessState> currentReadinessState() {
        return uiHostBundle.currentReadinessState;
    }

    @Override
    public Supplier<UserlandWorkflowController> userlandWorkflowController() {
        return uiHostBundle.userlandWorkflowController;
    }

    @Override
    public Supplier<UserlandSessionCoordinator> userlandSessionCoordinator() {
        return uiHostBundle.userlandSessionCoordinator;
    }

    @Override
    public UiStartupAssembly.ShowDebugView showDebugView() {
        return uiHostBundle.showDebugView;
    }

    @Override
    public Consumer<String> appendEvent() {
        return uiHostBundle.appendEvent;
    }

    @Override
    public Consumer<String> updateStatus() {
        return uiHostBundle.updateStatus;
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
