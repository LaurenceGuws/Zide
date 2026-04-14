package dev.zide.terminal.host.runtime;

import android.view.SurfaceView;
import android.view.View;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

import dev.zide.terminal.debug.TerminalStatusController;
import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.scroll.TerminalScrollOverlayView;
import dev.zide.terminal.selection.TerminalSelectionController;
import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;

/** Functional callback adapter for {@link ProductRuntimeController}. */
public final class ProductRuntimeHostCallbacks implements ProductRuntimeController.Host {
    private final BooleanSupplier debugViewEnabled;
    private final BooleanSupplier nativeLoaded;
    private final Supplier<UserlandInstallState> installState;
    private final Consumer<UserlandInstallState> setInstallState;
    private final Supplier<UserlandReadinessState> readinessState;
    private final Supplier<SurfaceView> surfaceView;
    private final Supplier<View> productBootstrapBlocker;
    private final Supplier<TerminalScrollOverlayView> terminalScrollOverlay;
    private final Supplier<TerminalSelectionController> selectionController;
    private final Supplier<ProductShellStatePresenter> productShellStatePresenter;
    private final Supplier<FrameLoopController> frameLoopController;
    private final Supplier<TerminalStatusController> terminalStatusController;
    private final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;
    private final Supplier<TerminalGestureStateController> terminalGestureStateController;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final IntSupplier nativeCurrentShellVisibleRows;
    private final IntSupplier nativeCurrentShellScrollbackCount;
    private final IntSupplier nativeCurrentShellScrollbackOffset;
    private final IntSupplier nativeRestartShellSession;

    public ProductRuntimeHostCallbacks(
            BooleanSupplier debugViewEnabled,
            BooleanSupplier nativeLoaded,
            Supplier<UserlandInstallState> installState,
            Consumer<UserlandInstallState> setInstallState,
            Supplier<UserlandReadinessState> readinessState,
            Supplier<SurfaceView> surfaceView,
            Supplier<View> productBootstrapBlocker,
            Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
            Supplier<TerminalSelectionController> selectionController,
            Supplier<ProductShellStatePresenter> productShellStatePresenter,
            Supplier<FrameLoopController> frameLoopController,
            Supplier<TerminalStatusController> terminalStatusController,
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
            Supplier<TerminalGestureStateController> terminalGestureStateController,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            IntSupplier nativeCurrentShellVisibleRows,
            IntSupplier nativeCurrentShellScrollbackCount,
            IntSupplier nativeCurrentShellScrollbackOffset,
            IntSupplier nativeRestartShellSession) {
        this.debugViewEnabled = debugViewEnabled;
        this.nativeLoaded = nativeLoaded;
        this.installState = installState;
        this.setInstallState = setInstallState;
        this.readinessState = readinessState;
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
        this.nativeCurrentShellVisibleRows = nativeCurrentShellVisibleRows;
        this.nativeCurrentShellScrollbackCount = nativeCurrentShellScrollbackCount;
        this.nativeCurrentShellScrollbackOffset = nativeCurrentShellScrollbackOffset;
        this.nativeRestartShellSession = nativeRestartShellSession;
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
    public UserlandReadinessState readinessState() {
        return readinessState.get();
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

    @Override
    public int nativeCurrentShellVisibleRows() {
        return nativeCurrentShellVisibleRows.getAsInt();
    }

    @Override
    public int nativeCurrentShellScrollbackCount() {
        return nativeCurrentShellScrollbackCount.getAsInt();
    }

    @Override
    public int nativeCurrentShellScrollbackOffset() {
        return nativeCurrentShellScrollbackOffset.getAsInt();
    }

    @Override
    public int nativeRestartShellSession() {
        return nativeRestartShellSession.getAsInt();
    }
}
