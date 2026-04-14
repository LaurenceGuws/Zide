package dev.zide.terminal.host.ui;

import android.app.Activity;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

import dev.zide.terminal.TerminalNativeBridge;
import dev.zide.terminal.debug.AndroidDebugFormatter;
import dev.zide.terminal.gesture.ProductGestureController;
import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.host.ui.ChromeController;
import dev.zide.terminal.host.ui.ChromeFactory;
import dev.zide.terminal.host.surface.SurfaceBridge;
import dev.zide.terminal.host.surface.SurfaceController;
import dev.zide.terminal.host.surface.SurfaceWidgetAssembly;
import dev.zide.terminal.host.surface.SurfaceWidgetAssemblyCallbacks;
import dev.zide.terminal.host.surface.SurfaceWidgetController;
import dev.zide.terminal.host.ui.UiFactory;
import dev.zide.terminal.host.ui.ViewModeController;
import dev.zide.terminal.host.ui.ViewModeCallbacks;
import dev.zide.terminal.host.userland.ProductShellStateBridge;
import dev.zide.terminal.host.userland.ProductShellStateCallbacks;
import dev.zide.terminal.input.ShellInputView;
import dev.zide.terminal.scroll.TerminalScrollOverlayView;
import dev.zide.terminal.selection.TerminalSelectionController;
import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;

/** Owns product widget/chrome/view-mode/surface host assembly for activity wiring. */
public final class WidgetAssembly {
    /** Activity callbacks required to assemble widget host controllers. */
    public interface Host {
        Activity activity();

        android.os.Handler handler();

        boolean nativeLoaded();

        boolean debugViewEnabled();

        void setDebugViewEnabled(boolean enabled);

        boolean imeVisible();

        void setImeVisible(boolean visible);

        View rootView();

        View productView();

        View debugView();

        View productBootstrapBlocker();

        View drawerScrim();

        View drawerEdgeHotspot();

        View leftSidebar();

        FrameLayout productSurfaceContainer();

        TerminalScrollOverlayView terminalScrollOverlay();

        TextView productBootstrapTitle();

        TextView productBootstrapDetail();

        Button productBootstrapRetryButton();

        Button assistCtrlButton();

        Button assistAltButton();

        ShellInputView shellInputView();

        TerminalSelectionController selectionController();

        TerminalGestureStateController terminalGestureStateController();

        SurfaceBridge surfaceHostBridge();

        boolean currentInstallStateInstalling();

        boolean currentInstallStateFailed();

        UserlandReadinessState currentReadinessState();

        UserlandInstallState currentInstallState();

        boolean shouldRunProductFrameLoop();

        void refreshProductScrollOverlay();

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void callNative(String event, long seq);

        void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state);

        long nativeOnSurfaceAvailableBridge(SurfaceHolder holder, int width, int height);

        long nativeOnSurfaceDestroyedBridge();

        long nativeOnSurfaceRedrawNeededBridge();

