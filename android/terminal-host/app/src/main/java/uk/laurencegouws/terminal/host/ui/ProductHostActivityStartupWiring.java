package uk.laurencegouws.terminal.host.ui;

import android.app.Activity;
import android.content.Context;
import android.os.Handler;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.FrameLayout;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.host.interaction.InteractionCallbacks;
import uk.laurencegouws.terminal.host.input.InputCallbacks;
import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssemblyCallbacks;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsController;
import uk.laurencegouws.terminal.host.session.SessionAssemblyCallbacks;
import uk.laurencegouws.terminal.host.status.StatusViewCallbacks;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetController;
import uk.laurencegouws.terminal.host.userland.WorkflowAssemblyCallbacks;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.scroll.ScrollOverlayView;
import uk.laurencegouws.terminal.selection.SelectionController;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandRelease;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/**
 * Static factories for {@code ZideActivity} onCreate callback assembly — keeps the activity
 * orchestration-only while preserving exact forwarder wiring and startup order.
 */
public final class ProductHostActivityStartupWiring {
    private ProductHostActivityStartupWiring() {
    }

    public static StatusViewCallbacks statusView(
            Activity activity,
            BooleanSupplier hasWindowFocus,
            ProductHostImeState productHostImeState,
            ProductHostStartupBundle hostStartup,
            Supplier<SurfaceBridge> surfaceBridge,
            Supplier<UserlandInstallState> currentInstallState,
            Supplier<UserlandReadinessState> currentReadinessState) {
        return new StatusViewCallbacks(
                activity,
                hasWindowFocus,
                productHostImeState,
                surfaceBridge,
                hostStartup.surface::notifyVisibleViewportIfReady,
                currentInstallState,
                currentReadinessState);
    }

    /** Interaction assembly callbacks; {@code hostDeclaredTerminalWidgetSlot} is the startup declared-slot value. */
    public static InteractionCallbacks interaction(
            ProductHostDeclaredTerminalWidgetSlot hostDeclaredTerminalWidgetSlot,
            Context harnessContext,
            Handler handler,
            FrameLayout productSurfaceContainer,
            IntSupplier productViewportWidthPx,
            IntSupplier productViewportHeightPx,
            ProductHostStartupBundle hostStartup,
            Consumer<String> appendEvent) {
        return new InteractionCallbacks(
                hostDeclaredTerminalWidgetSlot,
                harnessContext,
                handler,
                productSurfaceContainer,
                productViewportWidthPx,
                productViewportHeightPx,
                hostStartup.runtime::stopScrollbackFlingIfReady,
                hostStartup.runtime::refreshScrollOverlayIfReady,
                hostStartup.frameLoop::reevaluateFrameLoopIfReady,
                appendEvent);
    }

    public static InputCallbacks input(
            Context harnessContext,
            ShellInputView.Host shellInputHost,
            View rootView,
            InputMethodManager inputMethodManager,
            ProductHostImeState productHostImeState,
            ProductHostStartupBundle hostStartup,
            Consumer<String> updateStatus,
            Consumer<String> appendEvent) {
        return new InputCallbacks(
                harnessContext,
                shellInputHost,
                rootView,
                inputMethodManager,
                productHostImeState,
                hostStartup.runtime::refreshScrollOverlayIfReady,
                updateStatus,
                appendEvent);
    }

    public static SessionAssemblyCallbacks session(
            Context context,
            UserlandRelease userlandRelease,
            Handler handler,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Consumer<UserlandReadinessState> setCurrentReadinessState,
            ProductHostStartupBundle hostStartup,
            boolean nativeLoaded) {
        return new SessionAssemblyCallbacks(
                context,
                userlandRelease,
                handler,
                appendEvent,
                updateStatus,
                setCurrentReadinessState,
                hostStartup.runtime::refreshShellStateIfReady,
                hostStartup.runtime::refreshStatusTelemetryIfReady,
                hostStartup.runtime::shouldRunFrameLoop,
                () -> hostStartup.runtime.tickFrameAndRefreshScrollOverlay(nativeLoaded));
    }

    public static WorkflowAssemblyCallbacks workflow(
            Context context,
            Handler handler,
            Supplier<UserlandRelease> userlandRelease,
            Consumer<UserlandRelease> setUserlandRelease,
            Consumer<String> appendEvent,
            ProductHostStartupBundle hostStartup) {
        return new WorkflowAssemblyCallbacks(
                context,
                handler,
                userlandRelease,
                setUserlandRelease,
                appendEvent,
                hostStartup.runtime::applyInstallStateIfReady,
                hostStartup.workflowInstall::completeInstallIfReady,
                hostStartup.workflowInstall::failInstallIfReady,
                hostStartup.runtime::restartSessionAfterInstallIfReady,
                hostStartup.telemetry::markPackageDoctorCompleteIfReady);
    }

    public static RuntimeAssemblyCallbacks runtime(
            Supplier<UserlandInstallState> currentInstallState,
            Consumer<UserlandInstallState> setInstallState,
            Supplier<UserlandReadinessState> currentReadinessState,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Supplier<SurfaceBridge> surfaceBridge,
            View productReadinessBlocker,
            ScrollOverlayView terminalScrollOverlay,
            SelectionController selectionController,
            ShellStatePresenter shellStatePresenter,
            FrameLoopController frameLoopController,
            StatusController statusController,
            UserlandSessionCoordinator userlandSessionCoordinator,
            GestureStateController gestureStateController) {
        return new RuntimeAssemblyCallbacks(
                currentInstallState,
                setInstallState,
                currentReadinessState,
                appendEvent,
                updateStatus,
                surfaceBridge,
                productReadinessBlocker,
                terminalScrollOverlay,
                selectionController,
                shellStatePresenter,
                frameLoopController,
                statusController,
                userlandSessionCoordinator,
                gestureStateController);
    }

    public static UiStartupCallbacks uiStartup(
            ViewportController viewportController,
            ChromeController chromeController,
            RuntimeAssetsController runtimeAssetsController,
            ViewModeController viewModeController,
            SurfaceController surfaceHostController,
            SurfaceWidgetController surfaceWidgetController,
            ShellStatePresenter shellStatePresenter,
            FrameLoopController frameLoopController,
            View leftSidebar) {
        return new UiStartupCallbacks(
                viewportController,
                chromeController,
                runtimeAssetsController,
                viewModeController,
                surfaceHostController,
                surfaceWidgetController,
                shellStatePresenter,
                frameLoopController,
                leftSidebar);
    }
}
