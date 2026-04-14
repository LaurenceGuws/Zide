package uk.laurencegouws.terminal.host.runtime;

import android.view.SurfaceView;
import android.view.View;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.TerminalStatusController;
import uk.laurencegouws.terminal.gesture.TerminalGestureStateController;
import uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView;
import uk.laurencegouws.terminal.selection.TerminalSelectionController;
import uk.laurencegouws.terminal.userland.ProductShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/** Functional callback adapter for {@link ProductRuntimeAssembly.Host}. */
public final class ProductRuntimeAssemblyCallbacks implements ProductRuntimeAssembly.Host {
    public static final class RuntimeHostCallbacks {
        final BooleanSupplier debugViewEnabled;
        final BooleanSupplier nativeLoaded;
        final Supplier<UserlandInstallState> installState;
        final Consumer<UserlandInstallState> setInstallState;
        final Supplier<UserlandReadinessState> readinessState;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;

        private RuntimeHostCallbacks(
                BooleanSupplier debugViewEnabled,
                BooleanSupplier nativeLoaded,
                Supplier<UserlandInstallState> installState,
                Consumer<UserlandInstallState> setInstallState,
                Supplier<UserlandReadinessState> readinessState,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus) {
            this.debugViewEnabled = debugViewEnabled;
            this.nativeLoaded = nativeLoaded;
            this.installState = installState;
            this.setInstallState = setInstallState;
            this.readinessState = readinessState;
            this.appendEvent = appendEvent;
            this.updateStatus = updateStatus;
        }

        public static RuntimeHostCallbacks of(
                BooleanSupplier debugViewEnabled,
                BooleanSupplier nativeLoaded,
                Supplier<UserlandInstallState> installState,
                Consumer<UserlandInstallState> setInstallState,
                Supplier<UserlandReadinessState> readinessState,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus) {
            return new RuntimeHostCallbacks(
                    debugViewEnabled,
                    nativeLoaded,
                    installState,
                    setInstallState,
                    readinessState,
                    appendEvent,
                    updateStatus);
        }
    }

    public static final class RuntimeUiCallbacks {
        final Supplier<SurfaceView> surfaceView;
        final Supplier<View> productBootstrapBlocker;
        final Supplier<TerminalScrollOverlayView> terminalScrollOverlay;
        final Supplier<TerminalSelectionController> selectionController;
        final Supplier<ProductShellStatePresenter> productShellStatePresenter;
        final Supplier<FrameLoopController> frameLoopController;
        final Supplier<TerminalStatusController> terminalStatusController;
        final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;
        final Supplier<TerminalGestureStateController> terminalGestureStateController;

        private RuntimeUiCallbacks(
                Supplier<SurfaceView> surfaceView,
                Supplier<View> productBootstrapBlocker,
                Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
                Supplier<TerminalSelectionController> selectionController,
                Supplier<ProductShellStatePresenter> productShellStatePresenter,
                Supplier<FrameLoopController> frameLoopController,
                Supplier<TerminalStatusController> terminalStatusController,
                Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
                Supplier<TerminalGestureStateController> terminalGestureStateController) {
            this.surfaceView = surfaceView;
            this.productBootstrapBlocker = productBootstrapBlocker;
            this.terminalScrollOverlay = terminalScrollOverlay;
            this.selectionController = selectionController;
            this.productShellStatePresenter = productShellStatePresenter;
            this.frameLoopController = frameLoopController;
            this.terminalStatusController = terminalStatusController;
            this.userlandSessionCoordinator = userlandSessionCoordinator;
            this.terminalGestureStateController = terminalGestureStateController;
        }

        public static RuntimeUiCallbacks of(
                Supplier<SurfaceView> surfaceView,
                Supplier<View> productBootstrapBlocker,
                Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
                Supplier<TerminalSelectionController> selectionController,
                Supplier<ProductShellStatePresenter> productShellStatePresenter,
                Supplier<FrameLoopController> frameLoopController,
                Supplier<TerminalStatusController> terminalStatusController,
                Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
                Supplier<TerminalGestureStateController> terminalGestureStateController) {
            return new RuntimeUiCallbacks(
                    surfaceView,
                    productBootstrapBlocker,
                    terminalScrollOverlay,
                    selectionController,
                    productShellStatePresenter,
                    frameLoopController,
                    terminalStatusController,
                    userlandSessionCoordinator,
                    terminalGestureStateController);
        }
    }

    private final RuntimeHostCallbacks runtimeHostCallbacks;
    private final RuntimeUiCallbacks runtimeUiCallbacks;

    public ProductRuntimeAssemblyCallbacks(
            RuntimeHostCallbacks runtimeHostCallbacks,
            RuntimeUiCallbacks runtimeUiCallbacks) {
        this.runtimeHostCallbacks = runtimeHostCallbacks;
        this.runtimeUiCallbacks = runtimeUiCallbacks;
    }

    @Override
    public boolean debugViewEnabled() {
        return runtimeHostCallbacks.debugViewEnabled.getAsBoolean();
    }

    @Override
    public boolean nativeLoaded() {
        return runtimeHostCallbacks.nativeLoaded.getAsBoolean();
    }

    @Override
    public UserlandInstallState installState() {
        return runtimeHostCallbacks.installState.get();
    }

    @Override
    public void setInstallState(UserlandInstallState installState) {
        runtimeHostCallbacks.setInstallState.accept(installState);
    }

    @Override
    public UserlandReadinessState readinessState() {
        return runtimeHostCallbacks.readinessState.get();
    }

    @Override
    public SurfaceView surfaceView() {
        return runtimeUiCallbacks.surfaceView.get();
    }

    @Override
    public View productBootstrapBlocker() {
        return runtimeUiCallbacks.productBootstrapBlocker.get();
    }

    @Override
    public TerminalScrollOverlayView terminalScrollOverlay() {
        return runtimeUiCallbacks.terminalScrollOverlay.get();
    }

    @Override
    public TerminalSelectionController selectionController() {
        return runtimeUiCallbacks.selectionController.get();
    }

    @Override
    public ProductShellStatePresenter productShellStatePresenter() {
        return runtimeUiCallbacks.productShellStatePresenter.get();
    }

    @Override
    public FrameLoopController frameLoopController() {
        return runtimeUiCallbacks.frameLoopController.get();
    }

    @Override
    public TerminalStatusController terminalStatusController() {
        return runtimeUiCallbacks.terminalStatusController.get();
    }

    @Override
    public UserlandSessionCoordinator userlandSessionCoordinator() {
        return runtimeUiCallbacks.userlandSessionCoordinator.get();
    }

    @Override
    public TerminalGestureStateController terminalGestureStateController() {
        return runtimeUiCallbacks.terminalGestureStateController.get();
    }

    @Override
    public void appendEvent(String message) {
        runtimeHostCallbacks.appendEvent.accept(message);
    }

    @Override
    public void updateStatus(String statusLabel) {
        runtimeHostCallbacks.updateStatus.accept(statusLabel);
    }
}
