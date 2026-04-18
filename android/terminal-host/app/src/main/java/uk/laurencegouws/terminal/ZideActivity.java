package uk.laurencegouws.terminal;

import android.content.Context;
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

import uk.laurencegouws.terminal.scroll.ScrollOverlayView;
import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;
import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.debug.SurfaceStateSnapshotReader;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.host.lifecycle.LifecycleController;
import uk.laurencegouws.terminal.host.lifecycle.LifecycleDebugIntentArgs;
import uk.laurencegouws.terminal.host.ui.ChromeController;
import uk.laurencegouws.terminal.host.ui.ChromeImePolicyInput;
import uk.laurencegouws.terminal.host.ui.ProductHostImeState;
import uk.laurencegouws.terminal.host.ui.ProductHostKeepScreenOnPolicy;
import uk.laurencegouws.terminal.host.ui.SurfaceWidgetHostImeVisibility;
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
import uk.laurencegouws.terminal.host.ui.ActivityViewBindings;
import uk.laurencegouws.terminal.host.ui.TerminalWidgetCompositionAssembly;
import uk.laurencegouws.terminal.host.ui.TerminalWidgetInstance;
import uk.laurencegouws.terminal.host.ui.TerminalWidgetSlotId;
import uk.laurencegouws.terminal.host.ui.ProductHostStartupBundle;
import uk.laurencegouws.terminal.host.ui.ViewModeController;
import uk.laurencegouws.terminal.host.ui.UiStartupAssembly;
import uk.laurencegouws.terminal.host.ui.UiStartupCallbacks;
import uk.laurencegouws.terminal.host.ui.ViewportController;
import uk.laurencegouws.terminal.host.ui.WidgetAssembly;
import uk.laurencegouws.terminal.host.userland.ReadinessBlockerStartup;
import uk.laurencegouws.terminal.host.userland.ShellPresentationHostInputs;
import uk.laurencegouws.terminal.host.userland.WorkflowAssembly;
import uk.laurencegouws.terminal.host.userland.WorkflowAssemblyCallbacks;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.input.HardwareKeyboardController;
import uk.laurencegouws.terminal.input.ImeFocusRecoveryController;
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
 * controllers, forward lifecycle/input/surface callbacks, and expose the JNI
 * bridge. The single terminal widget instance is composed via
 * {@link uk.laurencegouws.terminal.host.ui.TerminalWidgetCompositionAssembly}
 * rather than manual {@link InteractionAssembly} + {@link WidgetAssembly} +
 * {@link uk.laurencegouws.terminal.host.ui.TerminalWidgetInstance} stitching here.
 * Terminal truth stays in Zig, while Android-specific policy belongs in the
 * package controllers below this activity.
 */
