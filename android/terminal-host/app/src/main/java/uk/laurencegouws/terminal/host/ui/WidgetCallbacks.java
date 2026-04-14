package uk.laurencegouws.terminal.host.ui;

import android.app.Activity;
import android.view.SurfaceHolder;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.IntUnaryOperator;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;
import uk.laurencegouws.terminal.gesture.TerminalGestureStateController;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView;
import uk.laurencegouws.terminal.selection.TerminalSelectionController;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Functional callback adapter for {@link WidgetAssembly.Host}. */
public final class WidgetCallbacks implements WidgetAssembly.Host {
    public static final class WidgetHostCallbacks {
        final Supplier<Activity> activity;
        final Supplier<android.os.Handler> handler;
        final BooleanSupplier nativeLoaded;
        final BooleanSupplier debugViewEnabled;
        final Consumer<Boolean> setDebugViewEnabled;
        final BooleanSupplier imeVisible;
        final Consumer<Boolean> setImeVisible;

        private WidgetHostCallbacks(
                Supplier<Activity> activity,
                Supplier<android.os.Handler> handler,
                BooleanSupplier nativeLoaded,
                BooleanSupplier debugViewEnabled,
                Consumer<Boolean> setDebugViewEnabled,
                BooleanSupplier imeVisible,
                Consumer<Boolean> setImeVisible) {
            this.activity = activity;
            this.handler = handler;
            this.nativeLoaded = nativeLoaded;
            this.debugViewEnabled = debugViewEnabled;
            this.setDebugViewEnabled = setDebugViewEnabled;
            this.imeVisible = imeVisible;
            this.setImeVisible = setImeVisible;
        }

        public static WidgetHostCallbacks of(
                Supplier<Activity> activity,
                Supplier<android.os.Handler> handler,
                BooleanSupplier nativeLoaded,
                BooleanSupplier debugViewEnabled,
                Consumer<Boolean> setDebugViewEnabled,
                BooleanSupplier imeVisible,
                Consumer<Boolean> setImeVisible) {
            return new WidgetHostCallbacks(
                    activity,
                    handler,
                    nativeLoaded,
                    debugViewEnabled,
                    setDebugViewEnabled,
                    imeVisible,
                    setImeVisible);
        }
    }

    public static final class WidgetViewCallbacks {
        final Supplier<View> rootView;
        final Supplier<View> productView;
        final Supplier<View> debugView;
        final Supplier<View> productReadinessBlocker;
        final Supplier<View> drawerScrim;
        final Supplier<View> drawerEdgeHotspot;
        final Supplier<View> leftSidebar;
        final Supplier<FrameLayout> productSurfaceContainer;
        final Supplier<TerminalScrollOverlayView> terminalScrollOverlay;
        final Supplier<TextView> productReadinessTitle;
        final Supplier<TextView> productReadinessDetail;
        final Supplier<Button> productReadinessRetryButton;
        final Supplier<Button> assistCtrlButton;
        final Supplier<Button> assistAltButton;
        final Supplier<ShellInputView> shellInputView;
        final Supplier<TerminalSelectionController> selectionController;
        final Supplier<TerminalGestureStateController> terminalGestureStateController;
        final Supplier<SurfaceBridge> surfaceHostBridge;

        private WidgetViewCallbacks(
                Supplier<View> rootView,
                Supplier<View> productView,
                Supplier<View> debugView,
                Supplier<View> productReadinessBlocker,
                Supplier<View> drawerScrim,
                Supplier<View> drawerEdgeHotspot,
                Supplier<View> leftSidebar,
                Supplier<FrameLayout> productSurfaceContainer,
                Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
                Supplier<TextView> productReadinessTitle,
                Supplier<TextView> productReadinessDetail,
                Supplier<Button> productReadinessRetryButton,
                Supplier<Button> assistCtrlButton,
                Supplier<Button> assistAltButton,
                Supplier<ShellInputView> shellInputView,
                Supplier<TerminalSelectionController> selectionController,
                Supplier<TerminalGestureStateController> terminalGestureStateController,
                Supplier<SurfaceBridge> surfaceHostBridge) {
            this.rootView = rootView;
            this.productView = productView;
            this.debugView = debugView;
            this.productReadinessBlocker = productReadinessBlocker;
            this.drawerScrim = drawerScrim;
            this.drawerEdgeHotspot = drawerEdgeHotspot;
            this.leftSidebar = leftSidebar;
            this.productSurfaceContainer = productSurfaceContainer;
            this.terminalScrollOverlay = terminalScrollOverlay;
            this.productReadinessTitle = productReadinessTitle;
            this.productReadinessDetail = productReadinessDetail;
            this.productReadinessRetryButton = productReadinessRetryButton;
            this.assistCtrlButton = assistCtrlButton;
            this.assistAltButton = assistAltButton;
            this.shellInputView = shellInputView;
            this.selectionController = selectionController;
            this.terminalGestureStateController = terminalGestureStateController;
            this.surfaceHostBridge = surfaceHostBridge;
        }

