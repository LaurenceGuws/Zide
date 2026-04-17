package uk.laurencegouws.terminal.host.ui;

import android.content.Context;
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
import uk.laurencegouws.terminal.host.userland.ShellPresentationHostInputs;
import uk.laurencegouws.terminal.host.userland.ShellStateBridge;
import uk.laurencegouws.terminal.host.userland.ShellStateCallbacks;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.scroll.ScrollOverlayView;
import uk.laurencegouws.terminal.selection.SelectionController;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;

/** Owns product widget/chrome/view-mode/surface host assembly for activity wiring. */
public final class WidgetAssembly {
    /** Harness callbacks required to assemble widget host controllers. */
    public interface Host {
        /**
         * Context for chrome and view construction (typically the hosting {@code Activity}).
         */
        Context harnessContext();

        android.os.Handler handler();

        boolean imeVisible();

        void setImeVisible(boolean visible);

        View rootView();

        View productView();

        View productReadinessBlocker();

        View drawerScrim();

        View drawerEdgeHotspot();

        /** Chrome drawer panel; host-owned, not widget policy. */
        View drawerSidebar();

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

        /**
         * Readiness/install suppliers for shell-blocker presentation; userland types stay behind
         * {@link ShellPresentationHostInputs} so this Host seam does not import userland value classes.
         */
        ShellPresentationHostInputs shellPresentationHostInputs();

        boolean shouldRunFrameLoop();

        void refreshScrollOverlay();

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void callNative(String event, long seq);

        void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state);

        AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();

        void handleShellStateEvent();

        int productViewportHeightPx();

        void reevaluateFrameLoop();

        /** Host routes diagnostics; widget assembly does not own package policy. */
        void requestPackageDiagnostics();

        void sendDirectText(String text);

        void notifyVisibleViewport(String reason);
    }

    /**
     * Immutable assembled widget host result (chrome, shell presentation bridge, surface hosts).
     * Harness joins this with {@link InteractionAssembly.Result} in
     * {@link TerminalWidgetCompositionAssembly} to build {@link TerminalWidgetInstance}; this type
     * is not the terminal-instance factory on its own.
     */
    public static final class Result {
        public final AppShellNavigation appShellNavigation;
        public final ShellStateBridge productShellStateHostBridge;
        public final ShellStatePresenter ShellStatePresenter;
        public final ChromeController terminalChromeController;
        public final ViewModeController terminalViewModeController;
        public final SurfaceBridge surfaceHostBridge;
        public final SurfaceController surfaceHostController;
        public final SurfaceWidgetController terminalSurfaceWidgetController;

        private Result(
                AppShellNavigation appShellNavigation,
                ShellStateBridge productShellStateHostBridge,
                ShellStatePresenter ShellStatePresenter,
                ChromeController terminalChromeController,
                ViewModeController terminalViewModeController,
                SurfaceBridge surfaceHostBridge,
                SurfaceController surfaceHostController,
                SurfaceWidgetController terminalSurfaceWidgetController) {
            this.appShellNavigation = appShellNavigation;
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
        final AppShellNavigation appShellNavigation = new AppShellNavigation();
        final SurfaceWidgetControllerRef surfaceWidgetControllerRef = new SurfaceWidgetControllerRef();
        final ChromeController terminalChromeController = createChromeController(
                host,
                appShellNavigation);

        final ViewModeController terminalViewModeController =
                createViewModeController(host, appShellNavigation);

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
                appShellNavigation,
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
            AppShellNavigation appShellNavigation) {
        return new ChromeController(
                ChromeFactory.createChromeHostBridge(
                        host.harnessContext(),
                        host.rootView(),
                        host.drawerScrim(),
                        host.drawerEdgeHotspot(),
                        host.drawerSidebar(),
                        appShellNavigation,
                        ChromeFactory.createChromeHostCallbacks(
                                host::requestPackageDiagnostics,
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
            Host host, AppShellNavigation appShellNavigation) {
        return UiFactory.createViewModeController(
                host.productView(),
                host.productSurfaceContainer(),
                appShellNavigation,
                new ViewModeCallbacks(
                        host::appendEvent,
                        host::updateStatus,
                        host::notifyVisibleViewport,
                        host::refreshScrollOverlay));
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
                        host.shellPresentationHostInputs().readinessState(),
                        host.shellPresentationHostInputs().installState(),
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

    private static SurfaceWidgetAssemblyCallbacks createSurfaceWidgetAssemblyCallbacks(
            Host host,
            SurfaceWidgetControllerRef surfaceWidgetControllerRef) {
        return new SurfaceWidgetAssemblyCallbacks(
                host.handler(),
                host.productSurfaceContainer(),
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

    private static final class SurfaceWidgetControllerRef {
        private SurfaceWidgetController value;
    }
}