public final class ZideActivity extends android.app.Activity
        implements ShellInputView.Host {
    private static final boolean nativeLoaded = NativeBridge.nativeLoaded();
    private static final String nativeLoadError = NativeBridge.nativeLoadError();

    /**
     * Authoritative product terminal slot for this activity’s wiring (interaction,
     * widget host, composition). Multi-slot hosting would vary selection; today only
     * {@link TerminalWidgetSlotId#PRIMARY}. Assembly entry points enforce this via
     * {@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}. App-shell
     * {@link uk.laurencegouws.terminal.host.ui.ShellViewId} for this slot is resolved
     * through {@link uk.laurencegouws.terminal.host.ui.ProductTerminalSlotShellMapping#shellViewIdForTerminalSlot}
     * (today {@link uk.laurencegouws.terminal.host.ui.ShellViewId#TERMINAL}).
     */
    private static final TerminalWidgetSlotId ACTIVE_PRODUCT_TERMINAL_SLOT = TerminalWidgetSlotId.PRIMARY;

    private final Handler handler = new Handler(Looper.getMainLooper());
    /** Single IME visibility scratch for status/input/widget harness wiring. */
    private final ProductHostImeState productHostImeState = new ProductHostImeState();
    /** Default keep-screen-on for terminal host; future settings can own toggles here. */
    private final ProductHostKeepScreenOnPolicy productHostKeepScreenOnPolicy =
            new ProductHostKeepScreenOnPolicy();
    /** Shared layout/chrome view handles for widget host and other harness wiring. */
    private ActivityViewBindings activityViewBindings;
    private ShellInputView shellInputView;
    private HardwareKeyboardController HardwareKeyboardController;
    private ImeFocusRecoveryController ImeFocusRecoveryController;
    private UserlandRelease userlandRelease;
    private UserlandWorkflowController userlandWorkflowController;
    private UserlandSessionCoordinator userlandSessionCoordinator;
    private FrameLoopController productFrameLoopController;
    private ShellStatePresenter ShellStatePresenter;
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
    /** Single hosted terminal widget (surface + selection + gesture seams). */
    private TerminalWidgetInstance terminalWidget;
    private RuntimeController terminalRuntimeController;
    private LifecycleController terminalActivityLifecycleController;
    private UserlandInstallState currentInstallState = UserlandInstallState.idle();
    private UserlandReadinessState currentReadinessState;

    private final ProductHostStartupBundle hostStartup = ProductHostStartupBundle.create(
            () -> terminalRuntimeController,
            () -> productFrameLoopController,
            () -> terminalWidget == null ? null : terminalWidget.surfaceController,
            () -> userlandSessionCoordinator,
            () -> HardwareKeyboardController,
            () -> ImeFocusRecoveryController,
            () -> terminalChromeController,
            () -> StatusController,
            this::setCurrentInstallState,
            this::setCurrentReadinessState);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        applyDefaultTerminalKeepScreenOnPolicy();
        runOnCreateStartupSequence();
    }

    private void applyDefaultTerminalKeepScreenOnPolicy() {
        productHostKeepScreenOnPolicy.applyDefaultTerminalHostPolicy(getWindow());
    }

    private void runOnCreateStartupSequence() {
        initializeStatusAndViewControllers();
        final InteractionAssembly.Result interaction = InteractionAssembly.assemble(createInteractionCallbacks());
        assembleUserlandWorkflowControllers();
        assembleSessionControllers();
        applyTerminalWidgetComposition(interaction);
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
        if (hostStartup.inputChrome.handleHardwareDispatchKeyEventIfReady(event)) {
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    private void initializeStatusAndViewControllers() {
        final StatusViewAssembly.Result result = assembleStatusViewResult();
        activityViewBindings = result.activityViewBindings;
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
                productHostImeState,
                () -> terminalWidget == null ? null : terminalWidget.surfaceBridge,
                hostStartup.surface::notifyVisibleViewportIfReady,
                () -> currentInstallState,
                () -> currentReadinessState);
    }

    private InteractionCallbacks createInteractionCallbacks() {
        return new InteractionCallbacks(
                ACTIVE_PRODUCT_TERMINAL_SLOT,
                this,
                handler,
                activityViewBindings.productSurfaceContainer,
                () -> terminalViewportController.productViewportWidthPx(),
                () -> terminalViewportController.productViewportHeightPx(),
                hostStartup.runtime::stopScrollbackFlingIfReady,
                hostStartup.runtime::refreshScrollOverlayIfReady,
                hostStartup.frameLoop::reevaluateFrameLoopIfReady,
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
                this,
                activityViewBindings.rootView,
                getSystemService(InputMethodManager.class),
                productHostImeState,
                hostStartup.runtime::refreshScrollOverlayIfReady,
                StatusController::updateStatus,
                StatusController::appendEvent);
    }

    private void applyTerminalWidgetComposition(InteractionAssembly.Result interaction) {
        final WidgetAssembly.Result widgetResult = WidgetAssembly.assemble(createWidgetHost(interaction));
        ShellStatePresenter = widgetResult.ShellStatePresenter;
        terminalChromeController = widgetResult.terminalChromeController;
        terminalViewModeController = widgetResult.terminalViewModeController;
        terminalWidget = TerminalWidgetCompositionAssembly.compose(
                ACTIVE_PRODUCT_TERMINAL_SLOT, interaction, widgetResult);
    }

    private WidgetAssembly.Host createWidgetHost(final InteractionAssembly.Result interaction) {
        return new WidgetAssembly.Host() {
            @Override
            public TerminalWidgetSlotId terminalWidgetSlot() {
                return ACTIVE_PRODUCT_TERMINAL_SLOT;
            }

            @Override
            public Context harnessContext() {
                return ZideActivity.this;
            }

            @Override
            public Handler handler() {
                return handler;
            }

            @Override
            public SurfaceWidgetHostImeVisibility surfaceWidgetHostImeVisibility() {
                return productHostImeState;
            }

            @Override
            public ChromeImePolicyInput chromeImePolicyInput() {
                return productHostImeState.chromeImePolicyInput();
            }

            @Override
            public View rootView() {
                return activityViewBindings.rootView;
            }

            @Override
            public View productView() {
                return activityViewBindings.productView;
            }

            @Override
            public View productReadinessBlocker() {
                return activityViewBindings.productReadinessBlocker;
            }

            @Override
            public View drawerScrim() {
                return activityViewBindings.drawerScrim;
            }

            @Override
            public View drawerEdgeHotspot() {
                return activityViewBindings.drawerEdgeHotspot;
            }

            @Override
            public View drawerSidebar() {
                return activityViewBindings.leftSidebar;
            }

            @Override
            public FrameLayout productSurfaceContainer() {
                return activityViewBindings.productSurfaceContainer;
            }

            @Override
            public ScrollOverlayView terminalScrollOverlay() {
                return activityViewBindings.terminalScrollOverlay;
            }

            @Override
            public TextView productReadinessTitle() {
                return activityViewBindings.productReadinessTitle;
            }

            @Override
            public TextView productReadinessDetail() {
                return activityViewBindings.productReadinessDetail;
            }

            @Override
            public Button productReadinessRetryButton() {
                return activityViewBindings.productReadinessRetryButton;
            }

            @Override
            public Button assistCtrlButton() {
                return activityViewBindings.assistCtrlButton;
            }

            @Override
            public Button assistAltButton() {
                return activityViewBindings.assistAltButton;
            }

            @Override
            public ShellInputView shellInputView() {
                return shellInputView;
            }

            @Override
            public SelectionController selectionController() {
                return interaction.selectionController;
            }

            @Override
            public GestureStateController GestureStateController() {
                return interaction.GestureStateController;
            }

            @Override
            public ShellPresentationHostInputs shellPresentationHostInputs() {
                return new ShellPresentationHostInputs(
                        () -> currentReadinessState,
                        () -> currentInstallState);
            }

            @Override
            public boolean shouldRunFrameLoop() {
                return hostStartup.runtime.shouldRunFrameLoop();
            }

            @Override
            public void refreshScrollOverlay() {
                hostStartup.runtime.refreshScrollOverlayIfReady();
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
                hostStartup.runtime.handleShellStateEventIfReady();
            }

            @Override
            public int productViewportHeightPx() {
                return terminalViewportController.productViewportHeightPx();
            }

            @Override
            public void reevaluateFrameLoop() {
                hostStartup.frameLoop.reevaluateFrameLoopIfReady();
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
                hostStartup.surface.notifyVisibleViewportIfReady(reason);
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
                () -> terminalWidget.surfaceBridge,
                activityViewBindings.productReadinessBlocker,
                activityViewBindings.terminalScrollOverlay,
                terminalWidget.selectionController,
                ShellStatePresenter,
                productFrameLoopController,
                StatusController,
                userlandSessionCoordinator,
                terminalWidget.gestureStateController);
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
                hostStartup.runtime::refreshShellStateIfReady,
                hostStartup.runtime::refreshStatusTelemetryIfReady,
                hostStartup.runtime::shouldRunFrameLoop,
                () -> hostStartup.runtime.tickFrameAndRefreshScrollOverlay(nativeLoaded));
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
                hostStartup.runtime::applyInstallStateIfReady,
                hostStartup.workflowInstall::completeInstallIfReady,
                hostStartup.workflowInstall::failInstallIfReady,
                hostStartup.runtime::restartSessionAfterInstallIfReady,
                hostStartup.telemetry::markPackageDoctorCompleteIfReady);
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
                hostStartup.frameLoop.stopFrameLoopIfReady();
            }

            @Override
            public void refreshUserlandSessionOnPause() {
                hostStartup.userlandSession.refreshUserlandSessionIfReady();
            }

            @Override
            public void notifySurfacePause() {
                hostStartup.surface.pauseSurfaceIfReady();
            }

            @Override
            public void notifySurfaceResume(
                    boolean debugRecreateSurfaceOnce,
                    boolean debugResizeSurfaceOnce,
                    boolean debugStartShellOnce) {
                hostStartup.surface.resumeSurfaceIfReady(
                        debugRecreateSurfaceOnce,
                        debugResizeSurfaceOnce,
                        debugStartShellOnce);
            }
        };
    }

    private void bindAndStartUiControllers() {
        UiStartupAssembly.start(
                createUiStartupCallbacks(),
                () -> ReadinessBlockerStartup.bind(
                        activityViewBindings.productReadinessRetryButton,
                        () -> currentInstallState,
                        () -> currentReadinessState,
                        userlandWorkflowController::startInstall,
                        () -> userlandSessionCoordinator.refreshAndApply(true),
                        StatusController::appendEvent,
                        StatusController::updateStatus));
    }

    private UiStartupCallbacks createUiStartupCallbacks() {
        return new UiStartupCallbacks(
                terminalViewportController,
                terminalChromeController,
                terminalRuntimeAssetsController,
                terminalViewModeController,
                terminalWidget.surfaceController,
                terminalWidget.surfaceWidgetController,
                ShellStatePresenter,
                productFrameLoopController,
                activityViewBindings.leftSidebar);
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
        hostStartup.inputChrome.notifyInputFocusRecoveryIfReady(hasFocus);
    }

    @Override
    public void onModifierLatchChanged(ShellInputView.Host.ModifierLatchState state) {
        hostStartup.inputChrome.applyModifierLatchIfReady(state);
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

}
