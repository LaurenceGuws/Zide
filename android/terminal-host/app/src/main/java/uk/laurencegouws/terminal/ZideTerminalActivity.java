package uk.laurencegouws.terminal;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;
import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;
import uk.laurencegouws.terminal.debug.TerminalStatusController;
import uk.laurencegouws.terminal.debug.TerminalSurfaceStateSnapshotReader;
import uk.laurencegouws.terminal.gesture.TerminalGestureStateController;
import uk.laurencegouws.terminal.host.lifecycle.LifecycleController;
import uk.laurencegouws.terminal.host.lifecycle.LifecycleCallbacks;
import uk.laurencegouws.terminal.host.ui.ChromeController;
import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.input.InputAssembly;
import uk.laurencegouws.terminal.host.input.InputCallbacks;
import uk.laurencegouws.terminal.host.interaction.InteractionAssembly;
import uk.laurencegouws.terminal.host.interaction.InteractionCallbacks;
import uk.laurencegouws.terminal.host.runtime.ProductRuntimeAssembly;
import uk.laurencegouws.terminal.host.runtime.ProductRuntimeAssemblyCallbacks;
import uk.laurencegouws.terminal.host.runtime.ProductRuntimeController;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssetsController;
import uk.laurencegouws.terminal.host.session.SessionAssembly;
import uk.laurencegouws.terminal.host.session.SessionAssemblyCallbacks;
import uk.laurencegouws.terminal.host.status.StatusViewAssembly;
import uk.laurencegouws.terminal.host.status.StatusViewCallbacks;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.host.surface.SurfaceWidgetController;
import uk.laurencegouws.terminal.host.ui.ViewModeController;
import uk.laurencegouws.terminal.host.ui.UiStartupAssembly;
import uk.laurencegouws.terminal.host.ui.UiStartupCallbacks;
import uk.laurencegouws.terminal.host.ui.ViewportController;
import uk.laurencegouws.terminal.host.ui.WidgetAssembly;
import uk.laurencegouws.terminal.host.ui.WidgetCallbacks;
import uk.laurencegouws.terminal.host.userland.WorkflowAssembly;
import uk.laurencegouws.terminal.host.userland.WorkflowAssemblyCallbacks;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.input.TerminalHardwareKeyboardController;
import uk.laurencegouws.terminal.input.TerminalImeFocusRecoveryController;
import uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView;
import uk.laurencegouws.terminal.selection.TerminalSelectionController;
import uk.laurencegouws.terminal.userland.ProductShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandRelease;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;
import uk.laurencegouws.terminal.userland.UserlandWorkflowController;

/**
 * Android activity entrypoint for the terminal-host product surface.
 *
 * <p>
 * The activity should remain wiring-oriented: inflate views, construct
 * controllers, forward
 * lifecycle/input/surface callbacks, and expose the JNI bridge. Terminal truth
 * stays in Zig, while
 * Android-specific policy belongs in the package controllers below this
 * activity.
 */