        public static WidgetViewCallbacks of(
                Supplier<View> rootView,
                Supplier<View> productView,
                Supplier<View> debugView,
                Supplier<View> productReadinessBlocker,
                Supplier<View> drawerScrim,
                Supplier<View> drawerEdgeHotspot,
                Supplier<View> leftSidebar,
                Supplier<FrameLayout> productSurfaceContainer,
                Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
                Supplier<TextView> productReadinessTitle,
                Supplier<TextView> productReadinessDetail,
                Supplier<Button> productReadinessRetryButton,
                Supplier<Button> assistCtrlButton,
                Supplier<Button> assistAltButton,
                Supplier<ShellInputView> shellInputView,
                Supplier<TerminalSelectionController> selectionController,
                Supplier<TerminalGestureStateController> terminalGestureStateController,
                Supplier<SurfaceBridge> surfaceHostBridge) {
            return new WidgetViewCallbacks(
                    rootView,
                    productView,
                    debugView,
                    productReadinessBlocker,
                    drawerScrim,
                    drawerEdgeHotspot,
                    leftSidebar,
                    productSurfaceContainer,
                    terminalScrollOverlay,
                    productReadinessTitle,
                    productReadinessDetail,
                    productReadinessRetryButton,
                    assistCtrlButton,
                    assistAltButton,
                    shellInputView,
                    selectionController,
                    terminalGestureStateController,
                    surfaceHostBridge);
        }
    }

    public static final class WidgetRuntimeCallbacks {
        final BooleanSupplier currentInstallStateInstalling;
        final BooleanSupplier currentInstallStateFailed;
        final Supplier<UserlandReadinessState> currentReadinessState;
        final Supplier<UserlandInstallState> currentInstallState;
        final BooleanSupplier shouldRunProductFrameLoop;
        final Runnable refreshProductScrollOverlay;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;
        final IntUnaryOperator nativeSetSessionScrollbackOffset;
        final IntSupplier nativeFollowSessionLiveBottom;
        final IntSupplier productViewportHeightPx;
        final Runnable reevaluateProductFrameLoop;
        final Runnable runPackageDoctor;
        final Consumer<String> sendDirectText;
        final Consumer<String> notifyVisibleViewport;
        final Runnable refreshUserlandSession;

        private WidgetRuntimeCallbacks(
                BooleanSupplier currentInstallStateInstalling,
                BooleanSupplier currentInstallStateFailed,
                Supplier<UserlandReadinessState> currentReadinessState,
                Supplier<UserlandInstallState> currentInstallState,
                BooleanSupplier shouldRunProductFrameLoop,
                Runnable refreshProductScrollOverlay,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                IntUnaryOperator nativeSetSessionScrollbackOffset,
                IntSupplier nativeFollowSessionLiveBottom,
                IntSupplier productViewportHeightPx,
                Runnable reevaluateProductFrameLoop,
                Runnable runPackageDoctor,
                Consumer<String> sendDirectText,
                Consumer<String> notifyVisibleViewport,
                Runnable refreshUserlandSession) {
            this.currentInstallStateInstalling = currentInstallStateInstalling;
            this.currentInstallStateFailed = currentInstallStateFailed;
            this.currentReadinessState = currentReadinessState;
            this.currentInstallState = currentInstallState;
            this.shouldRunProductFrameLoop = shouldRunProductFrameLoop;
            this.refreshProductScrollOverlay = refreshProductScrollOverlay;
            this.appendEvent = appendEvent;
            this.updateStatus = updateStatus;
            this.nativeSetSessionScrollbackOffset = nativeSetSessionScrollbackOffset;
            this.nativeFollowSessionLiveBottom = nativeFollowSessionLiveBottom;
            this.productViewportHeightPx = productViewportHeightPx;
            this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
            this.runPackageDoctor = runPackageDoctor;
            this.sendDirectText = sendDirectText;
            this.notifyVisibleViewport = notifyVisibleViewport;
            this.refreshUserlandSession = refreshUserlandSession;
        }

