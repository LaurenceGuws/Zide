package uk.laurencegouws.terminal.host.ui;

import android.app.Activity;
import android.view.SurfaceView;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;
import uk.laurencegouws.terminal.gesture.GestureController;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetAssembly;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetAssemblyCallbacks;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetController;
import uk.laurencegouws.terminal.host.userland.ShellStateBridge;
import uk.laurencegouws.terminal.host.userland.ShellStateCallbacks;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.scroll.ScrollOverlayView;
import uk.laurencegouws.terminal.selection.SelectionController;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Owns product widget/chrome/view-mode/surface host assembly for activity wiring. */
public final class WidgetAssembly {
    /** Activity callbacks required to assemble widget host controllers. */
    public interface Host {
        Activity activity();

        android.os.Handler handler();

        boolean debugViewEnabled();

        void setDebugViewEnabled(boolean enabled);

        boolean imeVisible();

        void setImeVisible(boolean visible);

        View rootView();

        View productView();

        View debugView();

        View productReadinessBlocker();

        View drawerScrim();

        View drawerEdgeHotspot();

        View leftSidebar();

        FrameLayout productSurfaceContainer();

        ScrollOverlayView terminalScrollOverlay();

        TextView productReadinessTitle();

        TextView productReadinessDetail();

        Button productReadinessRetryButton();

        Button assistCtrlButton();

        Button assistAltButton();

        ShellInputView shellInputView();

        SelectionController selectionController();

        GestureStateController GestureStateController();

        UserlandReadinessState currentReadinessState();

        UserlandInstallState currentInstallState();

        boolean shouldRunProductFrameLoop();

        void refreshProductScrollOverlay();

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void callNative(String event, long seq);

        void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state);

        AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();

        void handleProductShellStateEvent(String statusLabel);

        int productViewportHeightPx();

        void reevaluateProductFrameLoop();

        void runPackageDoctor();

        void sendDirectText(String text);

        void notifyVisibleViewport(String reason);

        void refreshUserlandSession();
    }

    /** Immutable assembled widget host result. */
    public static final class Result {
        public final ShellStateBridge productShellStateHostBridge;
        public final ShellStatePresenter ShellStatePresenter;
        public final ChromeController terminalChromeController;
        public final ViewModeController terminalViewModeController;
        public final SurfaceBridge surfaceHostBridge;
        public final SurfaceController surfaceHostController;
        public final SurfaceWidgetController terminalSurfaceWidgetController;

        private Result(
                ShellStateBridge productShellStateHostBridge,
                ShellStatePresenter ShellStatePresenter,
                ChromeController terminalChromeController,
                ViewModeController terminalViewModeController,
                SurfaceBridge surfaceHostBridge,
                SurfaceController surfaceHostController,
                SurfaceWidgetController terminalSurfaceWidgetController) {
            this.productShellStateHostBridge = productShellStateHostBridge;
            this.ShellStatePresenter = ShellStatePresenter;
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
        final ViewModeController[] terminalViewModeControllerRef = new ViewModeController[1];
        final SurfaceWidgetController[] surfaceWidgetControllerRef = new SurfaceWidgetController[1];
        final ChromeController terminalChromeController = new ChromeController(
                ChromeFactory.createChromeHostBridge(
                        host.activity(),
                        host.rootView(),
                        host.activity().findViewById(uk.laurencegouws.terminal.R.id.debug_view_mode_button),
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
                host.GestureStateController(),
                new SurfaceWidgetAssemblyCallbacks(
                        host.handler(),
                        host.productSurfaceContainer(),
                        host::debugViewEnabled,
                        host::imeVisible,
                        host::shouldRunProductFrameLoop,
                        host::refreshProductScrollOverlay,
                        host::appendEvent,
                        host::updateStatus,
                        host::callNative,
                        host::callNativeWithSurfaceState,
                        host::currentSurfaceStateSnapshot,
                        host::handleProductShellStateEvent,
                        nextSurfaceView -> installSurfaceGestureHost(nextSurfaceView, surfaceWidgetControllerRef),
                        (nextSurfaceView, callback) -> {
                            if (callback != null) {
                                nextSurfaceView.getHolder().addCallback(callback);
                            }
                        },
                        () -> surfaceWidgetControllerRef[0],
                        host::productViewportHeightPx,
                        host::reevaluateProductFrameLoop));
        surfaceWidgetControllerRef[0] = surfaceWidgetAssembly.surfaceWidgetController;
        host.terminalScrollOverlay().setHost(surfaceWidgetAssembly.surfaceWidgetController);

        final ShellStateBridge productShellStateHostBridge =
                UiFactory.createProductShellStateHostBridge(
                        host.productReadinessBlocker(),
                        host.terminalScrollOverlay(),
                        host.productReadinessTitle(),
                        host.productReadinessDetail(),
                        host.productReadinessRetryButton(),
                        new ShellStateCallbacks(
                                host::currentReadinessState,
                                host::currentInstallState,
                                surfaceWidgetAssembly.surfaceHostBridge::currentSurfaceView));
        final ShellStatePresenter ShellStatePresenter =
                new ShellStatePresenter(productShellStateHostBridge);

        return new Result(
                productShellStateHostBridge,
                ShellStatePresenter,
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
        final GestureController productGestureController =
                new GestureController(surfaceView, surfaceWidgetControllerRef[0]);
        productGestureController.install();
    }
}
