package uk.laurencegouws.terminal.host.runtime;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.TerminalStatusController;
import uk.laurencegouws.terminal.gesture.TerminalGestureStateController;
import uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView;
import uk.laurencegouws.terminal.selection.TerminalSelectionController;
import uk.laurencegouws.terminal.userland.ProductShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/** Runtime host assembly helpers. */
public final class RuntimeFactory {
    private RuntimeFactory() {
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
            Supplier<android.view.View> productReadinessBlocker,
            Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
            Supplier<TerminalSelectionController> selectionController,
            Supplier<ProductShellStatePresenter> productShellStatePresenter,
            Supplier<FrameLoopController> frameLoopController,
            Supplier<TerminalStatusController> terminalStatusController,
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
            Supplier<TerminalGestureStateController> terminalGestureStateController,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus) {
        return new ProductRuntimeHostCallbacks(
                debugViewEnabled,
                nativeLoaded,
                installState,
                setInstallState,
                readinessState,
                surfaceView,
                productReadinessBlocker,
                terminalScrollOverlay,
                selectionController,
                productShellStatePresenter,
                frameLoopController,
                terminalStatusController,
                userlandSessionCoordinator,
                terminalGestureStateController,
                appendEvent,
                updateStatus);
    }

    public static FrameLoopController createFrameLoopController(
            android.os.Handler handler,
            BooleanSupplier shouldRunProductFrameLoop,
            IntSupplier tickProductFrame) {
        return new FrameLoopController(
                handler,
                new FrameLoopBridge(new FrameLoopCallbacks(
                        shouldRunProductFrameLoop,
                        tickProductFrame)));
    }
}
