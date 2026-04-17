package uk.laurencegouws.terminal.host.ui;

import android.view.View;

import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsController;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetController;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;

/** Functional callback adapter for {@link UiStartupAssembly.Host}. */
public final class UiStartupCallbacks implements UiStartupAssembly.Host {
    private final ViewportController viewportController;
    private final ChromeController chromeController;
    private final RuntimeAssetsController runtimeAssetsController;
    private final ViewModeController viewModeController;
    private final SurfaceController surfaceHostController;
    private final SurfaceWidgetController surfaceWidgetController;
    private final ShellStatePresenter ShellStatePresenter;
    private final FrameLoopController frameLoopController;
    private final View leftSidebar;

    public UiStartupCallbacks(
            ViewportController viewportController,
            ChromeController chromeController,
            RuntimeAssetsController runtimeAssetsController,
            ViewModeController viewModeController,
            SurfaceController surfaceHostController,
            SurfaceWidgetController surfaceWidgetController,
            ShellStatePresenter ShellStatePresenter,
            FrameLoopController frameLoopController,
            View leftSidebar) {
        this.viewportController = viewportController;
        this.chromeController = chromeController;
        this.runtimeAssetsController = runtimeAssetsController;
        this.viewModeController = viewModeController;
        this.surfaceHostController = surfaceHostController;
        this.surfaceWidgetController = surfaceWidgetController;
        this.ShellStatePresenter = ShellStatePresenter;
        this.frameLoopController = frameLoopController;
        this.leftSidebar = leftSidebar;
    }

    @Override
    public ViewportController viewportController() {
        return viewportController;
    }

    @Override
    public ChromeController chromeController() {
        return chromeController;
    }

    @Override
    public RuntimeAssetsController runtimeAssetsController() {
        return runtimeAssetsController;
    }

    @Override
    public ViewModeController viewModeController() {
        return viewModeController;
    }

    @Override
    public SurfaceController surfaceHostController() {
        return surfaceHostController;
    }

    @Override
    public SurfaceWidgetController surfaceWidgetController() {
        return surfaceWidgetController;
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
    public View leftSidebar() {
        return leftSidebar;
    }
}
