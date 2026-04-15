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
    private final BooleanSupplier debugViewEnabled;
    private final Supplier<UserlandInstallState> installState;
    private final Consumer<UserlandInstallState> setInstallState;
    private final Supplier<UserlandReadinessState> readinessState;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Supplier<SurfaceView> surfaceView;
    private final Supplier<View> productReadinessBlocker;
    private final Supplier<TerminalScrollOverlayView> terminalScrollOverlay;
    private final Supplier<TerminalSelectionController> selectionController;
    private final Supplier<ProductShellStatePresenter> productShellStatePresenter;
    private final Supplier<FrameLoopController> frameLoopController;
    private final Supplier<TerminalStatusController> terminalStatusController;
    private final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;
    private final Supplier<TerminalGestureStateController> terminalGestureStateController;

    public ProductRuntimeAssemblyCallbacks(
            BooleanSupplier debugViewEnabled,
            Supplier<UserlandInstallState> installState,
            Consumer<UserlandInstallState> setInstallState,
            Supplier<UserlandReadinessState> readinessState,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Supplier<SurfaceView> surfaceView,
            Supplier<View> productReadinessBlocker,
            Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
            Supplier<TerminalSelectionController> selectionController,
            Supplier<ProductShellStatePresenter> productShellStatePresenter,
            Supplier<FrameLoopController> frameLoopController,
            Supplier<TerminalStatusController> terminalStatusController,
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
            Supplier<TerminalGestureStateController> terminalGestureStateController) {
        this.debugViewEnabled = debugViewEnabled;
        this.installState = installState;
        this.setInstallState = setInstallState;
        this.readinessState = readinessState;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.surfaceView = surfaceView;
        this.productReadinessBlocker = productReadinessBlocker;
        this.terminalScrollOverlay = terminalScrollOverlay;
        this.selectionController = selectionController;
        this.productShellStatePresenter = productShellStatePresenter;
        this.frameLoopController = frameLoopController;
        this.terminalStatusController = terminalStatusController;
        this.userlandSessionCoordinator = userlandSessionCoordinator;
        this.terminalGestureStateController = terminalGestureStateController;
    }

    @Override
    public boolean debugViewEnabled() {
        return debugViewEnabled.getAsBoolean();
    }

    @Override
    public UserlandInstallState installState() {
        return installState.get();
    }

    @Override
    public void setInstallState(UserlandInstallState installState) {
        setInstallState.accept(installState);
    }

    @Override
    public UserlandReadinessState readinessState() {
        return readinessState.get();
    }

    @Override
    public SurfaceView surfaceView() {
        return surfaceView.get();
    }

    @Override
    public View productReadinessBlocker() {
        return productReadinessBlocker.get();
    }

    @Override
    public TerminalScrollOverlayView terminalScrollOverlay() {
        return terminalScrollOverlay.get();
    }

    @Override
    public TerminalSelectionController selectionController() {
        return selectionController.get();
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
    public TerminalStatusController terminalStatusController() {
        return terminalStatusController.get();
    }

    @Override
    public UserlandSessionCoordinator userlandSessionCoordinator() {
        return userlandSessionCoordinator.get();
    }

    @Override
    public TerminalGestureStateController terminalGestureStateController() {
        return terminalGestureStateController.get();
    }

    @Override
    public void appendEvent(String message) {
        appendEvent.accept(message);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }
}
