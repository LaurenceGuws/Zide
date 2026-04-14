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
        appendEvent("activity.on.new_intent");
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
                new StatusViewCallbacks(
                        () -> this,
                        () -> debugViewEnabled,
                        () -> nativeLoaded,
                        this::hasWindowFocus,
                        () -> imeVisible,
                        visible -> imeVisible = visible,
                        () -> surfaceHostBridge,
                        () -> currentInstallState,
                        () -> currentReadinessState,
                        this::currentSurfaceStateSnapshot,
                        reason -> {
                            if (surfaceHostController != null) {
                                surfaceHostController.notifyVisibleViewport(reason);
                            }
                        }));
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
                new InteractionCallbacks(
                        () -> this,
                        () -> handler,
                        () -> productSurfaceContainer,
                        this::productViewportWidthPx,
                        this::productViewportHeightPx,
                        () -> nativeLoaded,
                        () -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.stopScrollbackFling();
                            }
                        },
                        () -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.refreshProductScrollOverlay();
                            }
                        },
                        () -> {
                            if (productFrameLoopController != null) {
                                productFrameLoopController.reevaluate();
                            }
                        },
                        this::appendEvent));
        selectionController = result.selectionController;
        terminalGestureStateController = result.terminalGestureStateController;
    }

    private void installInputControllers() {
        final InputAssembly.Result result = InputAssembly.assemble(
                new InputCallbacks(
                        () -> this,
                        () -> rootView,
                        () -> this,
                        () -> getSystemService(InputMethodManager.class),
                        () -> imeVisible,
                        visible -> imeVisible = visible,
                        () -> nativeLoaded,
                        TerminalNativeBridge::nativeFollowSessionLiveBottomBridge,
                        () -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.refreshProductScrollOverlay();
                            }
                        },
                        this::updateStatus,
                        this::appendEvent));
        shellInputView = result.shellInputView;
        terminalHardwareKeyboardController = result.hardwareKeyboardController;
        terminalImeFocusRecoveryController = result.imeFocusRecoveryController;
    }

    private void assembleWidgetHostControllers() {
        final WidgetAssembly.Result result = WidgetAssembly.assemble(
                new WidgetCallbacks(
                        () -> this,
                        () -> handler,
                        () -> nativeLoaded,
                        () -> debugViewEnabled,
                        enabled -> debugViewEnabled = enabled,
                        () -> imeVisible,
                        visible -> imeVisible = visible,
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
                        () -> surfaceHostBridge,
                        () -> currentInstallState.isInstalling(),
                        () -> currentInstallState.isFailed(),
                        () -> currentReadinessState,
                        () -> currentInstallState,
                        () -> terminalProductRuntimeController != null
                                && terminalProductRuntimeController.shouldRunProductFrameLoop(),
                        () -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.refreshProductScrollOverlay();
                            }
                        },
                        this::appendEvent,
                        this::updateStatus,
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
                        statusLabel -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.handleProductShellStateEvent(statusLabel);
                            }
                        },
                        TerminalNativeBridge::nativeSetSessionScrollbackOffsetBridge,
                        TerminalNativeBridge::nativeFollowSessionLiveBottomBridge,
                        this::productViewportHeightPx,
                        () -> {
                            if (productFrameLoopController != null) {
                                productFrameLoopController.reevaluate();
                            }
                        },
                        this::runPackageDoctor,
                        this::sendDirectText,
                        reason -> {
                            if (surfaceHostController != null) {
                                surfaceHostController.notifyVisibleViewport(reason);
                            }
                        },
                        () -> userlandSessionCoordinator.refreshAndApply(false)));
        productShellStatePresenter = result.productShellStatePresenter;
        terminalChromeController = result.terminalChromeController;
        terminalViewModeController = result.terminalViewModeController;
        surfaceHostBridge = result.surfaceHostBridge;
        surfaceHostController = result.surfaceHostController;
        terminalSurfaceWidgetController = result.terminalSurfaceWidgetController;
    }

    private void assembleSessionControllers() {
        final SessionAssembly.Result result = SessionAssembly.assemble(
                new SessionAssemblyCallbacks(
                        () -> this,
                        () -> userlandRelease,
                        () -> nativeLoaded,
                        () -> handler,
                        this::appendEvent,
                        this::updateStatus,
                        readinessState -> currentReadinessState = readinessState,
                        () -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.refreshProductShellState();
                            }
                        },
                        () -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.refreshDebugStatusSurface();
                            }
                        },
                        () -> terminalProductRuntimeController != null
                                && terminalProductRuntimeController.shouldRunProductFrameLoop(),
                        () -> {
                            final int tick = nativeLoaded ? TerminalNativeBridge.nativeTickProductFrameBridge()
                                    : 0;
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.refreshProductScrollOverlay();
                            }
                            return tick;
                        },
                        TerminalNativeBridge::nativeRestartSessionBridge,
                        TerminalNativeBridge::nativePollSessionBridge,
                        TerminalNativeBridge::nativeIsSessionAliveBridge));
        userlandSessionCoordinator = result.userlandSessionCoordinator;
        productFrameLoopController = result.frameLoopController;
    }

    private void assembleUserlandWorkflowControllers() {
        final WorkflowAssembly.Result result = WorkflowAssembly.assemble(
                new WorkflowAssemblyCallbacks(
                        () -> this,
                        () -> handler,
                        () -> userlandRelease,
                        release -> userlandRelease = release,
                        installState -> currentInstallState = installState,
                        readinessState -> currentReadinessState = readinessState,
                        (installState, statusLabel) -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.applyInstallState(installState, statusLabel);
                            }
                        },
                        (eventName, statusLabel, logRefresh) -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.restartSession(eventName, statusLabel,
                                        logRefresh);
                            }
                        },
                        (eventName, statusLabel) -> {
                            if (terminalViewModeController != null) {
                                terminalViewModeController.showDebugView(eventName, statusLabel);
                            }
                        },
                        this::appendEvent,
                        this::updateStatus,
                        () -> packageStatusText));
        terminalRuntimeAssetsController = result.runtimeAssetsController;
        userlandWorkflowController = result.userlandWorkflowController;
    }

    private void assembleProductRuntimeController() {
        terminalProductRuntimeController = ProductRuntimeAssembly.assemble(
                new ProductRuntimeAssemblyCallbacks(
                        () -> debugViewEnabled,
                        () -> nativeLoaded,
                        () -> currentInstallState,
                        installState -> currentInstallState = installState,
                        () -> currentReadinessState,
                        () -> surfaceHostBridge != null ? surfaceHostBridge.currentSurfaceView() : null,
                        () -> productBootstrapBlocker,
                        () -> terminalScrollOverlay,
                        () -> selectionController,
                        () -> productShellStatePresenter,
                        () -> productFrameLoopController,
                        () -> terminalStatusController,
                        () -> userlandSessionCoordinator,
                        () -> terminalGestureStateController,
                        this::appendEvent,
                        this::updateStatus));
    }

    private void assembleActivityLifecycleController() {
        terminalActivityLifecycleController = new LifecycleController(
                new LifecycleCallbacks(
                        () -> nativeLoaded,
                        TerminalNativeBridge::nativeOnStartBridge,
                        TerminalNativeBridge::nativeOnResumeBridge,
                        TerminalNativeBridge::nativeOnPauseBridge,
                        TerminalNativeBridge::nativeOnStopBridge,
                        TerminalNativeBridge::nativeOnWindowFocusBridge,
                        this::appendEvent,
                        this::callNative,
                        this::updateStatus,
                        () -> productFrameLoopController.stop(),
                        () -> userlandSessionCoordinator.refreshAndApply(false),
                        () -> surfaceHostController.onPause(),
                        (debugRecreateSurfaceOnce, debugResizeSurfaceOnce, debugStartShellOnce) -> surfaceHostController
                                .onResume(
                                        debugRecreateSurfaceOnce,
                                        debugResizeSurfaceOnce,
                                        debugStartShellOnce)));
    }

    private void bindAndStartUiControllers() {
        UiStartupAssembly.start(
                new UiStartupCallbacks(
                        () -> terminalViewportController,
                        () -> terminalChromeController,
                        () -> productBootstrapRetryButton,
                        () -> productBootstrapDebugButton,
                        () -> currentInstallState,
                        () -> currentReadinessState,
                        () -> userlandWorkflowController,
                        () -> userlandSessionCoordinator,
                        (eventName, statusLabel) -> {
                            if (terminalViewModeController != null) {
                                terminalViewModeController.showDebugView(eventName, statusLabel);
                            }
                        },
                        this::appendEvent,
                        this::updateStatus,
                        () -> terminalRuntimeAssetsController,
                        () -> terminalViewModeController,
                        () -> surfaceHostController,
                        () -> terminalSurfaceWidgetController,
                        () -> productShellStatePresenter,
                        () -> productFrameLoopController,
                        () -> leftSidebar));
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