        public static WidgetRuntimeCallbacks of(
                BooleanSupplier currentInstallStateInstalling,
                BooleanSupplier currentInstallStateFailed,
                Supplier<UserlandReadinessState> currentReadinessState,
                Supplier<UserlandInstallState> currentInstallState,
                BooleanSupplier shouldRunProductFrameLoop,
                Runnable refreshProductScrollOverlay,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                IntUnaryOperator nativeSetSessionScrollbackOffset,
                IntSupplier nativeFollowSessionLiveBottom,
                IntSupplier productViewportHeightPx,
                Runnable reevaluateProductFrameLoop,
                Runnable runPackageDoctor,
                Consumer<String> sendDirectText,
                Consumer<String> notifyVisibleViewport,
                Runnable refreshUserlandSession) {
            return new WidgetRuntimeCallbacks(
                    currentInstallStateInstalling,
                    currentInstallStateFailed,
                    currentReadinessState,
                    currentInstallState,
                    shouldRunProductFrameLoop,
                    refreshProductScrollOverlay,
                    appendEvent,
                    updateStatus,
                    nativeSetSessionScrollbackOffset,
                    nativeFollowSessionLiveBottom,
                    productViewportHeightPx,
                    reevaluateProductFrameLoop,
                    runPackageDoctor,
                    sendDirectText,
                    notifyVisibleViewport,
                    refreshUserlandSession);
        }
    }

    private final WidgetHostCallbacks widgetHostCallbacks;
    private final WidgetViewCallbacks widgetViewCallbacks;
    private final WidgetRuntimeCallbacks widgetRuntimeCallbacks;
    private final uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.NativeEventCallback callNative;
    private final uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState;
    private final uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.SurfaceAvailableCallback nativeOnSurfaceAvailableBridge;
    private final uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.LongSupplier nativeOnSurfaceDestroyedBridge;
    private final uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.LongSupplier nativeOnSurfaceRedrawNeededBridge;
    private final uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.VisibleViewportCallback nativeOnVisibleViewportBridge;
    private final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;
    private final Consumer<String> handleProductShellStateEvent;

    public WidgetCallbacks(
            WidgetHostCallbacks widgetHostCallbacks,
            WidgetViewCallbacks widgetViewCallbacks,
            WidgetRuntimeCallbacks widgetRuntimeCallbacks,
            uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.NativeEventCallback callNative,
            uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState,
            uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.SurfaceAvailableCallback nativeOnSurfaceAvailableBridge,
            uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.LongSupplier nativeOnSurfaceDestroyedBridge,
            uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.LongSupplier nativeOnSurfaceRedrawNeededBridge,
            uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.VisibleViewportCallback nativeOnVisibleViewportBridge,
            Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
            Consumer<String> handleProductShellStateEvent) {
        this.widgetHostCallbacks = widgetHostCallbacks;
        this.widgetViewCallbacks = widgetViewCallbacks;
        this.widgetRuntimeCallbacks = widgetRuntimeCallbacks;
        this.callNative = callNative;
        this.callNativeWithSurfaceState = callNativeWithSurfaceState;
        this.nativeOnSurfaceAvailableBridge = nativeOnSurfaceAvailableBridge;
        this.nativeOnSurfaceDestroyedBridge = nativeOnSurfaceDestroyedBridge;
        this.nativeOnSurfaceRedrawNeededBridge = nativeOnSurfaceRedrawNeededBridge;
        this.nativeOnVisibleViewportBridge = nativeOnVisibleViewportBridge;
        this.currentSurfaceStateSnapshot = currentSurfaceStateSnapshot;
        this.handleProductShellStateEvent = handleProductShellStateEvent;
    }

    @Override
    public Activity activity() {
        return widgetHostCallbacks.activity.get();
    }

    @Override
    public android.os.Handler handler() {
        return widgetHostCallbacks.handler.get();
    }

    @Override
    public boolean nativeLoaded() {
        return widgetHostCallbacks.nativeLoaded.getAsBoolean();
    }

    @Override
    public boolean debugViewEnabled() {
        return widgetHostCallbacks.debugViewEnabled.getAsBoolean();
    }

    @Override
    public void setDebugViewEnabled(boolean enabled) {
        widgetHostCallbacks.setDebugViewEnabled.accept(enabled);
    }

    @Override
    public boolean imeVisible() {
        return widgetHostCallbacks.imeVisible.getAsBoolean();
    }

    @Override
    public void setImeVisible(boolean visible) {
        widgetHostCallbacks.setImeVisible.accept(visible);
    }

    @Override
    public View rootView() {
        return widgetViewCallbacks.rootView.get();
    }

    @Override
    public View productView() {
        return widgetViewCallbacks.productView.get();
    }

    @Override
    public View debugView() {
        return widgetViewCallbacks.debugView.get();
    }

    @Override
    public View productReadinessBlocker() {
        return widgetViewCallbacks.productReadinessBlocker.get();
    }

    @Override
    public View drawerScrim() {
        return widgetViewCallbacks.drawerScrim.get();
    }

    @Override
    public View drawerEdgeHotspot() {
        return widgetViewCallbacks.drawerEdgeHotspot.get();
    }

