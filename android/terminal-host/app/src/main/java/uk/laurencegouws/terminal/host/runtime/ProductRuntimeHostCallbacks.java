package uk.laurencegouws.terminal.host.runtime;

import android.view.SurfaceView;
import android.view.View;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.TerminalNativeBridge;
import uk.laurencegouws.terminal.debug.TerminalStatusController;
import uk.laurencegouws.terminal.gesture.TerminalGestureStateController;
import uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView;
import uk.laurencegouws.terminal.selection.TerminalSelectionController;
import uk.laurencegouws.terminal.userland.ProductShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/** Functional callback adapter for {@link ProductRuntimeController}. */
public final class ProductRuntimeHostCallbacks implements ProductRuntimeController.Host {
    private final BooleanSupplier debugViewEnabled;
    private final Supplier<UserlandInstallState> installState;
    private final Consumer<UserlandInstallState> setInstallState;
    private final Supplier<UserlandReadinessState> readinessState;
    private final Supplier<SurfaceView> surfaceView;
    private final View productReadinessBlocker;
    private final TerminalScrollOverlayView terminalScrollOverlay;
    private final TerminalSelectionController selectionController;
    private final ProductShellStatePresenter productShellStatePresenter;
    private final FrameLoopController frameLoopController;
    private final TerminalStatusController terminalStatusController;
    private final UserlandSessionCoordinator userlandSessionCoordinator;
    private final TerminalGestureStateController terminalGestureStateController;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;

    public ProductRuntimeHostCallbacks(
            BooleanSupplier debugViewEnabled,
            Supplier<UserlandInstallState> installState,
            Consumer<UserlandInstallState> setInstallState,
            Supplier<UserlandReadinessState> readinessState,
            Supplier<SurfaceView> surfaceView,
            View productReadinessBlocker,
            TerminalScrollOverlayView terminalScrollOverlay,
            TerminalSelectionController selectionController,
            ProductShellStatePresenter productShellStatePresenter,
            FrameLoopController frameLoopController,
            TerminalStatusController terminalStatusController,
            UserlandSessionCoordinator userlandSessionCoordinator,
            TerminalGestureStateController terminalGestureStateController,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus) {
        this.debugViewEnabled = debugViewEnabled;
        this.installState = installState;
        this.setInstallState = setInstallState;
        this.readinessState = readinessState;
        this.surfaceView = surfaceView;
        this.productReadinessBlocker = productReadinessBlocker;
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
        return TerminalNativeBridge.nativeLoaded();
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
        return productReadinessBlocker;
    }

    @Override
    public TerminalScrollOverlayView terminalScrollOverlay() {
        return terminalScrollOverlay;
    }

    @Override
    public TerminalSelectionController selectionController() {
        return selectionController;
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
    public TerminalStatusController terminalStatusController() {
        return terminalStatusController;
    }

    @Override
    public UserlandSessionCoordinator userlandSessionCoordinator() {
        return userlandSessionCoordinator;
    }

    @Override
    public TerminalGestureStateController terminalGestureStateController() {
        return terminalGestureStateController;
    }

    @Override
    public void appendEvent(String message) {
        appendEvent.accept(message);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }

    @Override
    public int nativeCurrentSessionVisibleRows() {
        return TerminalNativeBridge.nativeCurrentSessionVisibleRowsBridge();
    }

    @Override
    public int nativeCurrentSessionScrollbackCount() {
        return TerminalNativeBridge.nativeCurrentSessionScrollbackCountBridge();
    }

    @Override
    public int nativeCurrentSessionScrollbackOffset() {
        return TerminalNativeBridge.nativeCurrentSessionScrollbackOffsetBridge();
    }

    @Override
    public int nativeRestartSession() {
        return TerminalNativeBridge.nativeRestartSessionBridge();
    }
}
