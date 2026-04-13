package dev.zide.terminal.host;

import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.scroll.TerminalScrollOverlayView;
import dev.zide.terminal.selection.TerminalSelectionController;
import dev.zide.terminal.session.ShellSessionController;
import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.userland.UserlandRelease;
import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;
import dev.zide.terminal.debug.TerminalStatusController;

/** Assembly helpers for Android terminal host controllers and bridges. */
public final class TerminalHostAssembler {
    private TerminalHostAssembler() {
    }

    public static TerminalProductRuntimeController createProductRuntimeController(
            TerminalProductRuntimeController.Host host) {
        return new TerminalProductRuntimeController(host);
    }

    public static TerminalProductRuntimeController.Host createProductRuntimeHostCallbacks(
            BooleanSupplier debugViewEnabled,
            BooleanSupplier nativeLoaded,
            Supplier<UserlandInstallState> installState,
            Consumer<UserlandInstallState> setInstallState,
            Supplier<UserlandBootstrapState> bootstrapState,
            Supplier<android.view.SurfaceView> surfaceView,
            Supplier<View> productBootstrapBlocker,
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
        return new TerminalProductRuntimeHostCallbacks(
                debugViewEnabled,
                nativeLoaded,
                installState,
                setInstallState,
                bootstrapState,
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

    public static TerminalProductShellStateHostBridge createProductShellStateHostBridge(
            View productBootstrapBlocker,
            View terminalScrollOverlay,
            TextView productBootstrapTitle,
            TextView productBootstrapDetail,
            android.widget.Button productBootstrapRetryButton,
            TerminalProductShellStateHostBridge.Callbacks callbacks) {
        return new TerminalProductShellStateHostBridge(
                productBootstrapBlocker,
                terminalScrollOverlay,
                productBootstrapTitle,
                productBootstrapDetail,
                productBootstrapRetryButton,
                callbacks);
    }

    public static TerminalViewModeController createViewModeController(
            View productView,
            View debugView,
            View terminalScrollOverlay,
            FrameLayout productSurfaceContainer,
            TerminalViewModeController.Host host) {
        return new TerminalViewModeController(
                productView,
                debugView,
                terminalScrollOverlay,
                productSurfaceContainer,
                host);
    }

    public static TerminalSurfaceWidgetController createSurfaceWidgetController(
            TerminalSurfaceHostController surfaceHostController,
            TerminalSelectionController selectionController,
            TerminalGestureStateController terminalGestureStateController,
            TerminalSurfaceWidgetController.Host host) {
        return new TerminalSurfaceWidgetController(
                surfaceHostController,
                selectionController,
                terminalGestureStateController,
                host);
    }

    public static ShellSessionController createShellSessionController(
            String bootstrapStampPath,
            String shellPath,
            UserlandRelease userlandRelease,
            boolean nativeLoaded,
            IntSupplier restart,
            IntSupplier poll,
            BooleanSupplier isAlive) {
        return new ShellSessionController(
                new TerminalShellSessionBridge(new TerminalShellSessionCallbacks(
                        restart,
                        poll,
                        isAlive)),
                bootstrapStampPath,
                shellPath,
                userlandRelease,
                nativeLoaded);
    }

    public static TerminalUserlandSessionHostBridge createUserlandSessionHostBridge(
            Consumer<String> appendEvent,
            Function<Integer, String> shellStartStatusLabel,
            Consumer<UserlandBootstrapState> applyBootstrapState,
            Runnable refreshProductShellState,
            Runnable refreshDebugStatusSurface,
            Consumer<String> updateStatus) {
        return new TerminalUserlandSessionHostBridge(
                new TerminalUserlandSessionHostCallbacks(
                        appendEvent,
                        shellStartStatusLabel,
                        applyBootstrapState,
                        refreshProductShellState,
                        refreshDebugStatusSurface,
                        updateStatus));
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
