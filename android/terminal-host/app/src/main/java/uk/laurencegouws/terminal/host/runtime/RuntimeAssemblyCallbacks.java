package uk.laurencegouws.terminal.host.runtime;

import android.view.View;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.scroll.ScrollOverlayView;
import uk.laurencegouws.terminal.selection.SelectionController;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/** Functional callback adapter for {@link RuntimeAssembly.Host}. */
public final class RuntimeAssemblyCallbacks implements RuntimeAssembly.Host {
    private final Supplier<UserlandInstallState> installState;
    private final Consumer<UserlandInstallState> setInstallState;
    private final Supplier<UserlandReadinessState> readinessState;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Supplier<SurfaceBridge> surfaceHostBridge;
    private final View productReadinessBlocker;
    private final ScrollOverlayView terminalScrollOverlay;
    private final SelectionController selectionController;
    private final ShellStatePresenter ShellStatePresenter;
    private final FrameLoopController frameLoopController;
    private final StatusController StatusController;
    private final UserlandSessionCoordinator userlandSessionCoordinator;
    private final GestureStateController GestureStateController;

    public RuntimeAssemblyCallbacks(
            Supplier<UserlandInstallState> installState,
            Consumer<UserlandInstallState> setInstallState,
            Supplier<UserlandReadinessState> readinessState,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Supplier<SurfaceBridge> surfaceHostBridge,
            View productReadinessBlocker,
            ScrollOverlayView terminalScrollOverlay,
            SelectionController selectionController,
            ShellStatePresenter ShellStatePresenter,
            FrameLoopController frameLoopController,
            StatusController StatusController,
            UserlandSessionCoordinator userlandSessionCoordinator,
            GestureStateController GestureStateController) {
        this.installState = installState;
        this.setInstallState = setInstallState;
        this.readinessState = readinessState;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.surfaceHostBridge = surfaceHostBridge;
        this.productReadinessBlocker = productReadinessBlocker;
        this.terminalScrollOverlay = terminalScrollOverlay;
        this.selectionController = selectionController;
        this.ShellStatePresenter = ShellStatePresenter;
        this.frameLoopController = frameLoopController;
        this.StatusController = StatusController;
        this.userlandSessionCoordinator = userlandSessionCoordinator;
        this.GestureStateController = GestureStateController;
    }

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
    public SurfaceBridge surfaceHostBridge() {
        return surfaceHostBridge.get();
    }

    @Override
    public View productReadinessBlocker() {
        return productReadinessBlocker;
    }

    @Override
    public ScrollOverlayView terminalScrollOverlay() {
        return terminalScrollOverlay;
    }

    @Override
    public SelectionController selectionController() {
        return selectionController;
    }

    @Override
    public ShellStatePresenter ShellStatePresenter() {
        return ShellStatePresenter;
    }

    @Override
    public FrameLoopController frameLoopController() {
        return frameLoopController;
    }

    @Override
    public StatusController StatusController() {
        return StatusController;
    }

    @Override
    public UserlandSessionCoordinator userlandSessionCoordinator() {
        return userlandSessionCoordinator;
    }

    @Override
    public GestureStateController GestureStateController() {
        return GestureStateController;
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
