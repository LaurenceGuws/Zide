package uk.laurencegouws.terminal.host.ui;

import android.view.View;
import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetController;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsController;

/** Owns post-construction UI bind/start wiring for the activity. */
public final class UiStartupAssembly {
    /** Activity callbacks required for UI startup wiring. */
    public interface Host {
        ViewportController viewportController();

        ChromeController chromeController();

        RuntimeAssetsController runtimeAssetsController();

        ViewModeController viewModeController();

        SurfaceController surfaceHostController();

        SurfaceWidgetController surfaceWidgetController();

        uk.laurencegouws.terminal.userland.ShellStatePresenter ShellStatePresenter();

        FrameLoopController frameLoopController();

        View leftSidebar();
    }

    private UiStartupAssembly() {
    }

    public static void start(Host host, Runnable bindReadinessBlocker) {
        host.viewportController().installInsetsHandling();
        host.viewportController().installViewportTracking();
        host.chromeController().bindSidebarControls();
        bindReadinessBlocker.run();
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
    }
}
