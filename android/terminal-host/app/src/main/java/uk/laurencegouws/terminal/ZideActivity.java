package uk.laurencegouws.terminal;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.debug.SurfaceStateSnapshotReader;
import uk.laurencegouws.terminal.host.lifecycle.LifecycleController;
import uk.laurencegouws.terminal.host.lifecycle.LifecycleDebugIntentArgs;
import uk.laurencegouws.terminal.host.ui.ChromeController;
import uk.laurencegouws.terminal.host.ui.ProductHostImeState;
import uk.laurencegouws.terminal.host.ui.ProductHostKeepScreenOnPolicy;
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
import uk.laurencegouws.terminal.host.ui.AppShellTerminalHostSelectionContext;
import uk.laurencegouws.terminal.host.ui.ProductHostDeclaredTerminalWidgetSlot;
import uk.laurencegouws.terminal.host.ui.TerminalWidgetSlotId;
import uk.laurencegouws.terminal.host.ui.ProductHostActivityStartupWiring;
import uk.laurencegouws.terminal.host.ui.ProductHostOnCreateStartupCoordinator;
import uk.laurencegouws.terminal.host.ui.ProductHostOnCreateStartupSteps;
import uk.laurencegouws.terminal.host.ui.ProductHostStartupBundle;
import uk.laurencegouws.terminal.host.ui.ProductTerminalLifecycleHost;
import uk.laurencegouws.terminal.host.ui.ProductTerminalWidgetAssemblyHost;
import uk.laurencegouws.terminal.host.ui.ViewModeController;
import uk.laurencegouws.terminal.host.ui.WidgetHostAssemblyContext;
import uk.laurencegouws.terminal.host.ui.UiStartupAssembly;
import uk.laurencegouws.terminal.host.ui.ViewportController;
import uk.laurencegouws.terminal.host.ui.WidgetAssembly;
import uk.laurencegouws.terminal.host.userland.ReadinessBlockerStartup;
import uk.laurencegouws.terminal.host.userland.WorkflowAssembly;
import uk.laurencegouws.terminal.host.userland.WorkflowAssemblyCallbacks;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.input.HardwareKeyboardController;
import uk.laurencegouws.terminal.input.ImeFocusRecoveryController;
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

    /**
     * App-shell terminal <strong>selection</strong> for this activity’s wiring (interaction,
     * widget host, composition). {@link ProductHostDeclaredTerminalWidgetSlot#forCurrentProductHarness}
     * is the host-declared slot source; {@link AppShellTerminalHostSelectionContext#forProductHostStartup}
     * builds the startup context from it. Multi-slot hosting would vary the declared source first.
     * Assembly entry points enforce active-slot policy via
     * {@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}. Shell view identity is resolved
     * through {@link uk.laurencegouws.terminal.host.ui.ProductTerminalSlotShellMapping#shellViewIdForTerminalSlot}.
     */
    private final TerminalWidgetSlotId productHostDeclaredTerminalWidgetSlot =
            ProductHostDeclaredTerminalWidgetSlot.forCurrentProductHarness();
    private final AppShellTerminalHostSelectionContext appShellTerminalSelectionContext =
            AppShellTerminalHostSelectionContext.forProductHostStartup(productHostDeclaredTerminalWidgetSlot);

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

    private final ProductHostOnCreateStartupSteps onCreateStartupSteps = new ProductHostOnCreateStartupSteps() {
        @Override
        public void initializeStatusAndViewControllers() {
            ZideActivity.this.initializeStatusAndViewControllers();
        }

        @Override
        public InteractionAssembly.Result assembleInteraction() {
            return InteractionAssembly.assemble(createInteractionCallbacks());
        }

        @Override
        public void assembleUserlandWorkflowControllers() {
            ZideActivity.this.assembleUserlandWorkflowControllers();
        }

        @Override
        public void assembleSessionControllers() {
            ZideActivity.this.assembleSessionControllers();
        }

        @Override
        public void applyTerminalWidgetComposition(final InteractionAssembly.Result interaction) {
            ZideActivity.this.applyTerminalWidgetComposition(interaction);
        }

        @Override
        public void assembleRuntimeController() {
            ZideActivity.this.assembleRuntimeController();
        }

        @Override
        public void assembleActivityLifecycleController() {
            ZideActivity.this.assembleActivityLifecycleController();
        }

        @Override
        public void loadInitialReadinessState() {
            ZideActivity.this.loadInitialReadinessState();
        }

        @Override
        public void installInputControllers() {
            ZideActivity.this.installInputControllers();
        }

        @Override
        public void bindAndStartUiControllers() {
            ZideActivity.this.bindAndStartUiControllers();
        }

        @Override
        public void onTerminalLifecycleControllerCreate() {
            terminalActivityLifecycleController.onCreate();
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        applyDefaultTerminalKeepScreenOnPolicy();
        ProductHostOnCreateStartupCoordinator.run(onCreateStartupSteps);
    }

    private void applyDefaultTerminalKeepScreenOnPolicy() {
        productHostKeepScreenOnPolicy.applyDefaultTerminalHostPolicy(getWindow()::addFlags);
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
        return ProductHostActivityStartupWiring.statusView(
                this,
                this::hasWindowFocus,
                productHostImeState,
                hostStartup,
                () -> terminalWidget == null ? null : terminalWidget.surfaceBridge,
                () -> currentInstallState,
                () -> currentReadinessState);
    }

    private InteractionCallbacks createInteractionCallbacks() {
        return ProductHostActivityStartupWiring.interaction(
                productHostDeclaredTerminalWidgetSlot,
                this,
                handler,
                activityViewBindings.productSurfaceContainer,
                () -> terminalViewportController.productViewportWidthPx(),
                () -> terminalViewportController.productViewportHeightPx(),
                hostStartup,
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
        return ProductHostActivityStartupWiring.input(
                this,
                this,
                activityViewBindings.rootView,
                getSystemService(InputMethodManager.class),
                productHostImeState,
                hostStartup,
                StatusController::updateStatus,
                StatusController::appendEvent);
    }

    private void applyTerminalWidgetComposition(InteractionAssembly.Result interaction) {
        final WidgetAssembly.Result widgetResult =
                WidgetAssembly.assemble(createWidgetHost(interaction), appShellTerminalSelectionContext);
        ShellStatePresenter = widgetResult.harnessHost.shellStatePresenter;
        terminalChromeController = widgetResult.harnessHost.terminalChromeController;
        terminalViewModeController = widgetResult.harnessHost.terminalViewModeController;
        terminalWidget = TerminalWidgetCompositionAssembly.compose(
                productHostDeclaredTerminalWidgetSlot, interaction, widgetResult.surfaceJoin);
    }

    private WidgetAssembly.Host createWidgetHost(final InteractionAssembly.Result interaction) {
        return new ProductTerminalWidgetAssemblyHost(
                new WidgetHostAssemblyContext(
                        productHostDeclaredTerminalWidgetSlot,
                        this,
                        handler,
                        productHostImeState,
                        activityViewBindings,
                        () -> shellInputView,
                        interaction,
                        () -> currentReadinessState,
                        () -> currentInstallState,
                        hostStartup,
                        StatusController,
                        SurfaceStateSnapshotReader,
                        terminalViewportController,
                        userlandWorkflowController,
                        this::sendDirectText));
    }

    private RuntimeAssemblyCallbacks createRuntimeAssemblyCallbacks() {
        return ProductHostActivityStartupWiring.runtime(
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
        return ProductHostActivityStartupWiring.session(
                this,
                userlandRelease,
                handler,
                StatusController::appendEvent,
                StatusController::updateStatus,
                this::setCurrentReadinessState,
                hostStartup,
                nativeLoaded);
    }

    private void assembleUserlandWorkflowControllers() {
        final WorkflowAssembly.Result result = WorkflowAssembly.assemble(
                createWorkflowAssemblyCallbacks());
        terminalRuntimeAssetsController = result.runtimeAssetsController;
        userlandWorkflowController = result.userlandWorkflowController;
    }

    private WorkflowAssemblyCallbacks createWorkflowAssemblyCallbacks() {
        return ProductHostActivityStartupWiring.workflow(
                this,
                handler,
                () -> userlandRelease,
                release -> userlandRelease = release,
                StatusController::appendEvent,
                hostStartup);
    }

    private void assembleActivityLifecycleController() {
        terminalActivityLifecycleController = new LifecycleController(
                new ProductTerminalLifecycleHost(hostStartup, StatusController));
    }

    private void bindAndStartUiControllers() {
        UiStartupAssembly.start(
                ProductHostActivityStartupWiring.uiStartup(
                        terminalViewportController,
                        terminalChromeController,
                        terminalRuntimeAssetsController,
                        terminalViewModeController,
                        terminalWidget.surfaceController,
                        terminalWidget.surfaceWidgetController,
                        ShellStatePresenter,
                        productFrameLoopController,
                        activityViewBindings.leftSidebar),
                () -> ReadinessBlockerStartup.bind(
                        activityViewBindings.productReadinessRetryButton,
                        () -> currentInstallState,
                        () -> currentReadinessState,
                        userlandWorkflowController::startInstall,
                        () -> userlandSessionCoordinator.refreshAndApply(true),
                        StatusController::appendEvent,
                        StatusController::updateStatus));
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
