package dev.zide.terminal.host;

import android.view.SurfaceView;
import android.view.View;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import dev.zide.terminal.debug.TerminalStatusController;
import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.scroll.TerminalScrollOverlayView;
import dev.zide.terminal.selection.TerminalSelectionController;
import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;

/** Functional callback adapter for {@link TerminalProductRuntimeAssembly.Host}. */
public final class TerminalProductRuntimeAssemblyHostCallbacks implements TerminalProductRuntimeAssembly.Host {
    private final BooleanSupplier debugViewEnabled;
    private final BooleanSupplier nativeLoaded;
    private final Supplier<UserlandInstallState> installState;
    private final Consumer<UserlandInstallState> setInstallState;
    private final Supplier<UserlandBootstrapState> bootstrapState;
    private final Supplier<SurfaceView> surfaceView;
    private final Supplier<View> productBootstrapBlocker;
    private final Supplier<TerminalScrollOverlayView> terminalScrollOverlay;
    private final Supplier<TerminalSelectionController> selectionController;
    private final Supplier<ProductShellStatePresenter> productShellStatePresenter;
    private final Supplier<TerminalFrameLoopController> frameLoopController;
    private final Supplier<TerminalStatusController> terminalStatusController;
    private final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;
    private final Supplier<TerminalGestureStateController> terminalGestureStateController;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;

    public TerminalProductRuntimeAssemblyHostCallbacks(
            BooleanSupplier debugViewEnabled,
            BooleanSupplier nativeLoaded,
            Supplier<UserlandInstallState> installState,
            Consumer<UserlandInstallState> setInstallState,
            Supplier<UserlandBootstrapState> bootstrapState,
            Supplier<SurfaceView> surfaceView,
            Supplier<View> productBootstrapBlocker,
            Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
            Supplier<TerminalSelectionController> selectionController,
            Supplier<ProductShellStatePresenter> productShellStatePresenter,
            Supplier<TerminalFrameLoopController> frameLoopController,
            Supplier<TerminalStatusController> terminalStatusController,
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
            Supplier<TerminalGestureStateController> terminalGestureStateController,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus) {
        this.debugViewEnabled = debugViewEnabled;
        this.nativeLoaded = nativeLoaded;
        this.installState = installState;
        this.setInstallState = setInstallState;
        this.bootstrapState = bootstrapState;
        this.surfaceView = surfaceView;
        this.productBootstrapBlocker = productBootstrapBlocker;
        this.terminalScrollOverlay = terminalScrollOverlay;
        this.selectionController = selectionController;
        this.productShellStatePresenter = productShellStatePresenter;
        this.frameLoopController = frameLoopController;
        this.terminalStatusController = terminalStatusController;
        this.userlandSessionCoordinator = userlandSessionCoordinator;
        this.terminalGestureStateController = terminalGestureStateController;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
    }

    @Override
    public boolean debugViewEnabled() {
        return debugViewEnabled.getAsBoolean();
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
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
    public UserlandBootstrapState bootstrapState() {
        return bootstrapState.get();
    }

    @Override
    public SurfaceView surfaceView() {
        return surfaceView.get();
    }

    @Override
    public View productBootstrapBlocker() {
        return productBootstrapBlocker.get();
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
    public TerminalFrameLoopController frameLoopController() {
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