        long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible);

        AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();

        void handleProductShellStateEvent(String statusLabel);

        int nativeSetShellScrollbackOffset(int offsetRows);

        int nativeFollowShellLiveBottom();

        int productViewportHeightPx();

        void reevaluateProductFrameLoop();

        void runPackageDoctor();

        void sendDirectText(String text);

        void notifyVisibleViewport(String reason);

        void refreshUserlandSession();
    }

    /** Immutable assembled widget host result. */
    public static final class Result {
        public final ProductShellStateBridge productShellStateHostBridge;
        public final ProductShellStatePresenter productShellStatePresenter;
        public final ChromeController terminalChromeController;
        public final ViewModeController terminalViewModeController;
        public final SurfaceBridge surfaceHostBridge;
        public final SurfaceController surfaceHostController;
        public final SurfaceWidgetController terminalSurfaceWidgetController;

        private Result(
                ProductShellStateBridge productShellStateHostBridge,
                ProductShellStatePresenter productShellStatePresenter,
                ChromeController terminalChromeController,
                ViewModeController terminalViewModeController,
                SurfaceBridge surfaceHostBridge,
                SurfaceController surfaceHostController,
                SurfaceWidgetController terminalSurfaceWidgetController) {
            this.productShellStateHostBridge = productShellStateHostBridge;
            this.productShellStatePresenter = productShellStatePresenter;
            this.terminalChromeController = terminalChromeController;
            this.terminalViewModeController = terminalViewModeController;
            this.surfaceHostBridge = surfaceHostBridge;
            this.surfaceHostController = surfaceHostController;
            this.terminalSurfaceWidgetController = terminalSurfaceWidgetController;
        }
    }

    private WidgetAssembly() {
    }

    public static Result assemble(Host host) {
        final ProductShellStateBridge productShellStateHostBridge =
                UiFactory.createProductShellStateHostBridge(
                        host.productBootstrapBlocker(),
                        host.terminalScrollOverlay(),
                        host.productBootstrapTitle(),
                        host.productBootstrapDetail(),
                        host.productBootstrapRetryButton(),
                        new ProductShellStateCallbacks(
                                host::nativeLoaded,
                                TerminalNativeBridge::nativeSharedShellRendererActiveBridge,
                                host::currentInstallStateInstalling,
                                host::currentInstallStateFailed,
                                host::currentReadinessState,
                                host::currentInstallState,
                                () -> host.surfaceHostBridge() != null ? host.surfaceHostBridge().currentSurfaceView() : null));
        final ProductShellStatePresenter productShellStatePresenter =
                new ProductShellStatePresenter(productShellStateHostBridge);

        final ViewModeController[] terminalViewModeControllerRef = new ViewModeController[1];
        final SurfaceWidgetController[] surfaceWidgetControllerRef = new SurfaceWidgetController[1];
        final ChromeController terminalChromeController = new ChromeController(
                ChromeFactory.createChromeHostBridge(
                        host.activity(),
                        host.rootView(),
                        host.activity().findViewById(dev.zide.terminal.R.id.debug_view_mode_button),
                        host.drawerScrim(),
                        host.drawerEdgeHotspot(),
                        host.leftSidebar(),
                        ChromeFactory.createChromeHostCallbacks(
                                host::debugViewEnabled,
                                (eventName, statusLabel) -> {
                                    if (terminalViewModeControllerRef[0] != null) {
                                        terminalViewModeControllerRef[0].showProductView(eventName, statusLabel);
                                    }
                                },
                                (eventName, statusLabel) -> {
                                    if (terminalViewModeControllerRef[0] != null) {
                                        terminalViewModeControllerRef[0].showDebugView(eventName, statusLabel);
                                    }
                                },
                                host::runPackageDoctor,
                                host::appendEvent,
                                host::imeVisible,
                                host::setImeVisible,
                                host::shellInputView,
                                host::assistCtrlButton,
                                host::assistAltButton,
                                host::sendDirectText,
                                host::updateStatus)));

        final ViewModeController terminalViewModeController = UiFactory.createViewModeController(
                host.productView(),
                host.debugView(),
                host.terminalScrollOverlay(),
                host.productSurfaceContainer(),
                new ViewModeCallbacks(
                        host::debugViewEnabled,
                        host::setDebugViewEnabled,
                        host::appendEvent,
                        host::updateStatus,
                        terminalChromeController::closeSidebar,
                        host::notifyVisibleViewport,
                        host::refreshProductScrollOverlay,
                        host::refreshUserlandSession));
        terminalViewModeControllerRef[0] = terminalViewModeController;

        final SurfaceWidgetAssembly.Result surfaceWidgetAssembly = SurfaceWidgetAssembly.assemble(
                host.selectionController(),
                host.terminalGestureStateController(),
                new SurfaceWidgetAssemblyCallbacks(
                        host::handler,
                        host::productSurfaceContainer,
                        host::nativeLoaded,
                        host::debugViewEnabled,
                        host::imeVisible,
                        host::shouldRunProductFrameLoop,
                        host::refreshProductScrollOverlay,
                        host::appendEvent,
                        host::updateStatus,
                        host::callNative,
                        host::callNativeWithSurfaceState,
                        host::nativeOnSurfaceAvailableBridge,
                        host::nativeOnSurfaceDestroyedBridge,
                        host::nativeOnSurfaceRedrawNeededBridge,
                        host::nativeOnVisibleViewportBridge,
                        host::currentSurfaceStateSnapshot,
                        host::handleProductShellStateEvent,
                        nextSurfaceView -> installSurfaceGestureHost(nextSurfaceView, surfaceWidgetControllerRef),
                        (nextSurfaceView, callback) -> {
                            if (callback != null) {
                                nextSurfaceView.getHolder().addCallback(callback);
                            }
                        },
                        () -> surfaceWidgetControllerRef[0],
                        host::nativeSetShellScrollbackOffset,
                        host::nativeFollowShellLiveBottom,
                        host::productViewportHeightPx,
                        host::reevaluateProductFrameLoop));
        surfaceWidgetControllerRef[0] = surfaceWidgetAssembly.surfaceWidgetController;
        host.terminalScrollOverlay().setHost(surfaceWidgetAssembly.surfaceWidgetController);

        return new Result(
                productShellStateHostBridge,
                productShellStatePresenter,
                terminalChromeController,
                terminalViewModeController,
                surfaceWidgetAssembly.surfaceHostBridge,
                surfaceWidgetAssembly.surfaceHostController,
                surfaceWidgetAssembly.surfaceWidgetController);
    }

    private static void installSurfaceGestureHost(
            SurfaceView surfaceView,
            SurfaceWidgetController[] surfaceWidgetControllerRef) {
        if (surfaceWidgetControllerRef[0] == null) {
            return;
        }
        final ProductGestureController productGestureController =
                new ProductGestureController(surfaceView, surfaceWidgetControllerRef[0]);
        productGestureController.install();
    }
}