    @Override
    public View leftSidebar() {
        return widgetViewCallbacks.leftSidebar.get();
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return widgetViewCallbacks.productSurfaceContainer.get();
    }

    @Override
    public TerminalScrollOverlayView terminalScrollOverlay() {
        return widgetViewCallbacks.terminalScrollOverlay.get();
    }

    @Override
    public TextView productReadinessTitle() {
        return widgetViewCallbacks.productReadinessTitle.get();
    }

    @Override
    public TextView productReadinessDetail() {
        return widgetViewCallbacks.productReadinessDetail.get();
    }

    @Override
    public Button productReadinessRetryButton() {
        return widgetViewCallbacks.productReadinessRetryButton.get();
    }

    @Override
    public Button assistCtrlButton() {
        return widgetViewCallbacks.assistCtrlButton.get();
    }

    @Override
    public Button assistAltButton() {
        return widgetViewCallbacks.assistAltButton.get();
    }

    @Override
    public ShellInputView shellInputView() {
        return widgetViewCallbacks.shellInputView.get();
    }

    @Override
    public TerminalSelectionController selectionController() {
        return widgetViewCallbacks.selectionController.get();
    }

    @Override
    public TerminalGestureStateController terminalGestureStateController() {
        return widgetViewCallbacks.terminalGestureStateController.get();
    }

    @Override
    public SurfaceBridge surfaceHostBridge() {
        return widgetViewCallbacks.surfaceHostBridge.get();
    }

    @Override
    public boolean currentInstallStateInstalling() {
        return widgetRuntimeCallbacks.currentInstallStateInstalling.getAsBoolean();
    }

    @Override
    public boolean currentInstallStateFailed() {
        return widgetRuntimeCallbacks.currentInstallStateFailed.getAsBoolean();
    }

    @Override
    public UserlandReadinessState currentReadinessState() {
        return widgetRuntimeCallbacks.currentReadinessState.get();
    }

    @Override
    public UserlandInstallState currentInstallState() {
        return widgetRuntimeCallbacks.currentInstallState.get();
    }

    @Override
    public boolean shouldRunProductFrameLoop() {
        return widgetRuntimeCallbacks.shouldRunProductFrameLoop.getAsBoolean();
    }

    @Override
    public void refreshProductScrollOverlay() {
        widgetRuntimeCallbacks.refreshProductScrollOverlay.run();
    }

    @Override
    public void appendEvent(String event) {
        widgetRuntimeCallbacks.appendEvent.accept(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        widgetRuntimeCallbacks.updateStatus.accept(statusLabel);
    }

    @Override
    public void callNative(String event, long seq) {
        callNative.call(event, seq);
    }

    @Override
    public void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state) {
        callNativeWithSurfaceState.call(event, seq, state);
    }

    @Override
    public long nativeOnSurfaceAvailableBridge(SurfaceHolder holder, int width, int height) {
        return nativeOnSurfaceAvailableBridge.call(holder, width, height);
    }

    @Override
    public long nativeOnSurfaceDestroyedBridge() {
        return nativeOnSurfaceDestroyedBridge.getAsLong();
    }

    @Override
    public long nativeOnSurfaceRedrawNeededBridge() {
        return nativeOnSurfaceRedrawNeededBridge.getAsLong();
    }

    @Override
    public long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible) {
        return nativeOnVisibleViewportBridge.call(width, height, imeVisible);
    }

    @Override
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return currentSurfaceStateSnapshot.get();
    }

    @Override
    public void handleProductShellStateEvent(String statusLabel) {
        handleProductShellStateEvent.accept(statusLabel);
    }

    @Override
    public int nativeSetSessionScrollbackOffset(int offsetRows) {
        return widgetRuntimeCallbacks.nativeSetSessionScrollbackOffset.applyAsInt(offsetRows);
    }

    @Override
    public int nativeFollowSessionLiveBottom() {
        return widgetRuntimeCallbacks.nativeFollowSessionLiveBottom.getAsInt();
    }

    @Override
    public int productViewportHeightPx() {
        return widgetRuntimeCallbacks.productViewportHeightPx.getAsInt();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        widgetRuntimeCallbacks.reevaluateProductFrameLoop.run();
    }

    @Override
    public void runPackageDoctor() {
        widgetRuntimeCallbacks.runPackageDoctor.run();
    }

    @Override
    public void sendDirectText(String text) {
        widgetRuntimeCallbacks.sendDirectText.accept(text);
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        widgetRuntimeCallbacks.notifyVisibleViewport.accept(reason);
    }

    @Override
    public void refreshUserlandSession() {
        widgetRuntimeCallbacks.refreshUserlandSession.run();
    }
}
