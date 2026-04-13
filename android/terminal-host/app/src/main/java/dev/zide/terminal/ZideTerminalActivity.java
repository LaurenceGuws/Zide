package dev.zide.terminal;

import dev.zide.terminal.debug.AndroidDebugFormatter;
import dev.zide.terminal.gesture.ProductGestureController;
import dev.zide.terminal.gesture.TerminalGestureStateController;
import dev.zide.terminal.input.ShellInputView;
import dev.zide.terminal.input.TerminalHardwareKeyboardController;
import dev.zide.terminal.input.TerminalImeFocusRecoveryController;
import dev.zide.terminal.selection.TerminalSelectionController;
import dev.zide.terminal.session.ShellSessionController;
import dev.zide.terminal.scroll.TerminalScrollOverlayView;
import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandPolicy;
import dev.zide.terminal.userland.UserlandRelease;
import dev.zide.terminal.userland.UserlandBootstrapBlockerController;
import dev.zide.terminal.userland.UserlandWorkflowController;
import dev.zide.terminal.userland.UserlandSessionCoordinator;
import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.host.TerminalFrameLoopController;
import dev.zide.terminal.host.TerminalSurfaceHostController;
import dev.zide.terminal.host.TerminalSurfaceHostBridge;
import dev.zide.terminal.host.TerminalChromeController;
import dev.zide.terminal.host.TerminalViewModeController;
import dev.zide.terminal.host.TerminalSelectionHostBridge;
import dev.zide.terminal.host.TerminalSelectionInteractionHostBridge;
import dev.zide.terminal.host.TerminalStatusHostBridge;
import dev.zide.terminal.host.TerminalUserlandWorkflowHostBridge;
import dev.zide.terminal.host.TerminalUserlandSessionHostBridge;
import dev.zide.terminal.host.TerminalProductShellStateHostBridge;
import dev.zide.terminal.host.TerminalRuntimeAssetsController;
import dev.zide.terminal.host.TerminalRuntimeAssetsHostBridge;
import dev.zide.terminal.host.TerminalViewportHostBridge;
import dev.zide.terminal.host.TerminalGestureStateHostBridge;
import dev.zide.terminal.host.TerminalShellSessionBridge;
import dev.zide.terminal.host.TerminalFrameLoopHostBridge;
import dev.zide.terminal.host.TerminalViewportController;
import dev.zide.terminal.host.TerminalSurfaceWidgetController;
import dev.zide.terminal.host.TerminalProductRuntimeController;
import dev.zide.terminal.host.TerminalActivityViewBindings;
import dev.zide.terminal.host.TerminalSurfaceHostCallbacks;
import dev.zide.terminal.host.TerminalChromeHostFactory;
import dev.zide.terminal.host.TerminalProductRuntimeHostCallbacks;
import dev.zide.terminal.host.TerminalHostAssembler;
import dev.zide.terminal.host.TerminalInteractionHostFactory;
import dev.zide.terminal.host.TerminalInputHostFactory;
import dev.zide.terminal.host.TerminalSurfaceHostFactory;
import dev.zide.terminal.host.TerminalProductShellStateHostCallbacks;
import dev.zide.terminal.host.TerminalSurfaceWidgetHostCallbacks;
import dev.zide.terminal.host.TerminalViewModeHostCallbacks;
import dev.zide.terminal.host.TerminalUserlandWorkflowHostCallbacks;
import dev.zide.terminal.host.TerminalSelectionFactoryHostCallbacks;
import dev.zide.terminal.host.TerminalGestureStateFactoryHostCallbacks;
import dev.zide.terminal.host.TerminalShellSessionCallbacks;
import dev.zide.terminal.host.TerminalUserlandSessionHostCallbacks;
import dev.zide.terminal.host.TerminalFrameLoopHostCallbacks;
import dev.zide.terminal.host.TerminalUserlandBootstrapBlockerHostCallbacks;
import dev.zide.terminal.host.TerminalRuntimeAssetsHostCallbacks;
import dev.zide.terminal.host.TerminalStatusHostCallbacks;
import dev.zide.terminal.host.TerminalViewportHostCallbacks;
import dev.zide.terminal.host.TerminalSurfaceHostLifecycleCallbacks;
import dev.zide.terminal.debug.TerminalNativeStatusLabels;
import dev.zide.terminal.debug.TerminalStatusController;
import dev.zide.terminal.debug.TerminalSurfaceStateSnapshotReader;
import dev.zide.terminal.debug.TerminalSurfaceStateSnapshotHostCallbacks;
import android.app.Activity;
import android.content.Intent;
import android.view.Gravity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.SurfaceView;
import android.view.View;
import android.view.KeyEvent;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

