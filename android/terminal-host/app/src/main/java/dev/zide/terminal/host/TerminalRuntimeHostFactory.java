package dev.zide.terminal.host;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

import dev.zide.terminal.debug.TerminalStatusController;
import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.host.runtime.ProductRuntimeController;
import dev.zide.terminal.host.runtime.ProductRuntimeHostCallbacks;
import dev.zide.terminal.scroll.TerminalScrollOverlayView;
import dev.zide.terminal.selection.TerminalSelectionController;
import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;

/** Runtime host assembly helpers. */
public final class TerminalRuntimeHostFactory {
    private TerminalRuntimeHostFactory() {
    }

    public static ProductRuntimeController createProductRuntimeController(
            ProductRuntimeController.Host host) {
        return new ProductRuntimeController(host);
    }

    public static ProductRuntimeController.Host createProductRuntimeHostCallbacks(
            BooleanSupplier debugViewEnabled,
            BooleanSupplier nativeLoaded,
            Supplier<UserlandInstallState> installState,
            Consumer<UserlandInstallState> setInstallState,
            Supplier<UserlandReadinessState> readinessState,
            Supplier<android.view.SurfaceView> surfaceView,
            Supplier<android.view.View> productBootstrapBlocker,
            Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
            Supplier<TerminalSelectionController> selectionController,
            Supplier<ProductShellStatePresenter> productShellStatePresenter,
            Supplier<TerminalFrameLoopController> frameLoopController,
            Supplier<TerminalStatusController> terminalStatusController,
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
            Supplier<TerminalGestureStateController> terminalGestureStateController,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            IntSupplier nativeCurrentShellVisibleRows,
            IntSupplier nativeCurrentShellScrollbackCount,
            IntSupplier nativeCurrentShellScrollbackOffset,
            IntSupplier nativeRestartShellSession) {
        return new ProductRuntimeHostCallbacks(
                debugViewEnabled,
                nativeLoaded,
                installState,
                setInstallState,
                readinessState,
                surfaceView,
                productBootstrapBlocker,
                terminalScrollOverlay,
                selectionController,
                productShellStatePresenter,
                frameLoopController,
                terminalStatusController,
                userlandSessionCoordinator,
                terminalGestureStateController,
                appendEvent,
                updateStatus,
                nativeCurrentShellVisibleRows,
                nativeCurrentShellScrollbackCount,
                nativeCurrentShellScrollbackOffset,
                nativeRestartShellSession);
    }

    public static TerminalFrameLoopController createFrameLoopController(
            android.os.Handler handler,
            BooleanSupplier shouldRunProductFrameLoop,
            IntSupplier tickProductFrame) {
        return new TerminalFrameLoopController(
                handler,
                new TerminalFrameLoopHostBridge(new TerminalFrameLoopHostCallbacks(
                        shouldRunProductFrameLoop,
                        tickProductFrame)));
    }
}
