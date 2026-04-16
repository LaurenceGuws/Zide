package uk.laurencegouws.terminal.host.ui;

import android.view.View;
import android.widget.Button;

import java.util.function.Consumer;

import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetController;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsController;
import uk.laurencegouws.terminal.host.userland.ReadinessBlockerCallbacks;
import uk.laurencegouws.terminal.userland.UserlandReadinessBlockerController;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;
import uk.laurencegouws.terminal.userland.UserlandWorkflowController;

/** Owns post-construction UI bind/start wiring for the activity. */
public final class UiStartupAssembly {
    /** Activity callbacks required for UI startup wiring. */
    public interface Host {
        ViewportController viewportController();

        ChromeController chromeController();

        Button productReadinessRetryButton();

        Button productReadinessDebugButton();

        UserlandInstallState currentInstallState();

        UserlandReadinessState currentReadinessState();

        UserlandWorkflowController userlandWorkflowController();

        UserlandSessionCoordinator userlandSessionCoordinator();

        Consumer<String> appendEvent();

        Consumer<String> updateStatus();

        RuntimeAssetsController runtimeAssetsController();

        ViewModeController viewModeController();

        SurfaceController surfaceHostController();

        SurfaceWidgetController surfaceWidgetController();

        uk.laurencegouws.terminal.userland.ShellStatePresenter ShellStatePresenter();

        FrameLoopController frameLoopController();

        View leftSidebar();
    }

    /** Immutable startup result values. */
    public static final class Result {
        public final UserlandReadinessBlockerController userlandReadinessBlockerController;

        private Result(UserlandReadinessBlockerController userlandReadinessBlockerController) {
            this.userlandReadinessBlockerController = userlandReadinessBlockerController;
        }
    }

    private UiStartupAssembly() {
    }

    public static Result start(Host host) {
        host.viewportController().installInsetsHandling();
        host.viewportController().installViewportTracking();
        host.chromeController().bindSidebarControls();
        host.chromeController().bindViewModeToggle();
        final UserlandReadinessBlockerController userlandReadinessBlockerController =
                new UserlandReadinessBlockerController(
                        host.productReadinessRetryButton(),
                        host.productReadinessDebugButton(),
                        new ReadinessBlockerCallbacks(
                                host::currentInstallState,
                                host::currentReadinessState,
                                host.userlandWorkflowController(),
                                host.userlandSessionCoordinator(),
                                host.viewModeController()::showDebugView,
                                host.appendEvent(),
                                host.updateStatus()));
        userlandReadinessBlockerController.bind();
        host.chromeController().bindAssistBar();
        host.runtimeAssetsController().prepareRuntimeAssets();
        host.viewModeController().applyCurrentViewMode();
        host.surfaceHostController().installSurfaceView("activity-create", host.surfaceWidgetController());
        host.ShellStatePresenter().refresh();
        host.frameLoopController().reevaluate();
        host.leftSidebar().post(() -> {
            host.leftSidebar().setTranslationX(-host.leftSidebar().getWidth());
            host.chromeController().updateSidebarVisibility(false);
        });
        return new Result(userlandReadinessBlockerController);
    }
}
