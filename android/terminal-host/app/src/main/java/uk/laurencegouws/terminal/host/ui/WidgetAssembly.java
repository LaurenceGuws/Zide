package uk.laurencegouws.terminal.host.ui;

import android.app.Activity;
import android.view.SurfaceHolder;
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

        boolean shouldRunFrameLoop();

        void refreshScrollOverlay();

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void callNative(String event, long seq);

        void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state);

        AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();

        void handleShellStateEvent(String statusLabel);

        int productViewportHeightPx();

        void reevaluateFrameLoop();

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
        final ViewModeControllerRef terminalViewModeControllerRef = new ViewModeControllerRef();
        final SurfaceWidgetControllerRef surfaceWidgetControllerRef = new SurfaceWidgetControllerRef();
        final ChromeController terminalChromeController = createChromeController(
                host,
                terminalViewModeControllerRef);

        final ViewModeController terminalViewModeController = createViewModeController(
                host,
                terminalChromeController);
        terminalViewModeControllerRef.value = terminalViewModeController;

        final SurfaceWidgetAssembly.Result surfaceWidgetAssembly = assembleSurfaceWidget(
                host,
                surfaceWidgetControllerRef);
        surfaceWidgetControllerRef.value = surfaceWidgetAssembly.surfaceWidgetController;
        host.terminalScrollOverlay().setHost(surfaceWidgetAssembly.surfaceWidgetController);

        final ShellStateBridge productShellStateHostBridge = createShellStateHostBridge(
                host,
                surfaceWidgetAssembly);
        final ShellStatePresenter shellStatePresenter =
                new ShellStatePresenter(productShellStateHostBridge);

        return new Result(
                productShellStateHostBridge,
                shellStatePresenter,
                terminalChromeController,
                terminalViewModeController,
                surfaceWidgetAssembly.surfaceHostBridge,
                surfaceWidgetAssembly.surfaceHostController,
                surfaceWidgetAssembly.surfaceWidgetController);
    }

    private static ChromeController createChromeController(
            Host host,
            ViewModeControllerRef terminalViewModeControllerRef) {
        return new ChromeController(
                ChromeFactory.createChromeHostBridge(
                        host.activity(),
                        host.rootView(),
                        host.activity().findViewById(uk.laurencegouws.terminal.R.id.debug_view_mode_button),
                        host.drawerScrim(),
                        host.drawerEdgeHotspot(),
                        host.leftSidebar(),
                        ChromeFactory.createChromeHostCallbacks(
                                host::debugViewEnabled,
                                (eventName, statusLabel) -> showViewIfReady(
                                        terminalViewModeControllerRef,
                                        eventName,
                                        statusLabel),
                                (eventName, statusLabel) -> showDebugViewIfReady(
                                        terminalViewModeControllerRef,
                                        eventName,
                                        statusLabel),
                                host::runPackageDoctor,
                                host::appendEvent,
                                host::imeVisible,
                                host::setImeVisible,
                                host::shellInputView,
                                host::assistCtrlButton,
                                host::assistAltButton,
                                host::sendDirectText,
                                host::updateStatus)));
    }

    private static ViewModeController createViewModeController(
            Host host,
            ChromeController terminalChromeController) {
        return UiFactory.createViewModeController(
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
                        host::refreshScrollOverlay,
                        host::refreshUserlandSession));
    }

    private static SurfaceWidgetAssembly.Result assembleSurfaceWidget(
            Host host,
            SurfaceWidgetControllerRef surfaceWidgetControllerRef) {
        return SurfaceWidgetAssembly.assemble(
                host.selectionController(),
                host.GestureStateController(),
                createSurfaceWidgetAssemblyCallbacks(host, surfaceWidgetControllerRef));
    }

    private static ShellStateBridge createShellStateHostBridge(
            Host host,
            SurfaceWidgetAssembly.Result surfaceWidgetAssembly) {
        return UiFactory.createShellStateHostBridge(
                host.productReadinessBlocker(),
                host.terminalScrollOverlay(),
                host.productReadinessTitle(),
                host.productReadinessDetail(),
                host.productReadinessRetryButton(),
                new ShellStateCallbacks(
                        host::currentReadinessState,
                        host::currentInstallState,
                        surfaceWidgetAssembly.surfaceHostBridge::currentSurfaceView));
    }

    private static void installSurfaceGestureHost(
            SurfaceView surfaceView,
            SurfaceWidgetControllerRef surfaceWidgetControllerRef) {
        if (surfaceWidgetControllerRef.value == null) {
            return;
        }
        final GestureController productGestureController =
                new GestureController(surfaceView, surfaceWidgetControllerRef.value);
        productGestureController.install();
    }

    private static void showViewIfReady(
            ViewModeControllerRef terminalViewModeControllerRef,
            String eventName,
            String statusLabel) {
        final ViewModeController viewModeController = terminalViewModeControllerRef.value;
        if (viewModeController != null) {
            viewModeController.showView(eventName, statusLabel);
        }
    }

    private static void showDebugViewIfReady(
            ViewModeControllerRef terminalViewModeControllerRef,
            String eventName,
            String statusLabel) {
        final ViewModeController viewModeController = terminalViewModeControllerRef.value;
        if (viewModeController != null) {
            viewModeController.showDebugView(eventName, statusLabel);
        }
    }

    private static SurfaceWidgetAssemblyCallbacks createSurfaceWidgetAssemblyCallbacks(
            Host host,
            SurfaceWidgetControllerRef surfaceWidgetControllerRef) {
        return new SurfaceWidgetAssemblyCallbacks(
                host.handler(),
                host.productSurfaceContainer(),
                host::debugViewEnabled,
                host::imeVisible,
                host::shouldRunFrameLoop,
                host::refreshScrollOverlay,
                host::appendEvent,
                host::updateStatus,
                host::callNative,
                host::callNativeWithSurfaceState,
                host::currentSurfaceStateSnapshot,
                host::handleShellStateEvent,
                nextSurfaceView -> installSurfaceGestureHost(nextSurfaceView, surfaceWidgetControllerRef),
                WidgetAssembly::addSurfaceHolderCallbackIfPresent,
                () -> surfaceWidgetControllerRef.value,
                host::productViewportHeightPx,
                host::reevaluateFrameLoop);
    }

    private static void addSurfaceHolderCallbackIfPresent(
            SurfaceView nextSurfaceView,
            SurfaceHolder.Callback2 callback) {
        if (callback != null) {
            nextSurfaceView.getHolder().addCallback(callback);
        }
    }

    private static final class ViewModeControllerRef {
        private ViewModeController value;
    }

    private static final class SurfaceWidgetControllerRef {
        private SurfaceWidgetController value;
    }
}
