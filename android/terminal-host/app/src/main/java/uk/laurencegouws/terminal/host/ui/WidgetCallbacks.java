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
    public static final class WidgetHostBundle {
        final Supplier<Activity> activity;
        final Supplier<android.os.Handler> handler;
        final BooleanSupplier nativeLoaded;
        final BooleanSupplier debugViewEnabled;
        final Consumer<Boolean> setDebugViewEnabled;
        final BooleanSupplier imeVisible;
        final Consumer<Boolean> setImeVisible;

        private WidgetHostBundle(
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

        public static WidgetHostBundle of(
                Supplier<Activity> activity,
                Supplier<android.os.Handler> handler,
                BooleanSupplier nativeLoaded,
                BooleanSupplier debugViewEnabled,
                Consumer<Boolean> setDebugViewEnabled,
                BooleanSupplier imeVisible,
                Consumer<Boolean> setImeVisible) {
            return new WidgetHostBundle(
                    activity,
                    handler,
                    nativeLoaded,
                    debugViewEnabled,
                    setDebugViewEnabled,
                    imeVisible,
                    setImeVisible);
        }
    }

    public static final class WidgetViewBundle {
        final Supplier<View> rootView;
        final Supplier<View> productView;
        final Supplier<View> debugView;
        final Supplier<View> productBootstrapBlocker;
        final Supplier<View> drawerScrim;
        final Supplier<View> drawerEdgeHotspot;
        final Supplier<View> leftSidebar;
        final Supplier<FrameLayout> productSurfaceContainer;
        final Supplier<TerminalScrollOverlayView> terminalScrollOverlay;
        final Supplier<TextView> productBootstrapTitle;
        final Supplier<TextView> productBootstrapDetail;
        final Supplier<Button> productBootstrapRetryButton;
        final Supplier<Button> assistCtrlButton;
        final Supplier<Button> assistAltButton;
        final Supplier<ShellInputView> shellInputView;
        final Supplier<TerminalSelectionController> selectionController;
        final Supplier<TerminalGestureStateController> terminalGestureStateController;
        final Supplier<SurfaceBridge> surfaceHostBridge;

        private WidgetViewBundle(
                Supplier<View> rootView,
                Supplier<View> productView,
                Supplier<View> debugView,
                Supplier<View> productBootstrapBlocker,
                Supplier<View> drawerScrim,
                Supplier<View> drawerEdgeHotspot,
                Supplier<View> leftSidebar,
                Supplier<FrameLayout> productSurfaceContainer,
                Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
                Supplier<TextView> productBootstrapTitle,
                Supplier<TextView> productBootstrapDetail,
                Supplier<Button> productBootstrapRetryButton,
                Supplier<Button> assistCtrlButton,
                Supplier<Button> assistAltButton,
                Supplier<ShellInputView> shellInputView,
                Supplier<TerminalSelectionController> selectionController,
                Supplier<TerminalGestureStateController> terminalGestureStateController,
                Supplier<SurfaceBridge> surfaceHostBridge) {
            this.rootView = rootView;
            this.productView = productView;
            this.debugView = debugView;
            this.productBootstrapBlocker = productBootstrapBlocker;
            this.drawerScrim = drawerScrim;
            this.drawerEdgeHotspot = drawerEdgeHotspot;
            this.leftSidebar = leftSidebar;
            this.productSurfaceContainer = productSurfaceContainer;
            this.terminalScrollOverlay = terminalScrollOverlay;
            this.productBootstrapTitle = productBootstrapTitle;
            this.productBootstrapDetail = productBootstrapDetail;
            this.productBootstrapRetryButton = productBootstrapRetryButton;
            this.assistCtrlButton = assistCtrlButton;
            this.assistAltButton = assistAltButton;
            this.shellInputView = shellInputView;
            this.selectionController = selectionController;
            this.terminalGestureStateController = terminalGestureStateController;
            this.surfaceHostBridge = surfaceHostBridge;
        }

        public static WidgetViewBundle of(
                Supplier<View> rootView,
                Supplier<View> productView,
                Supplier<View> debugView,
                Supplier<View> productBootstrapBlocker,
                Supplier<View> drawerScrim,
                Supplier<View> drawerEdgeHotspot,
                Supplier<View> leftSidebar,
                Supplier<FrameLayout> productSurfaceContainer,
                Supplier<TerminalScrollOverlayView> terminalScrollOverlay,
                Supplier<TextView> productBootstrapTitle,
                Supplier<TextView> productBootstrapDetail,
                Supplier<Button> productBootstrapRetryButton,
                Supplier<Button> assistCtrlButton,
                Supplier<Button> assistAltButton,
                Supplier<ShellInputView> shellInputView,
                Supplier<TerminalSelectionController> selectionController,
                Supplier<TerminalGestureStateController> terminalGestureStateController,
                Supplier<SurfaceBridge> surfaceHostBridge) {
            return new WidgetViewBundle(
                    rootView,
                    productView,
                    debugView,
                    productBootstrapBlocker,
                    drawerScrim,
                    drawerEdgeHotspot,
                    leftSidebar,
                    productSurfaceContainer,
                    terminalScrollOverlay,
                    productBootstrapTitle,
                    productBootstrapDetail,
                    productBootstrapRetryButton,
                    assistCtrlButton,
                    assistAltButton,
                    shellInputView,
                    selectionController,
                    terminalGestureStateController,
                    surfaceHostBridge);
        }
    }

    public static final class WidgetRuntimeBundle {
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

        private WidgetRuntimeBundle(
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

        public static WidgetRuntimeBundle of(
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
            return new WidgetRuntimeBundle(
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

    public static final class SurfaceLifecycleBundle {
        final SurfaceLifecycleCallbacks.NativeEventCallback callNative;
        final SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState;
        final SurfaceLifecycleCallbacks.SurfaceAvailableCallback nativeOnSurfaceAvailableBridge;
        final SurfaceLifecycleCallbacks.LongSupplier nativeOnSurfaceDestroyedBridge;
        final SurfaceLifecycleCallbacks.LongSupplier nativeOnSurfaceRedrawNeededBridge;
        final SurfaceLifecycleCallbacks.VisibleViewportCallback nativeOnVisibleViewportBridge;
        final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;
        final Consumer<String> handleProductShellStateEvent;

        private SurfaceLifecycleBundle(
                SurfaceLifecycleCallbacks.NativeEventCallback callNative,
                SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState,
                SurfaceLifecycleCallbacks.SurfaceAvailableCallback nativeOnSurfaceAvailableBridge,
                SurfaceLifecycleCallbacks.LongSupplier nativeOnSurfaceDestroyedBridge,
                SurfaceLifecycleCallbacks.LongSupplier nativeOnSurfaceRedrawNeededBridge,
                SurfaceLifecycleCallbacks.VisibleViewportCallback nativeOnVisibleViewportBridge,
                Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
                Consumer<String> handleProductShellStateEvent) {
            this.callNative = callNative;
            this.callNativeWithSurfaceState = callNativeWithSurfaceState;
            this.nativeOnSurfaceAvailableBridge = nativeOnSurfaceAvailableBridge;
            this.nativeOnSurfaceDestroyedBridge = nativeOnSurfaceDestroyedBridge;
            this.nativeOnSurfaceRedrawNeededBridge = nativeOnSurfaceRedrawNeededBridge;
            this.nativeOnVisibleViewportBridge = nativeOnVisibleViewportBridge;
            this.currentSurfaceStateSnapshot = currentSurfaceStateSnapshot;
            this.handleProductShellStateEvent = handleProductShellStateEvent;
        }

        public static SurfaceLifecycleBundle of(
                SurfaceLifecycleCallbacks.NativeEventCallback callNative,
                SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState,
                SurfaceLifecycleCallbacks.SurfaceAvailableCallback nativeOnSurfaceAvailableBridge,
                SurfaceLifecycleCallbacks.LongSupplier nativeOnSurfaceDestroyedBridge,
                SurfaceLifecycleCallbacks.LongSupplier nativeOnSurfaceRedrawNeededBridge,
                SurfaceLifecycleCallbacks.VisibleViewportCallback nativeOnVisibleViewportBridge,
                Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
                Consumer<String> handleProductShellStateEvent) {
            return new SurfaceLifecycleBundle(
                    callNative,
                    callNativeWithSurfaceState,
                    nativeOnSurfaceAvailableBridge,
                    nativeOnSurfaceDestroyedBridge,
                    nativeOnSurfaceRedrawNeededBridge,
                    nativeOnVisibleViewportBridge,
                    currentSurfaceStateSnapshot,
                    handleProductShellStateEvent);
        }
    }

    private final WidgetHostBundle widgetHostBundle;
    private final WidgetViewBundle widgetViewBundle;
    private final WidgetRuntimeBundle widgetRuntimeBundle;
    private final SurfaceLifecycleBundle surfaceLifecycleBundle;

    public WidgetCallbacks(
            WidgetHostBundle widgetHostBundle,
            WidgetViewBundle widgetViewBundle,
            WidgetRuntimeBundle widgetRuntimeBundle,
            SurfaceLifecycleBundle surfaceLifecycleBundle) {
        this.widgetHostBundle = widgetHostBundle;
        this.widgetViewBundle = widgetViewBundle;
        this.widgetRuntimeBundle = widgetRuntimeBundle;
        this.surfaceLifecycleBundle = surfaceLifecycleBundle;
    }

    @Override
    public Activity activity() {
        return widgetHostBundle.activity.get();
    }

    @Override
    public android.os.Handler handler() {
        return widgetHostBundle.handler.get();
    }

    @Override
    public boolean nativeLoaded() {
        return widgetHostBundle.nativeLoaded.getAsBoolean();
    }

    @Override
    public boolean debugViewEnabled() {
        return widgetHostBundle.debugViewEnabled.getAsBoolean();
    }

    @Override
    public void setDebugViewEnabled(boolean enabled) {
        widgetHostBundle.setDebugViewEnabled.accept(enabled);
    }

    @Override
    public boolean imeVisible() {
        return widgetHostBundle.imeVisible.getAsBoolean();
    }

    @Override
    public void setImeVisible(boolean visible) {
        widgetHostBundle.setImeVisible.accept(visible);
    }

    @Override
    public View rootView() {
        return widgetViewBundle.rootView.get();
    }

    @Override
    public View productView() {
        return widgetViewBundle.productView.get();
    }

    @Override
    public View debugView() {
        return widgetViewBundle.debugView.get();
    }

    @Override
    public View productBootstrapBlocker() {
        return widgetViewBundle.productBootstrapBlocker.get();
    }

    @Override
    public View drawerScrim() {
        return widgetViewBundle.drawerScrim.get();
    }

    @Override
    public View drawerEdgeHotspot() {
        return widgetViewBundle.drawerEdgeHotspot.get();
    }

    @Override
    public View leftSidebar() {
        return widgetViewBundle.leftSidebar.get();
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return widgetViewBundle.productSurfaceContainer.get();
    }

    @Override
    public TerminalScrollOverlayView terminalScrollOverlay() {
        return widgetViewBundle.terminalScrollOverlay.get();
    }

    @Override
    public TextView productBootstrapTitle() {
        return widgetViewBundle.productBootstrapTitle.get();
    }

    @Override
    public TextView productBootstrapDetail() {
        return widgetViewBundle.productBootstrapDetail.get();
    }

    @Override
    public Button productBootstrapRetryButton() {
        return widgetViewBundle.productBootstrapRetryButton.get();
    }

    @Override
    public Button assistCtrlButton() {
        return widgetViewBundle.assistCtrlButton.get();
    }

    @Override
    public Button assistAltButton() {
        return widgetViewBundle.assistAltButton.get();
    }

    @Override
    public ShellInputView shellInputView() {
        return widgetViewBundle.shellInputView.get();
    }

    @Override
    public TerminalSelectionController selectionController() {
        return widgetViewBundle.selectionController.get();
    }

    @Override
    public TerminalGestureStateController terminalGestureStateController() {
        return widgetViewBundle.terminalGestureStateController.get();
    }

    @Override
    public SurfaceBridge surfaceHostBridge() {
        return widgetViewBundle.surfaceHostBridge.get();
    }

    @Override
    public boolean currentInstallStateInstalling() {
        return widgetRuntimeBundle.currentInstallStateInstalling.getAsBoolean();
    }

    @Override
    public boolean currentInstallStateFailed() {
        return widgetRuntimeBundle.currentInstallStateFailed.getAsBoolean();
    }

    @Override
    public UserlandReadinessState currentReadinessState() {
        return widgetRuntimeBundle.currentReadinessState.get();
    }

    @Override
    public UserlandInstallState currentInstallState() {
        return widgetRuntimeBundle.currentInstallState.get();
    }

    @Override
    public boolean shouldRunProductFrameLoop() {
        return widgetRuntimeBundle.shouldRunProductFrameLoop.getAsBoolean();
    }

    @Override
    public void refreshProductScrollOverlay() {
        widgetRuntimeBundle.refreshProductScrollOverlay.run();
    }

    @Override
    public void appendEvent(String event) {
        widgetRuntimeBundle.appendEvent.accept(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        widgetRuntimeBundle.updateStatus.accept(statusLabel);
    }

    @Override
    public void callNative(String event, long seq) {
        surfaceLifecycleBundle.callNative.call(event, seq);
    }

    @Override
    public void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state) {
        surfaceLifecycleBundle.callNativeWithSurfaceState.call(event, seq, state);
    }

    @Override
    public long nativeOnSurfaceAvailableBridge(SurfaceHolder holder, int width, int height) {
        return surfaceLifecycleBundle.nativeOnSurfaceAvailableBridge.call(holder, width, height);
    }

    @Override
    public long nativeOnSurfaceDestroyedBridge() {
        return surfaceLifecycleBundle.nativeOnSurfaceDestroyedBridge.getAsLong();
    }

    @Override
    public long nativeOnSurfaceRedrawNeededBridge() {
        return surfaceLifecycleBundle.nativeOnSurfaceRedrawNeededBridge.getAsLong();
    }

    @Override
    public long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible) {
        return surfaceLifecycleBundle.nativeOnVisibleViewportBridge.call(width, height, imeVisible);
    }

    @Override
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return surfaceLifecycleBundle.currentSurfaceStateSnapshot.get();
    }

    @Override
    public void handleProductShellStateEvent(String statusLabel) {
        surfaceLifecycleBundle.handleProductShellStateEvent.accept(statusLabel);
    }

    @Override
    public int nativeSetSessionScrollbackOffset(int offsetRows) {
        return widgetRuntimeBundle.nativeSetSessionScrollbackOffset.applyAsInt(offsetRows);
    }

    @Override
    public int nativeFollowSessionLiveBottom() {
        return widgetRuntimeBundle.nativeFollowSessionLiveBottom.getAsInt();
    }

    @Override
    public int productViewportHeightPx() {
        return widgetRuntimeBundle.productViewportHeightPx.getAsInt();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        widgetRuntimeBundle.reevaluateProductFrameLoop.run();
    }

    @Override
    public void runPackageDoctor() {
        widgetRuntimeBundle.runPackageDoctor.run();
    }

    @Override
    public void sendDirectText(String text) {
        widgetRuntimeBundle.sendDirectText.accept(text);
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        widgetRuntimeBundle.notifyVisibleViewport.accept(reason);
    }

    @Override
    public void refreshUserlandSession() {
        widgetRuntimeBundle.refreshUserlandSession.run();
    }
}
