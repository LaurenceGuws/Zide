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

import java.util.Objects;

/**
 * Owns product widget/chrome/view-mode/surface host assembly for activity wiring.
 *
 * <p>IME on {@link Host} is not primitive getters/setters: use
 * {@link Host#surfaceWidgetHostImeVisibility()} for surface reads and
 * {@link Host#chromeImePolicyInput()} for chrome factory wiring.</p>
 */
public final class WidgetAssembly {
    /** Harness callbacks required to assemble widget host controllers. */
    public interface Host {
        /**
         * Terminal widget slot for this assembly (must be {@link TerminalWidgetSlotId#PRIMARY}
         * for current product wiring). Chrome construction under this host remains
         * slot-agnostic until per-slot chrome policy exists.
         */
        TerminalWidgetSlotId terminalWidgetSlot();

        /**
         * Context for chrome and view construction (typically the hosting {@code Activity}).
         */
        Context harnessContext();

        android.os.Handler handler();

        /**
         * IME visibility read for surface/native viewport assembly (non-chrome). Distinct from
         * {@link #chromeImePolicyInput()}.
         */
        SurfaceWidgetHostImeVisibility surfaceWidgetHostImeVisibility();

        /** Harness-owned chrome IME policy input for {@link ChromeFactory} (B15 seam; B14 method names). */
        ChromeImePolicyInput chromeImePolicyInput();

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
     * Immutable assembled widget host result: harness controllers vs surface join slice.
     * {@link TerminalWidgetCompositionAssembly#compose} takes only {@link WidgetSurfaceHostJoin};
     * shell/chrome/view-mode refs live on {@link #harnessHost} — this type is not the
     * terminal-instance factory on its own.
     */
    public static final class Result {
        public final WidgetHarnessHostControllers harnessHost;
        public final WidgetSurfaceHostJoin surfaceJoin;

        private Result(WidgetHarnessHostControllers harnessHost, WidgetSurfaceHostJoin surfaceJoin) {
            this.harnessHost = harnessHost;
            this.surfaceJoin = surfaceJoin;
        }
    }

    private WidgetAssembly() {
    }

    /**
     * Assembles widget harness + surface join using the activity’s single startup selection context
     * (declared catalog + selected slot + policy) so selection is not re-resolved inside assembly.
     */
    public static Result assemble(final Host host, final AppShellTerminalHostSelectionContext selectionContext) {
        Objects.requireNonNull(host, "host");
        Objects.requireNonNull(selectionContext, "selectionContext");
        if (host.terminalWidgetSlot() != selectionContext.hostDeclaredTerminalWidgetSlot().terminalWidgetSlot()) {
            throw new IllegalStateException(
                    "Widget host slot must match startup AppShellTerminalHostSelectionContext host-declared value");
        }
        if (host.terminalWidgetSlot() != selectionContext.selectedProductTerminalSlotForAppShell()) {
            throw new IllegalStateException(
                    "Widget host declared slot must match startup AppShellTerminalHostSelectionContext selected slot");
        }
        final AppShellTerminalSelectionPolicy appShellTerminalSelectionPolicy =
                selectionContext.appShellTerminalSelectionPolicy();
        final AppShellNavigation appShellNavigation =
                AppShellNavigation.forProductTerminalSlot(
                        selectionContext.selectedProductTerminalSlotForAppShell());
        final AppShellTerminalViewPolicy appShellTerminalViewPolicy =
                new AppShellTerminalViewPolicy(appShellNavigation);
        final SurfaceWidgetControllerRef surfaceWidgetControllerRef = new SurfaceWidgetControllerRef();
        final ChromeController terminalChromeController = createChromeController(
                host,
                appShellTerminalViewPolicy);

        final ViewModeController terminalViewModeController =
                createViewModeController(host, appShellTerminalViewPolicy);

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
                new WidgetHarnessHostControllers(
                        appShellTerminalSelectionPolicy,
                        appShellTerminalViewPolicy,
                        productShellStateHostBridge,
                        shellStatePresenter,
                        terminalChromeController,
                        terminalViewModeController),
                new WidgetSurfaceHostJoin(
                        surfaceWidgetAssembly.surfaceHostBridge,
                        surfaceWidgetAssembly.surfaceHostController,
                        surfaceWidgetAssembly.surfaceWidgetController));
    }

    private static ChromeController createChromeController(
            Host host,
            AppShellTerminalViewPolicy appShellTerminalViewPolicy) {
        return new ChromeController(
                ChromeFactory.createChromeHostBridge(
                        host.harnessContext(),
                        host.rootView(),
                        host.drawerScrim(),
                        host.drawerEdgeHotspot(),
                        host.drawerSidebar(),
                        appShellTerminalViewPolicy,
                        ChromeFactory.createChromeHostCallbacks(
                                host::requestPackageDiagnostics,
                                host::appendEvent,
                                host.chromeImePolicyInput(),
                                host::shellInputView,
                                host::assistCtrlButton,
                                host::assistAltButton,
                                host::sendDirectText,
                                host::updateStatus)));
    }

    private static ViewModeController createViewModeController(
            Host host, AppShellTerminalViewPolicy appShellTerminalViewPolicy) {
        return UiFactory.createViewModeController(
                host.productView(),
                host.productSurfaceContainer(),
                appShellTerminalViewPolicy,
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
                host.surfaceWidgetHostImeVisibility(),
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
