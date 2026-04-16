package uk.laurencegouws.terminal.host.runtime;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
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

/** Runtime host assembly helpers. */
public final class RuntimeFactory {
    private RuntimeFactory() {
    }

    public static RuntimeController createRuntimeController(
            RuntimeController.Host host) {
        return new RuntimeController(host);
    }

    public static RuntimeController.Host createRuntimeHostCallbacks(
            BooleanSupplier debugViewEnabled,
            Supplier<UserlandInstallState> installState,
            Consumer<UserlandInstallState> setInstallState,
            Supplier<UserlandReadinessState> readinessState,
            Supplier<SurfaceBridge> surfaceHostBridge,
            android.view.View productReadinessBlocker,
            ScrollOverlayView terminalScrollOverlay,
            SelectionController selectionController,
            ShellStatePresenter ShellStatePresenter,
            FrameLoopController frameLoopController,
            StatusController StatusController,
            UserlandSessionCoordinator userlandSessionCoordinator,
            GestureStateController GestureStateController,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus) {
        return new RuntimeHostCallbacks(
                debugViewEnabled,
                installState,
                setInstallState,
                readinessState,
                surfaceHostBridge,
                productReadinessBlocker,
                terminalScrollOverlay,
                selectionController,
                ShellStatePresenter,
                frameLoopController,
                StatusController,
                userlandSessionCoordinator,
                GestureStateController,
                appendEvent,
                updateStatus);
    }

    public static FrameLoopController createFrameLoopController(
            android.os.Handler handler,
            BooleanSupplier shouldRunFrameLoop,
            IntSupplier tickFrame) {
        return new FrameLoopController(
                handler,
                new FrameLoopBridge(new FrameLoopCallbacks(
                        shouldRunFrameLoop,
                        tickFrame)));
    }
}