/**
 * Android activity entrypoint for the terminal-host product surface.
 *
 * <p>The activity should remain wiring-oriented: inflate views, construct controllers, forward
 * lifecycle/input/surface callbacks, and expose the JNI bridge. Terminal truth stays in Zig, while
 * Android-specific policy belongs in the package controllers below this activity.
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
    private ProductGestureController productGestureController;
    private TerminalSelectionController selectionController;
    private TerminalGestureStateController terminalGestureStateController;
    private ShellSessionController shellSessionController;
    private boolean debugViewEnabled = false;
    private boolean imeVisible = false;
    private UserlandRelease userlandRelease;
    private UserlandBootstrapBlockerController userlandBootstrapBlockerController;
    private UserlandWorkflowController userlandWorkflowController;
    private TerminalUserlandWorkflowHostBridge terminalUserlandWorkflowHostBridge;
    private UserlandSessionCoordinator userlandSessionCoordinator;
    private TerminalUserlandSessionHostBridge terminalUserlandSessionHostBridge;
    private TerminalFrameLoopController productFrameLoopController;
    private ProductShellStatePresenter productShellStatePresenter;
    private TerminalSurfaceHostController surfaceHostController;
    private TerminalSurfaceHostBridge surfaceHostBridge;
    private TerminalChromeController terminalChromeController;
    private TerminalViewModeController terminalViewModeController;
    private TerminalProductShellStateHostBridge terminalProductShellStateHostBridge;
    private TerminalRuntimeAssetsController terminalRuntimeAssetsController;
    private TerminalViewportController terminalViewportController;
    private TerminalStatusController terminalStatusController;
    private TerminalStatusHostBridge terminalStatusHostBridge;
    private TerminalSurfaceStateSnapshotReader terminalSurfaceStateSnapshotReader;
    private TerminalSurfaceWidgetController terminalSurfaceWidgetController;
    private TerminalProductRuntimeController terminalProductRuntimeController;
    private UserlandInstallState currentInstallState = UserlandInstallState.idle();
    private UserlandBootstrapState currentBootstrapState;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        initializeStatusAndViewControllers();
        selectionController = TerminalInteractionHostFactory.createSelectionController(
                this,
                productSurfaceContainer,
                this::productViewportWidthPx,
                this::productViewportHeightPx,
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
                this::appendEvent,
                () -> nativeLoaded,
                TerminalNativeBridge::nativeBeginShellWordSelectionAtVisibleCellBridge,
                TerminalNativeBridge::nativeExtendShellSelectionGestureToVisibleCellBridge,
                TerminalNativeBridge::nativeFinishShellSelectionGestureBridge,
                TerminalNativeBridge::nativeClearShellSelectionBridge,
                TerminalNativeBridge::nativeUpdateShellSelectionStartAtVisibleCellBridge,
                TerminalNativeBridge::nativeUpdateShellSelectionEndAtVisibleCellBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionActiveBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionRectLeftBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionRectTopBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionRectRightBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionRectBottomBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionStartRectLeftBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionStartRectTopBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionStartRectRightBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionStartRectBottomBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionEndRectLeftBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionEndRectTopBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionEndRectRightBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionEndRectBottomBridge,
                TerminalNativeBridge::nativeCurrentShellSelectionTextBytesBridge,
                TerminalNativeBridge::nativeCurrentShellVisibleRowsBridge,
                TerminalNativeBridge::nativeCurrentShellVisibleColsBridge,
                TerminalNativeBridge::nativeCurrentShellScrollbackCountBridge,
                TerminalNativeBridge::nativeCurrentShellScrollbackOffsetBridge,
                TerminalNativeBridge::nativeSetShellScrollbackOffsetBridge,
                TerminalNativeBridge::nativeFollowShellLiveBottomBridge);
        selectionController.install();
        terminalGestureStateController = TerminalInteractionHostFactory.createGestureStateController(
                this,
                handler,
                () -> nativeLoaded,
                TerminalNativeBridge::nativeCurrentShellVisibleRowsBridge,
                this::productViewportHeightPx,
                TerminalNativeBridge::nativeCurrentShellScrollbackCountBridge,
                TerminalNativeBridge::nativeCurrentShellScrollbackOffsetBridge,
                TerminalNativeBridge::nativeSetShellScrollbackOffsetBridge,
                TerminalNativeBridge::nativeFollowShellLiveBottomBridge,
                TerminalNativeBridge::nativeApplyTerminalPinchZoomBridge,
                TerminalNativeBridge::nativeSetTerminalPinchActiveBridge,
                () -> {
                    if (terminalProductRuntimeController != null) {
                        terminalProductRuntimeController.refreshProductScrollOverlay();
                    }
                },
                () -> {
                    if (productFrameLoopController != null) {
                        productFrameLoopController.reevaluate();
                    }
                });
        terminalRuntimeAssetsController = new TerminalRuntimeAssetsController(
                new TerminalRuntimeAssetsHostBridge(
                        this,
                        new TerminalRuntimeAssetsHostCallbacks(this::appendEvent)));
        userlandRelease = terminalRuntimeAssetsController.loadUserlandRelease();
        assembleSessionControllers();
        terminalUserlandWorkflowHostBridge = new TerminalUserlandWorkflowHostBridge(
                this,
                handler,
                new TerminalUserlandWorkflowHostCallbacks(
                        () -> userlandRelease,
                        this::appendEvent,
                        (installState, statusLabel) -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.applyInstallState(installState, statusLabel);
                            }
                        },
                        installState -> currentInstallState = installState,
                        bootstrapState -> currentBootstrapState = bootstrapState,
                        (eventName, statusLabel, logRefresh) -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.restartShellSession(eventName, statusLabel, logRefresh);
                            }
                        },
                        (eventName, statusLabel) -> {
                            if (terminalViewModeController != null) {
                                terminalViewModeController.showDebugView(eventName, statusLabel);
                            }
                        },
                        packageStatusText,
                        this::updateStatus));
        userlandWorkflowController = new UserlandWorkflowController(terminalUserlandWorkflowHostBridge);
        assembleWidgetHostControllers();
        terminalProductRuntimeController = TerminalHostAssembler.createProductRuntimeController(
                TerminalHostAssembler.createProductRuntimeHostCallbacks(
                        () -> debugViewEnabled,
                        () -> nativeLoaded,
                        () -> currentInstallState,
                        installState -> currentInstallState = installState,
                        () -> currentBootstrapState,
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
                        this::updateStatus,
                        TerminalNativeBridge::nativeCurrentShellVisibleRowsBridge,
                        TerminalNativeBridge::nativeCurrentShellScrollbackCountBridge,
                        TerminalNativeBridge::nativeCurrentShellScrollbackOffsetBridge,
                        TerminalNativeBridge::nativeRestartShellSessionBridge));
        currentBootstrapState = userlandSessionCoordinator.loadBootstrapState();
        installInputControllers();
        bindAndStartUiControllers();
        finishOnCreateLifecycle();
    }

    @Override
    protected void onStart() {
        super.onStart();
        appendEvent("activity.onStart");
        callNative("native.onStart", nativeLoaded ? TerminalNativeBridge.nativeOnStartBridge() : -1);
        updateStatus("started");
    }

    @Override
    protected void onResume() {
        super.onResume();
        appendEvent("activity.onResume");
        callNative("native.onResume", nativeLoaded ? TerminalNativeBridge.nativeOnResumeBridge() : -1);
        surfaceHostController.onResume(
                getIntent().getBooleanExtra(EXTRA_DEBUG_RECREATE_SURFACE_ONCE, false),
                getIntent().getBooleanExtra(EXTRA_DEBUG_RESIZE_SURFACE_ONCE, false),
                getIntent().getBooleanExtra(EXTRA_DEBUG_START_SHELL_ONCE, false));
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        appendEvent("activity.onNewIntent");
    }

    @Override
    protected void onPause() {
        appendEvent("activity.onPause");
        callNative("native.onPause", nativeLoaded ? TerminalNativeBridge.nativeOnPauseBridge() : -1);
        productFrameLoopController.stop();
        userlandSessionCoordinator.refreshAndApply(false);
        surfaceHostController.onPause();
        updateStatus("paused");
        super.onPause();
    }

    @Override
    protected void onStop() {
        appendEvent("activity.onStop");
        callNative("native.onStop", nativeLoaded ? TerminalNativeBridge.nativeOnStopBridge() : -1);
        updateStatus("stopped");
        super.onStop();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        appendEvent("activity.onWindowFocusChanged focus=" + hasFocus);
        callNative("native.onWindowFocus", nativeLoaded ? TerminalNativeBridge.nativeOnWindowFocusBridge(hasFocus) : -1);
        updateStatus(hasFocus ? "window-focused" : "window-unfocused");
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (terminalHardwareKeyboardController != null
                && terminalHardwareKeyboardController.handleDispatchKeyEvent(event)) {
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    private void installShellInputView() {
        shellInputView = new ShellInputView(this, this);
        final FrameLayout root = (FrameLayout) rootView;
        final FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(1, 1);
        lp.gravity = Gravity.BOTTOM | Gravity.START;
        root.addView(shellInputView, lp);
    }

    private void initializeStatusAndViewControllers() {
        final TerminalActivityViewBindings viewBindings = TerminalActivityViewBindings.from(this);
        packageStatusText = viewBindings.packageStatusText;
        productBootstrapTitle = viewBindings.productBootstrapTitle;
        productBootstrapDetail = viewBindings.productBootstrapDetail;
        productBootstrapRetryButton = viewBindings.productBootstrapRetryButton;
        productBootstrapDebugButton = viewBindings.productBootstrapDebugButton;
        rootView = viewBindings.rootView;
        productView = viewBindings.productView;
        debugView = viewBindings.debugView;
        productBootstrapBlocker = viewBindings.productBootstrapBlocker;
        drawerScrim = viewBindings.drawerScrim;
        drawerEdgeHotspot = viewBindings.drawerEdgeHotspot;
        leftSidebar = viewBindings.leftSidebar;
        productSurfaceContainer = viewBindings.productSurfaceContainer;
        terminalScrollOverlay = viewBindings.terminalScrollOverlay;
        assistCtrlButton = viewBindings.assistCtrlButton;
        assistAltButton = viewBindings.assistAltButton;
        terminalSurfaceStateSnapshotReader = new TerminalSurfaceStateSnapshotReader(
                new TerminalSurfaceStateSnapshotHostCallbacks(
                        () -> nativeLoaded,
                        TerminalNativeBridge::nativeCurrentWindowTokenBridge,
                        TerminalNativeBridge::nativeCurrentSurfaceEpochBridge,
                        TerminalNativeBridge::nativeCurrentSurfaceTransitionBridge,
                        TerminalNativeBridge::nativeCurrentRendererStatusBridge,
                        TerminalNativeBridge::nativeCurrentRendererSwapCountBridge,
                        TerminalNativeBridge::nativeCurrentRendererBoundEpochBridge,
                        TerminalNativeBridge::nativeCurrentRendererContextCreateCountBridge,
                        TerminalNativeBridge::nativeCurrentRendererSurfaceCreateCountBridge,
                        TerminalNativeBridge::nativeCurrentRendererTextureCreateCountBridge,
                        TerminalNativeBridge::nativeCurrentRendererTextureAliveBridge,
                        TerminalNativeBridge::nativeCurrentRendererTextureUploadCountBridge,
                        TerminalNativeBridge::nativeCurrentRendererTextureUpdateCountBridge,
                        TerminalNativeBridge::nativeCurrentRendererTextureResizeCountBridge,
                        TerminalNativeBridge::nativeCurrentRendererTextureWidthBridge,
                        TerminalNativeBridge::nativeCurrentRendererTextureHeightBridge));
        terminalStatusHostBridge = new TerminalStatusHostBridge(new TerminalStatusHostCallbacks(
                () -> debugViewEnabled,
                () -> nativeLoaded,
                this::hasWindowFocus,
                () -> imeVisible,
                () -> surfaceHostBridge != null ? surfaceHostBridge.currentSurfaceView() : null,
                () -> surfaceHostBridge != null ? surfaceHostBridge.currentVisibleViewportWidth() : 0,
                () -> surfaceHostBridge != null ? surfaceHostBridge.currentVisibleViewportHeight() : 0,
                () -> currentInstallState,
                () -> currentBootstrapState,
                this::currentSurfaceStateSnapshot));
        terminalStatusController = new TerminalStatusController(
                viewBindings.statusText,
                viewBindings.eventLogText,
                terminalStatusHostBridge);
        terminalViewportController = new TerminalViewportController(
                new TerminalViewportHostBridge(
                        productView,
                        productSurfaceContainer,
                        new TerminalViewportHostCallbacks(
                                () -> imeVisible,
                                visible -> ZideTerminalActivity.this.imeVisible = visible,
                                reason -> surfaceHostController.notifyVisibleViewport(reason))));
    }

    private void installInputControllers() {
        installShellInputView();
        terminalHardwareKeyboardController = TerminalInputHostFactory.createHardwareKeyboardController(
                () -> shellInputView,
                () -> getSystemService(InputMethodManager.class),
                () -> imeVisible,
                visible -> imeVisible = visible,
                () -> nativeLoaded,
                TerminalNativeBridge::nativeFollowShellLiveBottomBridge,
                () -> {
                    if (terminalProductRuntimeController != null) {
                        terminalProductRuntimeController.refreshProductScrollOverlay();
                    }
                },
                this::updateStatus);
        terminalImeFocusRecoveryController = TerminalInputHostFactory.createImeFocusRecoveryController(
                () -> shellInputView,
                () -> imeVisible,
                this::appendEvent,
                () -> getSystemService(InputMethodManager.class));
    }

    private void assembleWidgetHostControllers() {
        terminalProductShellStateHostBridge = TerminalHostAssembler.createProductShellStateHostBridge(
                productBootstrapBlocker,
                terminalScrollOverlay,
                productBootstrapTitle,
                productBootstrapDetail,
                productBootstrapRetryButton,
                new TerminalProductShellStateHostCallbacks(
                        () -> nativeLoaded,
                        TerminalNativeBridge::nativeSharedShellRendererActiveBridge,
                        () -> currentInstallState.isInstalling(),
                        () -> currentInstallState.isFailed(),
                        () -> currentBootstrapState,
                        () -> currentInstallState,
                        () -> surfaceHostBridge != null ? surfaceHostBridge.currentSurfaceView() : null));
        productShellStatePresenter = new ProductShellStatePresenter(terminalProductShellStateHostBridge);
        final var chromeHostBridge = TerminalChromeHostFactory.createChromeHostBridge(
                this,
                rootView,
                findViewById(R.id.debug_view_mode_button),
                drawerScrim,
                drawerEdgeHotspot,
                leftSidebar,
                TerminalChromeHostFactory.createChromeHostCallbacks(
                        () -> debugViewEnabled,
                        (eventName, statusLabel) -> {
                            if (terminalViewModeController != null) {
                                terminalViewModeController.showProductView(eventName, statusLabel);
                            }
                        },
                        (eventName, statusLabel) -> {
                            if (terminalViewModeController != null) {
                                terminalViewModeController.showDebugView(eventName, statusLabel);
                            }
                        },
                        this::runPackageDoctor,
                        this::appendEvent,
                        () -> imeVisible,
                        visible -> imeVisible = visible,
                        () -> shellInputView,
                        () -> assistCtrlButton,
                        () -> assistAltButton,
                        this::sendDirectText,
                        this::updateStatus));
        terminalChromeController = new TerminalChromeController(chromeHostBridge);
        terminalViewModeController = TerminalHostAssembler.createViewModeController(
                productView,
                debugView,
                terminalScrollOverlay,
                productSurfaceContainer,
                new TerminalViewModeHostCallbacks(
                        () -> debugViewEnabled,
                        enabled -> debugViewEnabled = enabled,
                        this::appendEvent,
                        this::updateStatus,
                        () -> terminalChromeController.closeSidebar(),
                        reason -> surfaceHostController.notifyVisibleViewport(reason),
                        () -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.refreshProductScrollOverlay();
                            }
                        },
                        () -> userlandSessionCoordinator.refreshAndApply(false)));
        surfaceHostBridge = TerminalSurfaceHostFactory.createSurfaceHostBridge(
                TerminalSurfaceHostFactory.createSurfaceHostCallbacks(
                        handler,
                        productSurfaceContainer,
                        TerminalSurfaceHostFactory.createSurfaceHostLifecycleCallbacks(
                                () -> nativeLoaded,
                                () -> debugViewEnabled,
                                this::currentImeVisible,
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
                                nextSurfaceView -> {
                                    productGestureController = new ProductGestureController(
                                            nextSurfaceView,
                                            terminalSurfaceWidgetController);
                                    productGestureController.install();
                                },
                                (nextSurfaceView, callback) -> {
                                    if (callback != null) {
                                        nextSurfaceView.getHolder().addCallback(callback);
                                    }
                                },
                                () -> terminalSurfaceWidgetController)));
        surfaceHostController = new TerminalSurfaceHostController(surfaceHostBridge);
        terminalSurfaceWidgetController = TerminalHostAssembler.createSurfaceWidgetController(
                surfaceHostController,
                selectionController,
                terminalGestureStateController,
                new TerminalSurfaceWidgetHostCallbacks(
                        () -> nativeLoaded,
                        TerminalNativeBridge::nativeSetShellScrollbackOffsetBridge,
                        TerminalNativeBridge::nativeFollowShellLiveBottomBridge,
                        this::productViewportHeightPx,
                        this::appendEvent,
                        () -> {
                            if (terminalProductRuntimeController != null) {
                                terminalProductRuntimeController.refreshProductScrollOverlay();
                            }
                        },
                        () -> {
                            if (productFrameLoopController != null) {
                                productFrameLoopController.reevaluate();
                            }
                        }));
        terminalScrollOverlay.setHost(terminalSurfaceWidgetController);
    }

    private void assembleSessionControllers() {
        shellSessionController = TerminalHostAssembler.createShellSessionController(
                UserlandPolicy.bootstrapStampPath(this),
                UserlandPolicy.shellPath(this),
                userlandRelease,
                nativeLoaded,
                TerminalNativeBridge::nativeRestartShellSessionBridge,
                TerminalNativeBridge::nativePollShellSessionBridge,
                TerminalNativeBridge::nativeIsShellSessionAliveBridge);
        terminalUserlandSessionHostBridge = TerminalHostAssembler.createUserlandSessionHostBridge(
                this::appendEvent,
                TerminalNativeStatusLabels::shellStartStatusLabel,
                bootstrapState -> currentBootstrapState = bootstrapState,
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
                this::updateStatus);
        userlandSessionCoordinator = new UserlandSessionCoordinator(
                shellSessionController,
                terminalUserlandSessionHostBridge);
        productFrameLoopController = TerminalHostAssembler.createFrameLoopController(
                handler,
                () -> terminalProductRuntimeController != null
                        && terminalProductRuntimeController.shouldRunProductFrameLoop(),
                () -> {
                    final int tick = nativeLoaded ? TerminalNativeBridge.nativeTickProductShellFrameBridge() : 0;
                    if (terminalProductRuntimeController != null) {
                        terminalProductRuntimeController.refreshProductScrollOverlay();
                    }
                    return tick;
                });
    }

    private void bindAndStartUiControllers() {
        terminalViewportController.installInsetsHandling();
        terminalViewportController.installViewportTracking();
        terminalChromeController.bindSidebarControls();
        terminalChromeController.bindViewModeToggle();
        userlandBootstrapBlockerController = new UserlandBootstrapBlockerController(
                productBootstrapRetryButton,
                productBootstrapDebugButton,
                new TerminalUserlandBootstrapBlockerHostCallbacks(
                        () -> currentInstallState,
                        () -> currentBootstrapState,
                        () -> userlandWorkflowController,
                        () -> userlandSessionCoordinator,
                        (eventName, statusLabel) -> {
                            if (terminalViewModeController != null) {
                                terminalViewModeController.showDebugView(eventName, statusLabel);
                            }
                        },
                        this::appendEvent,
                        this::updateStatus));
        userlandBootstrapBlockerController.bind();
        terminalChromeController.bindAssistBar();
        terminalRuntimeAssetsController.prepareRuntimeAssets();
        terminalViewModeController.applyCurrentViewMode();
        surfaceHostController.installSurfaceView("activity-create", terminalSurfaceWidgetController);
        productShellStatePresenter.refresh();
        productFrameLoopController.reevaluate();
        leftSidebar.post(() -> {
            leftSidebar.setTranslationX(-leftSidebar.getWidth());
            terminalChromeController.updateSidebarVisibility(false);
        });
    }

    private void finishOnCreateLifecycle() {
        appendEvent("activity.onCreate nativeLoaded=" + nativeLoaded);
        if (nativeLoadError != null) {
            appendEvent("native.load.error=" + nativeLoadError);
        }
        callNative("native.onCreate", nativeLoaded ? TerminalNativeBridge.nativeOnCreateBridge() : -1);
        updateStatus("created");
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
        TerminalNativeBridge.nativeSendShellCodepointBridge(codepoint);
    }

    @Override
    public void sendDirectText(String text) {
        if (!nativeLoaded)
            return;
        for (int i = 0; i < text.length();) {
            final int cp = text.codePointAt(i);
            TerminalNativeBridge.nativeSendShellCodepointBridge(cp);
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

    private boolean currentImeVisible() {
        return terminalChromeController.currentImeVisible();
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
