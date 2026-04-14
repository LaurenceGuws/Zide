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
    public static final class RuntimeHostBundle {
        final BooleanSupplier debugViewEnabled;
        final BooleanSupplier nativeLoaded;
        final Supplier<UserlandInstallState> installState;
        final Consumer<UserlandInstallState> setInstallState;
        final Supplier<UserlandReadinessState> readinessState;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;

        private RuntimeHostBundle(
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

        public static RuntimeHostBundle of(
                BooleanSupplier debugViewEnabled,
                BooleanSupplier nativeLoaded,
                Supplier<UserlandInstallState> installState,
                Consumer<UserlandInstallState> setInstallState,
                Supplier<UserlandReadinessState> readinessState,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus) {
            return new RuntimeHostBundle(
                    debugViewEnabled,
                    nativeLoaded,
                    installState,
                    setInstallState,
                    readinessState,
                    appendEvent,
                    updateStatus);
        }
    }

    public static final class RuntimeUiBundle {
        final Supplier<SurfaceView> surfaceView;
        final Supplier<View> productBootstrapBlocker;
        final Supplier<TerminalScrollOverlayView> terminalScrollOverlay;
        final Supplier<TerminalSelectionController> selectionController;
        final Supplier<ProductShellStatePresenter> productShellStatePresenter;
        final Supplier<FrameLoopController> frameLoopController;
        final Supplier<TerminalStatusController> terminalStatusController;
        final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;
        final Supplier<TerminalGestureStateController> terminalGestureStateController;

        private RuntimeUiBundle(
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

        public static RuntimeUiBundle of(
                Supplier<SurfaceView> surfaceView,
                Supplier<View> productBootstrapBlocker,
                Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
                Supplier<TerminalSelectionController> selectionController,
                Supplier<ProductShellStatePresenter> productShellStatePresenter,
                Supplier<FrameLoopController> frameLoopController,
                Supplier<TerminalStatusController> terminalStatusController,
                Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
                Supplier<TerminalGestureStateController> terminalGestureStateController) {
            return new RuntimeUiBundle(
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

    private final RuntimeHostBundle runtimeHostBundle;
    private final RuntimeUiBundle runtimeUiBundle;

    public ProductRuntimeAssemblyCallbacks(
            RuntimeHostBundle runtimeHostBundle,
            RuntimeUiBundle runtimeUiBundle) {
        this.runtimeHostBundle = runtimeHostBundle;
        this.runtimeUiBundle = runtimeUiBundle;
    }

    @Override
    public boolean debugViewEnabled() {
        return runtimeHostBundle.debugViewEnabled.getAsBoolean();
    }

    @Override
    public boolean nativeLoaded() {
        return runtimeHostBundle.nativeLoaded.getAsBoolean();
    }

    @Override
    public UserlandInstallState installState() {
        return runtimeHostBundle.installState.get();
    }

    @Override
    public void setInstallState(UserlandInstallState installState) {
        runtimeHostBundle.setInstallState.accept(installState);
    }

    @Override
    public UserlandReadinessState readinessState() {
        return runtimeHostBundle.readinessState.get();
    }

    @Override
    public SurfaceView surfaceView() {
        return runtimeUiBundle.surfaceView.get();
    }

    @Override
    public View productBootstrapBlocker() {
        return runtimeUiBundle.productBootstrapBlocker.get();
    }

    @Override
    public TerminalScrollOverlayView terminalScrollOverlay() {
        return runtimeUiBundle.terminalScrollOverlay.get();
    }

    @Override
    public TerminalSelectionController selectionController() {
        return runtimeUiBundle.selectionController.get();
    }

    @Override
    public ProductShellStatePresenter productShellStatePresenter() {
        return runtimeUiBundle.productShellStatePresenter.get();
    }

    @Override
    public FrameLoopController frameLoopController() {
        return runtimeUiBundle.frameLoopController.get();
    }

    @Override
    public TerminalStatusController terminalStatusController() {
        return runtimeUiBundle.terminalStatusController.get();
    }

    @Override
    public UserlandSessionCoordinator userlandSessionCoordinator() {
        return runtimeUiBundle.userlandSessionCoordinator.get();
    }

    @Override
    public TerminalGestureStateController terminalGestureStateController() {
        return runtimeUiBundle.terminalGestureStateController.get();
    }

    @Override
    public void appendEvent(String message) {
        runtimeHostBundle.appendEvent.accept(message);
    }

    @Override
    public void updateStatus(String statusLabel) {
        runtimeHostBundle.updateStatus.accept(statusLabel);
    }
}
