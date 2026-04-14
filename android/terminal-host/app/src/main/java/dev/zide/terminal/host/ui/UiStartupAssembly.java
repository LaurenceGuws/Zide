package dev.zide.terminal.host.ui;

import android.view.View;
import android.widget.Button;

import java.util.function.Consumer;
import java.util.function.Supplier;

import dev.zide.terminal.host.ui.ChromeController;
import dev.zide.terminal.host.runtime.FrameLoopController;
import dev.zide.terminal.host.surface.SurfaceController;
import dev.zide.terminal.host.surface.SurfaceWidgetController;
import dev.zide.terminal.host.ui.ViewModeController;
import dev.zide.terminal.host.runtime.RuntimeAssetsController;
import dev.zide.terminal.host.userland.ReadinessBlockerCallbacks;
import dev.zide.terminal.userland.UserlandReadinessBlockerController;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandSessionCoordinator;
import dev.zide.terminal.userland.UserlandWorkflowController;

/** Owns post-construction UI bind/start wiring for the activity. */
public final class UiStartupAssembly {
    /** Activity callbacks required for UI startup wiring. */
    public interface Host {
        ViewportController viewportController();

        ChromeController chromeController();

        Button productBootstrapRetryButton();

        Button productBootstrapDebugButton();

        Supplier<UserlandInstallState> currentInstallState();

        Supplier<UserlandReadinessState> currentReadinessState();

        Supplier<UserlandWorkflowController> userlandWorkflowController();

        Supplier<UserlandSessionCoordinator> userlandSessionCoordinator();

        ShowDebugView showDebugView();

        Consumer<String> appendEvent();

        Consumer<String> updateStatus();

        RuntimeAssetsController runtimeAssetsController();

        ViewModeController viewModeController();

        SurfaceController surfaceHostController();

        SurfaceWidgetController surfaceWidgetController();

        dev.zide.terminal.userland.ProductShellStatePresenter productShellStatePresenter();

        FrameLoopController frameLoopController();

        View leftSidebar();
    }

    /** Functional callback for routing debug-view requests. */
    public interface ShowDebugView {
        void call(String eventName, String statusLabel);
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
                        host.productBootstrapRetryButton(),
                        host.productBootstrapDebugButton(),
                        new ReadinessBlockerCallbacks(
                                host.currentInstallState(),
                                host.currentReadinessState(),
                                host.userlandWorkflowController(),
                                host.userlandSessionCoordinator(),
                                host.showDebugView()::call,
                                host.appendEvent(),
                                host.updateStatus()));
        userlandReadinessBlockerController.bind();
        host.chromeController().bindAssistBar();
        host.runtimeAssetsController().prepareRuntimeAssets();
        host.viewModeController().applyCurrentViewMode();
        host.surfaceHostController().installSurfaceView("activity-create", host.surfaceWidgetController());
        host.productShellStatePresenter().refresh();
        host.frameLoopController().reevaluate();
        host.leftSidebar().post(() -> {
            host.leftSidebar().setTranslationX(-host.leftSidebar().getWidth());
            host.chromeController().updateSidebarVisibility(false);
        });
        return new Result(userlandReadinessBlockerController);
    }
}
