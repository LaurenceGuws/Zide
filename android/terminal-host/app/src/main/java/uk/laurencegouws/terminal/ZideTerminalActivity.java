package uk.laurencegouws.terminal;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.KeyEvent;
import android.view.SurfaceHolder;
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
import uk.laurencegouws.terminal.host.lifecycle.LifecycleDebugIntentArgs;
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
    private static final boolean nativeLoaded = TerminalNativeBridge.nativeLoaded();
    private static final String nativeLoadError = TerminalNativeBridge.nativeLoadError();

    private final Handler handler = new Handler(Looper.getMainLooper());
    private TextView packageStatusText;
    private TextView productReadinessTitle;
    private TextView productReadinessDetail;
    private Button productReadinessRetryButton;
    private Button productReadinessDebugButton;
    private View rootView;
    private View productView;
    private View debugView;
    private View productReadinessBlocker;
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
        loadInitialReadinessState();
        installInputControllers();
        bindAndStartUiControllers();
        terminalActivityLifecycleController.onCreate();
    }

    @Override
    protected void onStart() {
        super.onStart();
        notifyLifecycleStart();
    }

    @Override
    protected void onResume() {
        super.onResume();
        final LifecycleDebugIntentArgs debugArgs = LifecycleDebugIntentArgs.fromIntent(getIntent());
        notifyLifecycleResume(
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
        notifyLifecyclePause();
        super.onPause();
    }

    @Override
    protected void onStop() {
        notifyLifecycleStop();
        super.onStop();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        notifyLifecycleWindowFocusChanged(hasFocus);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (handleHardwareDispatchKeyEventIfReady(event)) {
            return true;
        }
        return dispatchKeyEventToSuper(event);
    }

    private void initializeStatusAndViewControllers() {
        final StatusViewAssembly.Result result = StatusViewAssembly.assemble(
                createStatusViewCallbacks());
        packageStatusText = result.packageStatusText;
        productReadinessTitle = result.productReadinessTitle;
        productReadinessDetail = result.productReadinessDetail;
        productReadinessRetryButton = result.productReadinessRetryButton;
        productReadinessDebugButton = result.productReadinessDebugButton;
        rootView = result.rootView;
        productView = result.productView;
        debugView = result.debugView;
        productReadinessBlocker = result.productReadinessBlocker;
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
                () -> this,
                () -> handler,
                () -> productSurfaceContainer,
                () -> terminalViewportController.productViewportWidthPx(),
                () -> terminalViewportController.productViewportHeightPx(),
                () -> nativeLoaded,
                this::stopScrollbackFlingIfReady,
                this::refreshProductScrollOverlayIfReady,
                this::reevaluateProductFrameLoopIfReady,
                this::appendEvent);
    }

    private InputCallbacks createInputCallbacks() {
        return new InputCallbacks(
                () -> this,
                () -> rootView,
                () -> getSystemService(InputMethodManager.class),
                () -> imeVisible,
                visible -> imeVisible = visible,
                () -> nativeLoaded,
                this::refreshProductScrollOverlayIfReady,
                this::updateStatus,
                this::appendEvent);
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
                () -> this,
                () -> handler,
                () -> nativeLoaded,
                () -> debugViewEnabled,
                e -> debugViewEnabled = e,
                () -> imeVisible,
                v -> imeVisible = v,
                () -> rootView,
                () -> productView,
                () -> debugView,
                () -> productReadinessBlocker,
                () -> drawerScrim,
                () -> drawerEdgeHotspot,
                () -> leftSidebar,
                () -> productSurfaceContainer,
                () -> terminalScrollOverlay,
                () -> productReadinessTitle,
                () -> productReadinessDetail,
                () -> productReadinessRetryButton,
                () -> assistCtrlButton,
                () -> assistAltButton,
                () -> shellInputView,
                () -> selectionController,
                () -> terminalGestureStateController,
                () -> surfaceHostBridge,
                () -> currentReadinessState,
                () -> currentInstallState,
                this::shouldRunProductFrameLoop,
                this::refreshProductScrollOverlayIfReady,
                this::appendEvent,
                this::updateStatus,
                () -> terminalViewportController.productViewportHeightPx(),
                this::reevaluateProductFrameLoopIfReady,
                () -> userlandWorkflowController.runPackageDoctor(),
                this::sendDirectText,
                this::notifyVisibleViewportIfReady,
                this::refreshUserlandSessionIfReady,
                this::callNative,
                this::callNativeWithSurfaceState,
                () -> terminalSurfaceStateSnapshotReader.read(),
                this::handleProductShellStateEventIfReady);
    }

    private SessionAssemblyCallbacks createSessionAssemblyCallbacks() {
        return new SessionAssemblyCallbacks(
                () -> this,
                () -> userlandRelease,
                () -> handler,
                this::appendEvent,
                this::updateStatus,
                () -> nativeLoaded,
                state -> currentReadinessState = state,
                this::refreshProductShellStateIfReady,
                this::refreshDebugStatusSurfaceIfReady,
                this::shouldRunProductFrameLoop,
                this::tickProductFrameAndRefreshScrollOverlay);
    }

    private ProductRuntimeAssemblyCallbacks createProductRuntimeAssemblyCallbacks() {
        return new ProductRuntimeAssemblyCallbacks(
                () -> debugViewEnabled,
                () -> nativeLoaded,
                () -> currentInstallState,
                installState -> currentInstallState = installState,
                () -> currentReadinessState,
                this::appendEvent,
                this::updateStatus,
                () -> surfaceHostBridge != null ? surfaceHostBridge.currentSurfaceView() : null,
                () -> productReadinessBlocker,
                () -> terminalScrollOverlay,
                () -> selectionController,
                () -> productShellStatePresenter,
                () -> productFrameLoopController,
                () -> terminalStatusController,
                () -> userlandSessionCoordinator,
                () -> terminalGestureStateController);
    }

    private void assembleActivityLifecycleController() {
        terminalActivityLifecycleController = new LifecycleController(
                createLifecycleCallbacks());
    }

    private StatusViewCallbacks createStatusViewCallbacks() {
        return new StatusViewCallbacks(
                () -> this,
                () -> debugViewEnabled,
                () -> nativeLoaded,
                this::hasWindowFocus,
                () -> imeVisible,
                v -> imeVisible = v,
                () -> surfaceHostBridge,
                () -> terminalSurfaceStateSnapshotReader.read(),
                this::notifyVisibleViewportIfReady,
                () -> currentInstallState,
                () -> currentReadinessState);
    }

    private LifecycleCallbacks createLifecycleCallbacks() {
        return new LifecycleCallbacks(
                LifecycleCallbacks.LifecycleHostCallbacks.of(
                        () -> nativeLoaded,
                        () -> nativeLoadError,
                        this::appendEvent,
                        this::updateStatus,
                        this::stopProductFrameLoopIfReady,
                        this::refreshUserlandSessionIfReady,
                        this::pauseSurfaceIfReady,
                        this::resumeSurfaceIfReady),
                this::callNative);
    }

    private void bindAndStartUiControllers() {
        UiStartupAssembly.start(
                createUiStartupCallbacks());
    }

    private WorkflowAssemblyCallbacks createWorkflowAssemblyCallbacks() {
        return new WorkflowAssemblyCallbacks(
                () -> this,
                () -> handler,
                () -> userlandRelease,
                release -> userlandRelease = release,
                this::appendEvent,
                this::updateStatus,
                () -> packageStatusText,
                installState -> currentInstallState = installState,
                readinessState -> currentReadinessState = readinessState,
                this::applyInstallStateIfReady,
                this::restartSessionIfReady,
                this::showDebugViewIfReady);
    }

    private UiStartupCallbacks createUiStartupCallbacks() {
        return new UiStartupCallbacks(
                () -> terminalViewportController,
                () -> terminalChromeController,
                () -> productReadinessRetryButton,
                () -> productReadinessDebugButton,
                () -> currentInstallState,
                () -> currentReadinessState,
                () -> userlandWorkflowController,
                () -> userlandSessionCoordinator,
                this::showDebugViewIfReady,
                this::appendEvent,
                this::updateStatus,
                () -> terminalRuntimeAssetsController,
                () -> terminalViewModeController,
                () -> surfaceHostController,
                () -> terminalSurfaceWidgetController,
                () -> productShellStatePresenter,
                () -> productFrameLoopController,
                () -> leftSidebar);
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

    private void loadInitialReadinessState() {
        currentReadinessState = userlandSessionCoordinator.loadReadinessState();
    }

    private boolean handleHardwareDispatchKeyEventIfReady(KeyEvent event) {
        return terminalHardwareKeyboardController != null
                && terminalHardwareKeyboardController.handleDispatchKeyEvent(event);
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

    private void callNative(String event, long seq) {
        terminalStatusController.callNative(event, seq);
    }

    private void callNativeWithSurfaceState(
            String event,
            long seq,
            AndroidDebugFormatter.SurfaceEventSnapshot state) {
        terminalStatusController.callNativeWithSurfaceState(event, seq, state);
    }

    private boolean canSendDirectInput() {
        return nativeLoaded;
    }

    private void applyNewIntent(Intent intent) {
        setIntent(intent);
    }

    private void sendDirectCodepointToNative(int codepoint) {
        TerminalNativeBridge.nativeSendSessionCodepointBridge(codepoint);
    }

    private void sendDirectTextCodepoints(String text) {
        for (int i = 0; i < text.length();) {
            final int cp = text.codePointAt(i);
            sendDirectCodepointToNative(cp);
            i += Character.charCount(cp);
        }
    }

    private void notifyInputFocusRecoveryIfReady(boolean hasFocus) {
        if (terminalImeFocusRecoveryController != null) {
            terminalImeFocusRecoveryController.onInputFocusChanged(hasFocus);
        }
    }

    private void applyModifierLatchIfReady(ShellInputView.Host.ModifierLatchState state) {
        if (terminalChromeController != null) {
            terminalChromeController.applyModifierLatchState(state);
        }
    }

    private void notifyLifecycleStart() {
        terminalActivityLifecycleController.onStart();
    }

    private void notifyLifecyclePause() {
        terminalActivityLifecycleController.onPause();
    }

    private void notifyLifecycleStop() {
        terminalActivityLifecycleController.onStop();
    }

    private void notifyLifecycleWindowFocusChanged(boolean hasFocus) {
        terminalActivityLifecycleController.onWindowFocusChanged(hasFocus);
    }

    private void notifyLifecycleResume(
            boolean debugRecreateSurfaceOnce,
            boolean debugResizeSurfaceOnce,
            boolean debugStartShellOnce) {
        terminalActivityLifecycleController.onResume(
                debugRecreateSurfaceOnce,
                debugResizeSurfaceOnce,
                debugStartShellOnce);
    }

    private boolean dispatchKeyEventToSuper(KeyEvent event) {
        return super.dispatchKeyEvent(event);
    }

    private void updateStatus(String state) {
        terminalStatusController.updateStatus(state);
    }

    public void appendEvent(String message) {
        terminalStatusController.appendEvent(message);
    }
}
