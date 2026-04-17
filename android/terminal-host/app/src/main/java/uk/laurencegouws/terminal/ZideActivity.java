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
import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.debug.SurfaceStateSnapshotReader;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.host.lifecycle.LifecycleController;
import uk.laurencegouws.terminal.host.lifecycle.LifecycleDebugIntentArgs;
import uk.laurencegouws.terminal.host.ui.ChromeController;
import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.input.InputAssembly;
import uk.laurencegouws.terminal.host.input.InputCallbacks;
import uk.laurencegouws.terminal.host.interaction.InteractionAssembly;
import uk.laurencegouws.terminal.host.interaction.InteractionCallbacks;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssembly;
import uk.laurencegouws.terminal.host.runtime.RuntimeAssemblyCallbacks;
import uk.laurencegouws.terminal.host.runtime.RuntimeController;
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
import uk.laurencegouws.terminal.host.userland.WorkflowAssembly;
import uk.laurencegouws.terminal.host.userland.WorkflowAssemblyCallbacks;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.input.HardwareKeyboardController;
import uk.laurencegouws.terminal.input.ImeFocusRecoveryController;
import uk.laurencegouws.terminal.scroll.ScrollOverlayView;
import uk.laurencegouws.terminal.selection.SelectionController;
import uk.laurencegouws.terminal.userland.ShellStatePresenter;
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
public final class ZideActivity extends Activity
        implements ShellInputView.Host {
    private static final boolean nativeLoaded = NativeBridge.nativeLoaded();
    private static final String nativeLoadError = NativeBridge.nativeLoadError();

    private final Handler handler = new Handler(Looper.getMainLooper());
    private TextView productReadinessTitle;
    private TextView productReadinessDetail;
    private Button productReadinessRetryButton;
    private View rootView;
    private View productView;
    private View productReadinessBlocker;
    private View drawerScrim;
    private View drawerEdgeHotspot;
    private View leftSidebar;
    private FrameLayout productSurfaceContainer;
    private ScrollOverlayView terminalScrollOverlay;
    private Button assistCtrlButton;
    private Button assistAltButton;
    private ShellInputView shellInputView;
    private HardwareKeyboardController HardwareKeyboardController;
    private ImeFocusRecoveryController ImeFocusRecoveryController;
    private SelectionController selectionController;
    private GestureStateController GestureStateController;
    private boolean imeVisible = false;
    private UserlandRelease userlandRelease;
    private UserlandWorkflowController userlandWorkflowController;
    private UserlandSessionCoordinator userlandSessionCoordinator;
    private FrameLoopController productFrameLoopController;
    private ShellStatePresenter ShellStatePresenter;
    private SurfaceController surfaceHostController;
    private SurfaceBridge surfaceHostBridge;
    private ChromeController terminalChromeController;
    private ViewModeController terminalViewModeController;
    private RuntimeAssetsController terminalRuntimeAssetsController;
    /**
     * Product terminal viewport authority.
     *
     * <p>
     * The SurfaceView, scroll overlay, gesture math, and native grid-fit path must
     * all describe the same Android-owned rectangle. Do not use the broader content
     * frame here; it can acquire non-terminal children and should not become the
     * terminal size contract by accident.
     */
    private ViewportController terminalViewportController;
    private StatusController StatusController;
    private SurfaceStateSnapshotReader SurfaceStateSnapshotReader;
    private SurfaceWidgetController terminalSurfaceWidgetController;
    private RuntimeController terminalRuntimeController;
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
        assembleRuntimeController();
        assembleActivityLifecycleController();
        loadInitialReadinessState();
        installInputControllers();
        bindAndStartUiControllers();
        terminalActivityLifecycleController.onCreate();
    }

    private void assembleRuntimeController() {
        terminalRuntimeController = RuntimeAssembly.assemble(
                createRuntimeAssemblyCallbacks());
    }

    @Override
    protected void onStart() {
        super.onStart();
        terminalActivityLifecycleController.onStart();
    }

    @Override
    protected void onResume() {
        super.onResume();
        final LifecycleDebugIntentArgs debugArgs = LifecycleDebugIntentArgs.fromIntent(getIntent());
        terminalActivityLifecycleController.onResume(
                debugArgs.recreateSurfaceOnce,
                debugArgs.resizeSurfaceOnce,
                debugArgs.startShellOnce);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        applyNewIntent(intent);
        terminalActivityLifecycleController.onNewIntent();
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
        if (handleHardwareDispatchKeyEventIfReady(event)) {
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    private void initializeStatusAndViewControllers() {
        final StatusViewAssembly.Result result = assembleStatusViewResult();
        productReadinessTitle = result.productReadinessTitle;
        productReadinessDetail = result.productReadinessDetail;
        productReadinessRetryButton = result.productReadinessRetryButton;
        rootView = result.rootView;
        productView = result.productView;
        productReadinessBlocker = result.productReadinessBlocker;
        drawerScrim = result.drawerScrim;
        drawerEdgeHotspot = result.drawerEdgeHotspot;
        leftSidebar = result.leftSidebar;
        productSurfaceContainer = result.productSurfaceContainer;
        terminalScrollOverlay = result.terminalScrollOverlay;
        assistCtrlButton = result.assistCtrlButton;
        assistAltButton = result.assistAltButton;
        SurfaceStateSnapshotReader = result.SurfaceStateSnapshotReader;
        StatusController = result.StatusController;
        terminalViewportController = result.terminalViewportController;
    }

    private StatusViewAssembly.Result assembleStatusViewResult() {
        return StatusViewAssembly.assemble(createStatusViewCallbacks());
    }

    private StatusViewCallbacks createStatusViewCallbacks() {
        return new StatusViewCallbacks(
                this,
                this::hasWindowFocus,
                () -> imeVisible,
                this::setImeVisible,
                () -> surfaceHostBridge,
                reason -> {
                    if (surfaceHostController != null) {
                        surfaceHostController.notifyVisibleViewport(reason);
                    }
                },
                () -> currentInstallState,
                () -> currentReadinessState);
    }

    private void assembleInteractionControllers() {
        final InteractionAssembly.Result result = assembleInteractionControllerResult();
        selectionController = result.selectionController;
        GestureStateController = result.GestureStateController;
    }

    private InteractionAssembly.Result assembleInteractionControllerResult() {
        return InteractionAssembly.assemble(createInteractionCallbacks());
    }

    private InteractionCallbacks createInteractionCallbacks() {
        return new InteractionCallbacks(
                this,
                handler,
                productSurfaceContainer,
                () -> terminalViewportController.productViewportWidthPx(),
                () -> terminalViewportController.productViewportHeightPx(),
                this::stopScrollbackFlingIfReady,
                this::refreshScrollOverlayIfReady,
                this::reevaluateFrameLoopIfReady,
                StatusController::appendEvent);
    }

    private void installInputControllers() {
        final InputAssembly.Result result = assembleInputControllerResult();
        shellInputView = result.shellInputView;
        HardwareKeyboardController = result.hardwareKeyboardController;
        ImeFocusRecoveryController = result.imeFocusRecoveryController;
    }

    private InputAssembly.Result assembleInputControllerResult() {
        return InputAssembly.assemble(createInputCallbacks());
    }

    private InputCallbacks createInputCallbacks() {
        return new InputCallbacks(
                this,
                rootView,
                getSystemService(InputMethodManager.class),
                () -> imeVisible,
                this::setImeVisible,
                this::refreshScrollOverlayIfReady,
                StatusController::updateStatus,
                StatusController::appendEvent);
    }

    private void assembleWidgetHostControllers() {
        final WidgetAssembly.Result result = assembleWidgetHostControllerResult();
        ShellStatePresenter = result.ShellStatePresenter;
        terminalChromeController = result.terminalChromeController;
        terminalViewModeController = result.terminalViewModeController;
        surfaceHostBridge = result.surfaceHostBridge;
        surfaceHostController = result.surfaceHostController;
        terminalSurfaceWidgetController = result.terminalSurfaceWidgetController;
    }

    private WidgetAssembly.Result assembleWidgetHostControllerResult() {
        return WidgetAssembly.assemble(createWidgetHost());
    }

    private WidgetAssembly.Host createWidgetHost() {
        return new WidgetAssembly.Host() {
            @Override
            public Activity activity() {
                return ZideActivity.this;
            }

            @Override
            public Handler handler() {
                return handler;
            }

            @Override
            public boolean imeVisible() {
                return imeVisible;
            }

            @Override
            public void setImeVisible(boolean visible) {
                ZideActivity.this.setImeVisible(visible);
            }

            @Override
            public View rootView() {
                return rootView;
            }

            @Override
            public View productView() {
                return productView;
            }

            @Override
            public View productReadinessBlocker() {
                return productReadinessBlocker;
            }

            @Override
            public View drawerScrim() {
                return drawerScrim;
            }

            @Override
            public View drawerEdgeHotspot() {
                return drawerEdgeHotspot;
            }

            @Override
            public View drawerSidebar() {
                return leftSidebar;
            }

            @Override
            public FrameLayout productSurfaceContainer() {
                return productSurfaceContainer;
            }

            @Override
            public ScrollOverlayView terminalScrollOverlay() {
                return terminalScrollOverlay;
            }

            @Override
            public TextView productReadinessTitle() {
                return productReadinessTitle;
            }

            @Override
            public TextView productReadinessDetail() {
                return productReadinessDetail;
            }

            @Override
            public Button productReadinessRetryButton() {
                return productReadinessRetryButton;
            }

            @Override
            public Button assistCtrlButton() {
                return assistCtrlButton;
            }

            @Override
            public Button assistAltButton() {
                return assistAltButton;
            }

            @Override
            public ShellInputView shellInputView() {
                return shellInputView;
            }

            @Override
            public SelectionController selectionController() {
                return selectionController;
            }

            @Override
            public GestureStateController GestureStateController() {
                return GestureStateController;
            }

            @Override
            public UserlandReadinessState sessionReadinessState() {
                return currentReadinessState;
            }

            @Override
            public UserlandInstallState sessionInstallState() {
                return currentInstallState;
            }

            @Override
            public boolean shouldRunFrameLoop() {
                return ZideActivity.this.shouldRunFrameLoop();
            }

            @Override
            public void refreshScrollOverlay() {
                refreshScrollOverlayIfReady();
            }

            @Override
            public void appendEvent(String event) {
                StatusController.appendEvent(event);
            }

            @Override
            public void updateStatus(String statusLabel) {
                StatusController.updateStatus(statusLabel);
            }

            @Override
            public void callNative(String event, long seq) {
                StatusController.callNative(event, seq);
            }

            @Override
            public void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state) {
                StatusController.callNativeWithSurfaceState(event, seq, state);
            }

            @Override
            public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
                return SurfaceStateSnapshotReader.read();
            }

            @Override
            public void handleShellStateEvent() {
                handleShellStateEventIfReady();
            }

            @Override
            public int productViewportHeightPx() {
                return terminalViewportController.productViewportHeightPx();
            }

            @Override
            public void reevaluateFrameLoop() {
                reevaluateFrameLoopIfReady();
            }

            @Override
            public void requestPackageDiagnostics() {
                userlandWorkflowController.runPackageDoctor();
            }

            @Override
            public void sendDirectText(String text) {
                ZideActivity.this.sendDirectText(text);
            }

            @Override
            public void notifyVisibleViewport(String reason) {
                notifyVisibleViewportIfReady(reason);
            }
        };
    }

    private RuntimeAssemblyCallbacks createRuntimeAssemblyCallbacks() {
        return new RuntimeAssemblyCallbacks(
                () -> currentInstallState,
                this::setCurrentInstallState,
                () -> currentReadinessState,
                StatusController::appendEvent,
                StatusController::updateStatus,
                () -> surfaceHostBridge,
                productReadinessBlocker,
                terminalScrollOverlay,
                selectionController,
                ShellStatePresenter,
                productFrameLoopController,
                StatusController,
                userlandSessionCoordinator,
                GestureStateController);
    }

    private void assembleSessionControllers() {
        final SessionAssembly.Result result = assembleSessionControllerResult();
        userlandSessionCoordinator = result.userlandSessionCoordinator;
        productFrameLoopController = result.frameLoopController;
    }

    private SessionAssembly.Result assembleSessionControllerResult() {
        return SessionAssembly.assemble(createSessionAssemblyCallbacks());
    }

    private SessionAssemblyCallbacks createSessionAssemblyCallbacks() {
        return new SessionAssemblyCallbacks(
                this,
                userlandRelease,
                handler,
                StatusController::appendEvent,
                StatusController::updateStatus,
                this::setCurrentReadinessState,
                this::refreshShellStateIfReady,
                this::refreshStatusTelemetryIfReady,
                this::shouldRunFrameLoop,
                this::tickFrameAndRefreshScrollOverlay);
    }

    private void assembleUserlandWorkflowControllers() {
        final WorkflowAssembly.Result result = WorkflowAssembly.assemble(
                createWorkflowAssemblyCallbacks());
        terminalRuntimeAssetsController = result.runtimeAssetsController;
        userlandWorkflowController = result.userlandWorkflowController;
    }

    private WorkflowAssemblyCallbacks createWorkflowAssemblyCallbacks() {
        return new WorkflowAssemblyCallbacks(
                this,
                handler,
                () -> userlandRelease,
                release -> userlandRelease = release,
                StatusController::appendEvent,
                this::applyInstallStateIfReady,
                this::completeInstallIfReady,
                this::failInstallIfReady,
                this::restartSessionAfterInstallIfReady,
                this::markPackageDoctorComplete);
    }

    private void assembleActivityLifecycleController() {
        terminalActivityLifecycleController = new LifecycleController(
                createLifecycleHost());
    }

    private LifecycleController.Host createLifecycleHost() {
        return new LifecycleController.Host() {
            @Override
            public boolean nativeLoaded() {
                return NativeBridge.nativeLoaded();
            }

            @Override
            public String nativeLoadError() {
                return nativeLoadError;
            }

            @Override
            public long nativeOnCreate() {
                return NativeBridge.nativeOnCreateBridge();
            }

            @Override
            public long nativeOnStart() {
                return NativeBridge.nativeOnStartBridge();
            }

            @Override
            public long nativeOnResume() {
                return NativeBridge.nativeOnResumeBridge();
            }

            @Override
            public long nativeOnPause() {
                return NativeBridge.nativeOnPauseBridge();
            }

            @Override
            public long nativeOnStop() {
                return NativeBridge.nativeOnStopBridge();
            }

            @Override
            public long nativeOnWindowFocus(boolean hasFocus) {
                return NativeBridge.nativeOnWindowFocusBridge(hasFocus);
            }

            @Override
            public void appendEvent(String event) {
                StatusController.appendEvent(event);
            }

            @Override
            public void callNative(String event, long seq) {
                StatusController.callNative(event, seq);
            }

            @Override
            public void updateStatus(String statusLabel) {
                StatusController.updateStatus(statusLabel);
            }

            @Override
            public void stopFrameLoop() {
                stopFrameLoopIfReady();
            }

            @Override
            public void refreshUserlandSessionOnPause() {
                refreshUserlandSessionIfReady();
            }

            @Override
            public void notifySurfacePause() {
                pauseSurfaceIfReady();
            }

            @Override
            public void notifySurfaceResume(
                    boolean debugRecreateSurfaceOnce,
                    boolean debugResizeSurfaceOnce,
                    boolean debugStartShellOnce) {
                resumeSurfaceIfReady(
                        debugRecreateSurfaceOnce,
                        debugResizeSurfaceOnce,
                        debugStartShellOnce);
            }
        };
    }

    private void bindAndStartUiControllers() {
        startUiStartupAssembly();
    }

    private void startUiStartupAssembly() {
        UiStartupAssembly.start(createUiStartupCallbacks());
    }

    private UiStartupCallbacks createUiStartupCallbacks() {
        return new UiStartupCallbacks(
                terminalViewportController,
                terminalChromeController,
                productReadinessRetryButton,
                () -> currentInstallState,
                () -> currentReadinessState,
                userlandWorkflowController,
                userlandSessionCoordinator,
                StatusController::appendEvent,
                StatusController::updateStatus,
                terminalRuntimeAssetsController,
                terminalViewModeController,
                surfaceHostController,
                terminalSurfaceWidgetController,
                ShellStatePresenter,
                productFrameLoopController,
                leftSidebar);
    }

    private void stopScrollbackFlingIfReady() {
        if (terminalRuntimeController != null) {
            terminalRuntimeController.stopScrollbackFling();
        }
    }

    private void refreshScrollOverlayIfReady() {
        if (terminalRuntimeController != null) {
            terminalRuntimeController.refreshScrollOverlay();
        }
    }

    private void reevaluateFrameLoopIfReady() {
        if (productFrameLoopController != null) {
            productFrameLoopController.reevaluate();
        }
    }

    private void refreshShellStateIfReady() {
        if (terminalRuntimeController != null) {
            terminalRuntimeController.refreshShellState();
        }
    }

    private void refreshStatusTelemetryIfReady() {
        if (terminalRuntimeController != null) {
            terminalRuntimeController.refreshStatusTelemetry();
        }
    }

    private void handleShellStateEventIfReady() {
        if (terminalRuntimeController != null) {
            terminalRuntimeController.handleShellStateEvent();
        }
    }

    private void applyInstallStateIfReady(UserlandInstallState installState) {
        if (terminalRuntimeController != null) {
            terminalRuntimeController.applyInstallState(installState);
        }
    }

    private void completeInstallIfReady(UserlandReadinessState readinessState) {
        setCurrentInstallState(UserlandInstallState.idle());
        setCurrentReadinessState(readinessState);
        restartSessionAfterInstallIfReady(true);
    }

    private void failInstallIfReady(UserlandInstallState installState) {
        applyInstallStateIfReady(installState);
    }

    private void restartSessionAfterInstallIfReady(boolean logRefresh) {
        if (terminalRuntimeController != null) {
            terminalRuntimeController.restartSessionAfterInstall(logRefresh);
        }
    }

    private void markPackageDoctorComplete(boolean success) {
        StatusController.recordPackageDoctorOutcome(success);
    }

    private void notifyVisibleViewportIfReady(String reason) {
        if (surfaceHostController != null) {
            surfaceHostController.notifyVisibleViewport(reason);
        }
    }

    private void stopFrameLoopIfReady() {
        if (productFrameLoopController != null) {
            productFrameLoopController.stop();
        }
    }

    private void refreshUserlandSessionIfReady() {
        if (userlandSessionCoordinator != null) {
            userlandSessionCoordinator.refreshAndApply(false);
        }
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

    private void loadInitialReadinessState() {
        currentReadinessState = userlandSessionCoordinator.loadReadinessState();
    }

    private void setCurrentInstallState(UserlandInstallState installState) {
        currentInstallState = installState;
    }

    private void setCurrentReadinessState(UserlandReadinessState readinessState) {
        currentReadinessState = readinessState;
    }

    private void setImeVisible(boolean visible) {
        imeVisible = visible;
    }

    private boolean handleHardwareDispatchKeyEventIfReady(KeyEvent event) {
        return HardwareKeyboardController != null
                && HardwareKeyboardController.handleDispatchKeyEvent(event);
    }

    private boolean shouldRunFrameLoop() {
        return terminalRuntimeController != null
                && terminalRuntimeController.shouldRunFrameLoop();
    }

    private int tickFrameAndRefreshScrollOverlay() {
        final int tick = nativeLoaded ? NativeBridge.nativeTickFrameBridge() : 0;
        refreshScrollOverlayIfReady();
        return tick;
    }

    @Override
    public void sendDirectCodepoint(int codepoint) {
        if (!canSendDirectInput())
            return;
        sendDirectCodepointToNative(codepoint);
    }

    @Override
    public void sendDirectText(String text) {
        if (!canSendDirectInput())
            return;
        sendDirectTextCodepoints(text);
    }

    @Override
    public void onInputFocusChanged(boolean hasFocus) {
        notifyInputFocusRecoveryIfReady(hasFocus);
    }

    @Override
    public void onModifierLatchChanged(ShellInputView.Host.ModifierLatchState state) {
        applyModifierLatchIfReady(state);
    }

    private boolean canSendDirectInput() {
        return nativeLoaded;
    }

    private void applyNewIntent(Intent intent) {
        setIntent(intent);
    }

    private void sendDirectCodepointToNative(int codepoint) {
        NativeBridge.nativeSendSessionCodepointBridge(codepoint);
    }

    private void sendDirectTextCodepoints(String text) {
        for (int i = 0; i < text.length();) {
            final int cp = text.codePointAt(i);
            sendDirectCodepointToNative(cp);
            i += Character.charCount(cp);
        }
    }

    private void notifyInputFocusRecoveryIfReady(boolean hasFocus) {
        if (ImeFocusRecoveryController != null) {
            ImeFocusRecoveryController.onInputFocusChanged(hasFocus);
        }
    }

    private void applyModifierLatchIfReady(ShellInputView.Host.ModifierLatchState state) {
        if (terminalChromeController != null) {
            terminalChromeController.applyModifierLatchState(state);
        }
    }

}