public final class ZideTerminalActivity extends Activity
        implements ShellInputView.Host {
    private static final String EXTRA_DEBUG_RECREATE_SURFACE_ONCE = "debug_recreate_surface_once";
    private static final String EXTRA_DEBUG_RESIZE_SURFACE_ONCE = "debug_resize_surface_once";
    private static final String EXTRA_DEBUG_START_SHELL_ONCE = "debug_start_shell_once";
    private static final boolean nativeLoaded = TerminalNativeBridge.nativeLoaded();
    private static final String nativeLoadError = TerminalNativeBridge.nativeLoadError();

    private final Handler handler = new Handler(Looper.getMainLooper());
    private TextView packageStatusText;
    private TextView productBootstrapTitle;
    private TextView productBootstrapDetail;
    private Button productBootstrapRetryButton;
    private Button productBootstrapDebugButton;
    private View rootView;
    private View productView;
    private View debugView;
    private View productBootstrapBlocker;
    private View drawerScrim;
    private View drawerEdgeHotspot;
    private View leftSidebar;
    private FrameLayout productSurfaceContainer;
    private TerminalScrollOverlayView terminalScrollOverlay;
    private Button assistCtrlButton;
    private Button assistAltButton;
    private ShellInputView shellInputView;
    private TerminalHardwareKeyboardController terminalHardwareKeyboardController;
    private TerminalImeFocusRecoveryController terminalImeFocusRecoveryController;
    private TerminalSelectionController selectionController;
    private TerminalGestureStateController terminalGestureStateController;
    private boolean debugViewEnabled = false;
    private boolean imeVisible = false;
    private UserlandRelease userlandRelease;
    private UserlandWorkflowController userlandWorkflowController;
    private UserlandSessionCoordinator userlandSessionCoordinator;
    private FrameLoopController productFrameLoopController;
    private ProductShellStatePresenter productShellStatePresenter;
    private SurfaceController surfaceHostController;
    private SurfaceBridge surfaceHostBridge;
    private ChromeController terminalChromeController;
    private ViewModeController terminalViewModeController;
    private RuntimeAssetsController terminalRuntimeAssetsController;
    private ViewportController terminalViewportController;
    private TerminalStatusController terminalStatusController;
    private TerminalSurfaceStateSnapshotReader terminalSurfaceStateSnapshotReader;
    private SurfaceWidgetController terminalSurfaceWidgetController;
    private ProductRuntimeController terminalProductRuntimeController;
    private LifecycleController terminalActivityLifecycleController;
    private UserlandInstallState currentInstallState = UserlandInstallState.idle();
    private UserlandReadinessState currentReadinessState;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        runOnCreateStartupSequence();
    }

    private void runOnCreateStartupSequence() {
        initializeStatusAndViewControllers();
        assembleInteractionControllers();
        assembleUserlandWorkflowControllers();
        assembleSessionControllers();
        assembleWidgetHostControllers();
        assembleProductRuntimeController();
        assembleActivityLifecycleController();
        currentReadinessState = userlandSessionCoordinator.loadReadinessState();
        installInputControllers();
        bindAndStartUiControllers();
        finishOnCreateLifecycle();
    }

    @Override
    protected void onStart() {
        super.onStart();
        terminalActivityLifecycleController.onStart();
    }

    @Override
    protected void onResume() {
        super.onResume();
        terminalActivityLifecycleController.onResume(
                getIntent().getBooleanExtra(EXTRA_DEBUG_RECREATE_SURFACE_ONCE, false),
                getIntent().getBooleanExtra(EXTRA_DEBUG_RESIZE_SURFACE_ONCE, false),
                getIntent().getBooleanExtra(EXTRA_DEBUG_START_SHELL_ONCE, false));
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        appendEvent("activity.on.new.intent");
    }

    @Override
    protected void onPause() {
        terminalActivityLifecycleController.onPause();
        super.onPause();
    }

    @Override
    protected void onStop() {
        terminalActivityLifecycleController.onStop();
        super.onStop();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        terminalActivityLifecycleController.onWindowFocusChanged(hasFocus);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (terminalHardwareKeyboardController != null
                && terminalHardwareKeyboardController.handleDispatchKeyEvent(event)) {
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    private void initializeStatusAndViewControllers() {
        final StatusViewAssembly.Result result = StatusViewAssembly.assemble(
                createStatusViewCallbacks());
        packageStatusText = result.packageStatusText;
        productBootstrapTitle = result.productBootstrapTitle;
        productBootstrapDetail = result.productBootstrapDetail;
        productBootstrapRetryButton = result.productBootstrapRetryButton;
        productBootstrapDebugButton = result.productBootstrapDebugButton;
        rootView = result.rootView;
        productView = result.productView;
        debugView = result.debugView;
        productBootstrapBlocker = result.productBootstrapBlocker;
        drawerScrim = result.drawerScrim;
        drawerEdgeHotspot = result.drawerEdgeHotspot;
        leftSidebar = result.leftSidebar;
        productSurfaceContainer = result.productSurfaceContainer;
        terminalScrollOverlay = result.terminalScrollOverlay;
        assistCtrlButton = result.assistCtrlButton;
        assistAltButton = result.assistAltButton;
        terminalSurfaceStateSnapshotReader = result.terminalSurfaceStateSnapshotReader;
        terminalStatusController = result.terminalStatusController;
        terminalViewportController = result.terminalViewportController;
    }

    private void assembleInteractionControllers() {
        final InteractionAssembly.Result result = InteractionAssembly.assemble(
                createInteractionCallbacks());
        selectionController = result.selectionController;
        terminalGestureStateController = result.terminalGestureStateController;
    }

    private void installInputControllers() {
        final InputAssembly.Result result = InputAssembly.assemble(
                createInputCallbacks());
        shellInputView = result.shellInputView;
        terminalHardwareKeyboardController = result.hardwareKeyboardController;
        terminalImeFocusRecoveryController = result.imeFocusRecoveryController;
    }

    private InteractionCallbacks createInteractionCallbacks() {
        return new InteractionCallbacks(
                InteractionCallbacks.InteractionHostCallbacks.of(
                        () -> this,
                        () -> handler,
                        () -> productSurfaceContainer,
                        this::productViewportWidthPx,
                        this::productViewportHeightPx),
                InteractionCallbacks.InteractionRuntimeCallbacks.of(
                        () -> nativeLoaded,
                        this::stopScrollbackFlingIfReady,
                        this::refreshProductScrollOverlayIfReady,
                        this::reevaluateProductFrameLoopIfReady,
                        this::appendEvent));
    }

    private InputCallbacks createInputCallbacks() {
        return new InputCallbacks(
                InputCallbacks.InputHostCallbacks.of(
                        () -> this,
                        () -> rootView,
                        () -> this,
                        () -> getSystemService(InputMethodManager.class)),
                InputCallbacks.InputRuntimeCallbacks.of(
                        () -> imeVisible,
                        visible -> imeVisible = visible,
                        () -> nativeLoaded,
                        TerminalNativeBridge::nativeFollowSessionLiveBottomBridge,
                        this::refreshProductScrollOverlayIfReady,
                        this::updateStatus,
                        this::appendEvent));
    }

    private void assembleWidgetHostControllers() {
        final WidgetAssembly.Result result = WidgetAssembly.assemble(
                createWidgetCallbacks());
        productShellStatePresenter = result.productShellStatePresenter;
        terminalChromeController = result.terminalChromeController;
        terminalViewModeController = result.terminalViewModeController;
        surfaceHostBridge = result.surfaceHostBridge;
        surfaceHostController = result.surfaceHostController;
        terminalSurfaceWidgetController = result.terminalSurfaceWidgetController;
    }

    private void assembleSessionControllers() {
        final SessionAssembly.Result result = SessionAssembly.assemble(
                createSessionAssemblyCallbacks());
        userlandSessionCoordinator = result.userlandSessionCoordinator;
        productFrameLoopController = result.frameLoopController;
    }

    private void assembleUserlandWorkflowControllers() {
        final WorkflowAssembly.Result result = WorkflowAssembly.assemble(
                createWorkflowAssemblyCallbacks());
        terminalRuntimeAssetsController = result.runtimeAssetsController;
        userlandWorkflowController = result.userlandWorkflowController;
    }

    private void assembleProductRuntimeController() {
        terminalProductRuntimeController = ProductRuntimeAssembly.assemble(
                createProductRuntimeAssemblyCallbacks());
    }

    private WidgetCallbacks createWidgetCallbacks() {
        return new WidgetCallbacks(
                WidgetCallbacks.WidgetHostCallbacks.of(
                        () -> this,
                        () -> handler,
                        () -> nativeLoaded,
                        () -> debugViewEnabled,
                        enabled -> debugViewEnabled = enabled,
                        () -> imeVisible,
                        visible -> imeVisible = visible),
                WidgetCallbacks.WidgetViewCallbacks.of(
                        () -> rootView,
                        () -> productView,
                        () -> debugView,
                        () -> productBootstrapBlocker,
                        () -> drawerScrim,
                        () -> drawerEdgeHotspot,
                        () -> leftSidebar,
                        () -> productSurfaceContainer,
                        () -> terminalScrollOverlay,
                        () -> productBootstrapTitle,
                        () -> productBootstrapDetail,
                        () -> productBootstrapRetryButton,
                        () -> assistCtrlButton,
                        () -> assistAltButton,
                        () -> shellInputView,
                        () -> selectionController,
                        () -> terminalGestureStateController,
                        () -> surfaceHostBridge),
                WidgetCallbacks.WidgetRuntimeCallbacks.of(
                        () -> currentInstallState.isInstalling(),
                        () -> currentInstallState.isFailed(),
                        () -> currentReadinessState,
                        () -> currentInstallState,
                        this::shouldRunProductFrameLoop,
                        this::refreshProductScrollOverlayIfReady,
                        this::appendEvent,
                        this::updateStatus,
                        TerminalNativeBridge::nativeSetSessionScrollbackOffsetBridge,
                        TerminalNativeBridge::nativeFollowSessionLiveBottomBridge,
                        this::productViewportHeightPx,
                        this::reevaluateProductFrameLoopIfReady,
                        this::runPackageDoctor,
                        this::sendDirectText,
                        this::notifyVisibleViewportIfReady,
                        this::refreshUserlandSessionIfReady),
                WidgetCallbacks.WidgetSurfaceLifecycleCallbacks.of(
                        this::callNative,
                        this::callNativeWithSurfaceState,
                        (holder, width, height) -> TerminalNativeBridge.nativeOnSurfaceAvailableBridge(
                                holder.getSurface(),
                                width,
                                height),
                        TerminalNativeBridge::nativeOnSurfaceDestroyedBridge,
                        TerminalNativeBridge::nativeOnSurfaceRedrawNeededBridge,
                        TerminalNativeBridge::nativeOnVisibleViewportBridge,
                        this::currentSurfaceStateSnapshot,
                        this::handleProductShellStateEventIfReady));
    }

    private SessionAssemblyCallbacks createSessionAssemblyCallbacks() {
        return new SessionAssemblyCallbacks(
                SessionAssemblyCallbacks.SessionHostCallbacks.of(
                        () -> this,
                        () -> userlandRelease,
                        () -> handler,
                        this::appendEvent,
                        this::updateStatus),
                SessionAssemblyCallbacks.SessionRuntimeCallbacks.of(
                        () -> nativeLoaded,
                        readinessState -> currentReadinessState = readinessState,
                        this::refreshProductShellStateIfReady,
                        this::refreshDebugStatusSurfaceIfReady,
                        this::shouldRunProductFrameLoop,
                        this::tickProductFrameAndRefreshScrollOverlay,
                        SessionAssemblyCallbacks.NativeSessionCallbacks.of(
                                TerminalNativeBridge::nativeRestartSessionBridge,
                                TerminalNativeBridge::nativePollSessionBridge,
                                TerminalNativeBridge::nativeIsSessionAliveBridge)));
    }

    private ProductRuntimeAssemblyCallbacks createProductRuntimeAssemblyCallbacks() {
        return new ProductRuntimeAssemblyCallbacks(
                ProductRuntimeAssemblyCallbacks.RuntimeHostCallbacks.of(
                        () -> debugViewEnabled,
                        () -> nativeLoaded,
                        () -> currentInstallState,
                        installState -> currentInstallState = installState,
                        () -> currentReadinessState,
                        this::appendEvent,
                        this::updateStatus),
                ProductRuntimeAssemblyCallbacks.RuntimeUiCallbacks.of(
                        this::currentSurfaceViewIfReady,
                        () -> productBootstrapBlocker,
                        () -> terminalScrollOverlay,
                        () -> selectionController,
                        () -> productShellStatePresenter,
                        () -> productFrameLoopController,
                        () -> terminalStatusController,
                        () -> userlandSessionCoordinator,
                        () -> terminalGestureStateController));
    }

    private void assembleActivityLifecycleController() {
        terminalActivityLifecycleController = new LifecycleController(
                createLifecycleCallbacks());
    }

    private StatusViewCallbacks createStatusViewCallbacks() {
        return new StatusViewCallbacks(
                StatusViewCallbacks.StatusHostCallbacks.of(
                        () -> this,
                        () -> debugViewEnabled,
                        () -> nativeLoaded,
                        this::hasWindowFocus,
                        () -> imeVisible,
                        visible -> imeVisible = visible),
                StatusViewCallbacks.StatusRuntimeCallbacks.of(
                        StatusViewCallbacks.StatusSurfaceCallbacks.of(
                                () -> surfaceHostBridge,
                                this::currentSurfaceStateSnapshot,
                                this::notifyVisibleViewportIfReady),
                        StatusViewCallbacks.StatusUserlandCallbacks.of(
                                () -> currentInstallState,
                                () -> currentReadinessState)));
    }

    private LifecycleCallbacks createLifecycleCallbacks() {
        return new LifecycleCallbacks(
                LifecycleCallbacks.LifecycleHostCallbacks.of(
                        () -> nativeLoaded,
                        this::appendEvent,
                        this::updateStatus,
                        this::stopProductFrameLoopIfReady,
                        this::refreshUserlandSessionIfReady,
                        this::pauseSurfaceIfReady,
                        this::resumeSurfaceIfReady),
                LifecycleCallbacks.NativeLifecycleCallbacks.of(
                        TerminalNativeBridge::nativeOnStartBridge,
                        TerminalNativeBridge::nativeOnResumeBridge,
                        TerminalNativeBridge::nativeOnPauseBridge,
                        TerminalNativeBridge::nativeOnStopBridge,
                        TerminalNativeBridge::nativeOnWindowFocusBridge,
                        this::callNative));
    }

    private void bindAndStartUiControllers() {
        UiStartupAssembly.start(
                createUiStartupCallbacks());
    }

    private WorkflowAssemblyCallbacks createWorkflowAssemblyCallbacks() {
        return new WorkflowAssemblyCallbacks(
                WorkflowAssemblyCallbacks.WorkflowHostCallbacks.of(
                        () -> this,
                        () -> handler,
                        () -> userlandRelease,
                        release -> userlandRelease = release,
                        this::appendEvent,
                        this::updateStatus,
                        () -> packageStatusText),
                WorkflowAssemblyCallbacks.WorkflowRuntimeCallbacks.of(
                        installState -> currentInstallState = installState,
                        readinessState -> currentReadinessState = readinessState,
                        WorkflowAssemblyCallbacks.WorkflowActionCallbacks.of(
                                this::applyInstallStateIfReady,
                                this::restartSessionIfReady,
                                this::showDebugViewIfReady)));
    }

    private UiStartupCallbacks createUiStartupCallbacks() {
        return new UiStartupCallbacks(
                UiStartupCallbacks.UiHostCallbacks.of(
                        () -> terminalViewportController,
                        () -> terminalChromeController,
                        () -> productBootstrapRetryButton,
                        () -> productBootstrapDebugButton,
                        () -> currentInstallState,
                        () -> currentReadinessState,
                        () -> userlandWorkflowController,
                        () -> userlandSessionCoordinator,
                        this::showDebugViewIfReady,
                        this::appendEvent,
                        this::updateStatus),
                UiStartupCallbacks.UiRuntimeCallbacks.of(
                        () -> terminalRuntimeAssetsController,
                        () -> terminalViewModeController,
                        () -> surfaceHostController,
                        () -> terminalSurfaceWidgetController,
                        () -> productShellStatePresenter,
                        () -> productFrameLoopController,
                        () -> leftSidebar));
    }

    private void stopScrollbackFlingIfReady() {
        if (terminalProductRuntimeController != null) {
            terminalProductRuntimeController.stopScrollbackFling();
        }
    }

    private void refreshProductScrollOverlayIfReady() {
        if (terminalProductRuntimeController != null) {
            terminalProductRuntimeController.refreshProductScrollOverlay();
        }
    }

    private void reevaluateProductFrameLoopIfReady() {
        if (productFrameLoopController != null) {
            productFrameLoopController.reevaluate();
        }
    }

    private boolean shouldRunProductFrameLoop() {
        return terminalProductRuntimeController != null
                && terminalProductRuntimeController.shouldRunProductFrameLoop();
    }

    private void handleProductShellStateEventIfReady(String statusLabel) {
        if (terminalProductRuntimeController != null) {
            terminalProductRuntimeController.handleProductShellStateEvent(statusLabel);
        }
    }

    private void notifyVisibleViewportIfReady(String reason) {
        if (surfaceHostController != null) {
            surfaceHostController.notifyVisibleViewport(reason);
        }
    }

    private void refreshProductShellStateIfReady() {
        if (terminalProductRuntimeController != null) {
            terminalProductRuntimeController.refreshProductShellState();
        }
    }

    private void refreshDebugStatusSurfaceIfReady() {
        if (terminalProductRuntimeController != null) {
            terminalProductRuntimeController.refreshDebugStatusSurface();
        }
    }

    private void applyInstallStateIfReady(UserlandInstallState installState, String statusLabel) {
        if (terminalProductRuntimeController != null) {
            terminalProductRuntimeController.applyInstallState(installState, statusLabel);
        }
    }

    private void restartSessionIfReady(String eventName, String statusLabel, boolean logRefresh) {
        if (terminalProductRuntimeController != null) {
            terminalProductRuntimeController.restartSession(eventName, statusLabel, logRefresh);
        }
    }

    private void showDebugViewIfReady(String eventName, String statusLabel) {
        if (terminalViewModeController != null) {
            terminalViewModeController.showDebugView(eventName, statusLabel);
        }
    }

    private android.view.SurfaceView currentSurfaceViewIfReady() {
        return surfaceHostBridge != null ? surfaceHostBridge.currentSurfaceView() : null;
    }

    private void stopProductFrameLoopIfReady() {
        if (productFrameLoopController != null) {
            productFrameLoopController.stop();
        }
    }

    private void refreshUserlandSessionIfReady() {
        if (userlandSessionCoordinator != null) {
            userlandSessionCoordinator.refreshAndApply(false);
        }
    }

    private int tickProductFrameAndRefreshScrollOverlay() {
        final int tick = nativeLoaded ? TerminalNativeBridge.nativeTickProductFrameBridge() : 0;
        refreshProductScrollOverlayIfReady();
        return tick;
    }

    private void pauseSurfaceIfReady() {
        if (surfaceHostController != null) {
            surfaceHostController.onPause();
        }
    }

    private void resumeSurfaceIfReady(
            boolean debugRecreateSurfaceOnce,
            boolean debugResizeSurfaceOnce,
            boolean debugStartShellOnce) {
        if (surfaceHostController != null) {
            surfaceHostController.onResume(
                    debugRecreateSurfaceOnce,
                    debugResizeSurfaceOnce,
                    debugStartShellOnce);
        }
    }

    private void finishOnCreateLifecycle() {
        appendEvent("activity.on.create nativeLoaded=" + nativeLoaded);
        if (nativeLoadError != null) {
            appendEvent("native.load.error detail=" + nativeLoadError);
        }
        callNative("native.onCreate", nativeLoaded ? TerminalNativeBridge.nativeOnCreateBridge() : -1);
        updateStatus("activity.state.created");
    }

    /**
     * Product terminal viewport authority.
     *
     * <p>
     * The SurfaceView, scroll overlay, gesture math, and native grid-fit path must
     * all describe
     * the same Android-owned rectangle. Do not use the broader content frame here;
     * it can acquire
     * non-terminal children and should not become the terminal size contract by
     * accident.
     */
    private int productViewportWidthPx() {
        return terminalViewportController.productViewportWidthPx();
    }

    private int productViewportHeightPx() {
        return terminalViewportController.productViewportHeightPx();
    }

    @Override
    public void sendDirectCodepoint(int codepoint) {
        if (!nativeLoaded)
            return;
        TerminalNativeBridge.nativeSendSessionCodepointBridge(codepoint);
    }

    @Override
    public void sendDirectText(String text) {
        if (!nativeLoaded)
            return;
        for (int i = 0; i < text.length();) {
            final int cp = text.codePointAt(i);
            TerminalNativeBridge.nativeSendSessionCodepointBridge(cp);
            i += Character.charCount(cp);
        }
    }

    @Override
    public void onInputFocusChanged(boolean hasFocus) {
        if (terminalImeFocusRecoveryController != null) {
            terminalImeFocusRecoveryController.onInputFocusChanged(hasFocus);
        }
    }

    @Override
    public void onModifierLatchChanged(ShellInputView.Host.ModifierLatchState state) {
        if (terminalChromeController != null) {
            terminalChromeController.applyModifierLatchState(state);
        }
    }

    private void runPackageDoctor() {
        userlandWorkflowController.runPackageDoctor();
    }

    private void callNative(String event, long seq) {
        terminalStatusController.callNative(event, seq);
    }

    private void callNativeWithSurfaceState(
            String event,
            long seq,
            AndroidDebugFormatter.SurfaceEventSnapshot state) {
        terminalStatusController.callNativeWithSurfaceState(event, seq, state);
    }

    private AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return terminalSurfaceStateSnapshotReader.read();
    }

    private void updateStatus(String state) {
        terminalStatusController.updateStatus(state);
    }

    public void appendEvent(String message) {
        terminalStatusController.appendEvent(message);
    }
}
