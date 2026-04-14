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

    private final Supplier<Activity> activity;
    private final Supplier<android.os.Handler> handler;
    private final BooleanSupplier nativeLoaded;
    private final BooleanSupplier debugViewEnabled;
    private final Consumer<Boolean> setDebugViewEnabled;
    private final BooleanSupplier imeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final Supplier<View> rootView;
    private final Supplier<View> productView;
    private final Supplier<View> debugView;
    private final Supplier<View> productBootstrapBlocker;
    private final Supplier<View> drawerScrim;
    private final Supplier<View> drawerEdgeHotspot;
    private final Supplier<View> leftSidebar;
    private final Supplier<FrameLayout> productSurfaceContainer;
    private final Supplier<TerminalScrollOverlayView> terminalScrollOverlay;
    private final Supplier<TextView> productBootstrapTitle;
    private final Supplier<TextView> productBootstrapDetail;
    private final Supplier<Button> productBootstrapRetryButton;
    private final Supplier<Button> assistCtrlButton;
    private final Supplier<Button> assistAltButton;
    private final Supplier<ShellInputView> shellInputView;
    private final Supplier<TerminalSelectionController> selectionController;
    private final Supplier<TerminalGestureStateController> terminalGestureStateController;
    private final Supplier<SurfaceBridge> surfaceHostBridge;
    private final BooleanSupplier currentInstallStateInstalling;
    private final BooleanSupplier currentInstallStateFailed;
    private final Supplier<UserlandReadinessState> currentReadinessState;
    private final Supplier<UserlandInstallState> currentInstallState;
    private final BooleanSupplier shouldRunProductFrameLoop;
    private final Runnable refreshProductScrollOverlay;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final SurfaceLifecycleBundle surfaceLifecycleBundle;
    private final IntUnaryOperator nativeSetSessionScrollbackOffset;
    private final IntSupplier nativeFollowSessionLiveBottom;
    private final IntSupplier productViewportHeightPx;
    private final Runnable reevaluateProductFrameLoop;
    private final Runnable runPackageDoctor;
    private final Consumer<String> sendDirectText;
    private final Consumer<String> notifyVisibleViewport;
    private final Runnable refreshUserlandSession;

    public WidgetCallbacks(
            Supplier<Activity> activity,
            Supplier<android.os.Handler> handler,
            BooleanSupplier nativeLoaded,
            BooleanSupplier debugViewEnabled,
            Consumer<Boolean> setDebugViewEnabled,
            BooleanSupplier imeVisible,
            Consumer<Boolean> setImeVisible,
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
            Supplier<SurfaceBridge> surfaceHostBridge,
            BooleanSupplier currentInstallStateInstalling,
            BooleanSupplier currentInstallStateFailed,
            Supplier<UserlandReadinessState> currentReadinessState,
            Supplier<UserlandInstallState> currentInstallState,
            BooleanSupplier shouldRunProductFrameLoop,
            Runnable refreshProductScrollOverlay,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            SurfaceLifecycleBundle surfaceLifecycleBundle,
            IntUnaryOperator nativeSetSessionScrollbackOffset,
            IntSupplier nativeFollowSessionLiveBottom,
            IntSupplier productViewportHeightPx,
            Runnable reevaluateProductFrameLoop,
            Runnable runPackageDoctor,
            Consumer<String> sendDirectText,
            Consumer<String> notifyVisibleViewport,
            Runnable refreshUserlandSession) {
        this.activity = activity;
        this.handler = handler;
        this.nativeLoaded = nativeLoaded;
        this.debugViewEnabled = debugViewEnabled;
        this.setDebugViewEnabled = setDebugViewEnabled;
        this.imeVisible = imeVisible;
        this.setImeVisible = setImeVisible;
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
        this.currentInstallStateInstalling = currentInstallStateInstalling;
        this.currentInstallStateFailed = currentInstallStateFailed;
        this.currentReadinessState = currentReadinessState;
        this.currentInstallState = currentInstallState;
        this.shouldRunProductFrameLoop = shouldRunProductFrameLoop;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.surfaceLifecycleBundle = surfaceLifecycleBundle;
        this.nativeSetSessionScrollbackOffset = nativeSetSessionScrollbackOffset;
        this.nativeFollowSessionLiveBottom = nativeFollowSessionLiveBottom;
        this.productViewportHeightPx = productViewportHeightPx;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
        this.runPackageDoctor = runPackageDoctor;
        this.sendDirectText = sendDirectText;
        this.notifyVisibleViewport = notifyVisibleViewport;
        this.refreshUserlandSession = refreshUserlandSession;
    }

    @Override
    public Activity activity() {
        return activity.get();
    }

    @Override
    public android.os.Handler handler() {
        return handler.get();
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public boolean debugViewEnabled() {
        return debugViewEnabled.getAsBoolean();
    }

    @Override
    public void setDebugViewEnabled(boolean enabled) {
        setDebugViewEnabled.accept(enabled);
    }

    @Override
    public boolean imeVisible() {
        return imeVisible.getAsBoolean();
    }

    @Override
    public void setImeVisible(boolean visible) {
        setImeVisible.accept(visible);
    }

    @Override
    public View rootView() {
        return rootView.get();
    }

    @Override
    public View productView() {
        return productView.get();
    }

    @Override
    public View debugView() {
        return debugView.get();
    }

    @Override
    public View productBootstrapBlocker() {
        return productBootstrapBlocker.get();
    }

    @Override
    public View drawerScrim() {
        return drawerScrim.get();
    }

    @Override
    public View drawerEdgeHotspot() {
        return drawerEdgeHotspot.get();
    }

    @Override
    public View leftSidebar() {
        return leftSidebar.get();
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return productSurfaceContainer.get();
    }

    @Override
    public TerminalScrollOverlayView terminalScrollOverlay() {
        return terminalScrollOverlay.get();
    }

    @Override
    public TextView productBootstrapTitle() {
        return productBootstrapTitle.get();
    }

    @Override
    public TextView productBootstrapDetail() {
        return productBootstrapDetail.get();
    }

    @Override
    public Button productBootstrapRetryButton() {
        return productBootstrapRetryButton.get();
    }

    @Override
    public Button assistCtrlButton() {
        return assistCtrlButton.get();
    }

    @Override
    public Button assistAltButton() {
        return assistAltButton.get();
    }

    @Override
    public ShellInputView shellInputView() {
        return shellInputView.get();
    }

    @Override
    public TerminalSelectionController selectionController() {
        return selectionController.get();
    }

    @Override
    public TerminalGestureStateController terminalGestureStateController() {
        return terminalGestureStateController.get();
    }

    @Override
    public SurfaceBridge surfaceHostBridge() {
        return surfaceHostBridge.get();
    }

    @Override
    public boolean currentInstallStateInstalling() {
        return currentInstallStateInstalling.getAsBoolean();
    }

    @Override
    public boolean currentInstallStateFailed() {
        return currentInstallStateFailed.getAsBoolean();
    }

    @Override
    public UserlandReadinessState currentReadinessState() {
        return currentReadinessState.get();
    }

    @Override
    public UserlandInstallState currentInstallState() {
        return currentInstallState.get();
    }

    @Override
    public boolean shouldRunProductFrameLoop() {
        return shouldRunProductFrameLoop.getAsBoolean();
    }

    @Override
    public void refreshProductScrollOverlay() {
        refreshProductScrollOverlay.run();
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
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
        return nativeSetSessionScrollbackOffset.applyAsInt(offsetRows);
    }

    @Override
    public int nativeFollowSessionLiveBottom() {
        return nativeFollowSessionLiveBottom.getAsInt();
    }

    @Override
    public int productViewportHeightPx() {
        return productViewportHeightPx.getAsInt();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        reevaluateProductFrameLoop.run();
    }

    @Override
    public void runPackageDoctor() {
        runPackageDoctor.run();
    }

    @Override
    public void sendDirectText(String text) {
        sendDirectText.accept(text);
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        notifyVisibleViewport.accept(reason);
    }

    @Override
    public void refreshUserlandSession() {
        refreshUserlandSession.run();
    }
}
