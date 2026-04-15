package uk.laurencegouws.terminal.host.ui;

import android.app.Activity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
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
    private final Supplier<Activity> activity;
    private final Supplier<android.os.Handler> handler;
    private final BooleanSupplier debugViewEnabled;
    private final Consumer<Boolean> setDebugViewEnabled;
    private final BooleanSupplier imeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final Supplier<View> rootView;
    private final Supplier<View> productView;
    private final Supplier<View> debugView;
    private final Supplier<View> productReadinessBlocker;
    private final Supplier<View> drawerScrim;
    private final Supplier<View> drawerEdgeHotspot;
    private final Supplier<View> leftSidebar;
    private final Supplier<FrameLayout> productSurfaceContainer;
    private final Supplier<TerminalScrollOverlayView> terminalScrollOverlay;
    private final Supplier<TextView> productReadinessTitle;
    private final Supplier<TextView> productReadinessDetail;
    private final Supplier<Button> productReadinessRetryButton;
    private final Supplier<Button> assistCtrlButton;
    private final Supplier<Button> assistAltButton;
    private final Supplier<ShellInputView> shellInputView;
    private final Supplier<TerminalSelectionController> selectionController;
    private final Supplier<TerminalGestureStateController> terminalGestureStateController;
    private final Supplier<SurfaceBridge> surfaceHostBridge;
    private final Supplier<UserlandReadinessState> currentReadinessState;
    private final Supplier<UserlandInstallState> currentInstallState;
    private final BooleanSupplier shouldRunProductFrameLoop;
    private final Runnable refreshProductScrollOverlay;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final IntSupplier productViewportHeightPx;
    private final Runnable reevaluateProductFrameLoop;
    private final Runnable runPackageDoctor;
    private final Consumer<String> sendDirectText;
    private final Consumer<String> notifyVisibleViewport;
    private final Runnable refreshUserlandSession;
    private final uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.NativeEventCallback callNative;
    private final uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState;
    private final Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot;
    private final Consumer<String> handleProductShellStateEvent;

    public WidgetCallbacks(
            Supplier<Activity> activity,
            Supplier<android.os.Handler> handler,
            BooleanSupplier debugViewEnabled,
            Consumer<Boolean> setDebugViewEnabled,
            BooleanSupplier imeVisible,
            Consumer<Boolean> setImeVisible,
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
            Supplier<SurfaceBridge> surfaceHostBridge,
            Supplier<UserlandReadinessState> currentReadinessState,
            Supplier<UserlandInstallState> currentInstallState,
            BooleanSupplier shouldRunProductFrameLoop,
            Runnable refreshProductScrollOverlay,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            IntSupplier productViewportHeightPx,
            Runnable reevaluateProductFrameLoop,
            Runnable runPackageDoctor,
            Consumer<String> sendDirectText,
            Consumer<String> notifyVisibleViewport,
            Runnable refreshUserlandSession,
            uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.NativeEventCallback callNative,
            uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks.NativeSurfaceEventCallback callNativeWithSurfaceState,
            Supplier<AndroidDebugFormatter.SurfaceEventSnapshot> currentSurfaceStateSnapshot,
            Consumer<String> handleProductShellStateEvent) {
        this.activity = activity;
        this.handler = handler;
        this.debugViewEnabled = debugViewEnabled;
        this.setDebugViewEnabled = setDebugViewEnabled;
        this.imeVisible = imeVisible;
        this.setImeVisible = setImeVisible;
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
        this.currentReadinessState = currentReadinessState;
        this.currentInstallState = currentInstallState;
        this.shouldRunProductFrameLoop = shouldRunProductFrameLoop;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.productViewportHeightPx = productViewportHeightPx;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
        this.runPackageDoctor = runPackageDoctor;
        this.sendDirectText = sendDirectText;
        this.notifyVisibleViewport = notifyVisibleViewport;
        this.refreshUserlandSession = refreshUserlandSession;
        this.callNative = callNative;
        this.callNativeWithSurfaceState = callNativeWithSurfaceState;
        this.currentSurfaceStateSnapshot = currentSurfaceStateSnapshot;
        this.handleProductShellStateEvent = handleProductShellStateEvent;
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
    public View productReadinessBlocker() {
        return productReadinessBlocker.get();
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
    public TextView productReadinessTitle() {
        return productReadinessTitle.get();
    }

    @Override
    public TextView productReadinessDetail() {
        return productReadinessDetail.get();
    }

    @Override
    public Button productReadinessRetryButton() {
        return productReadinessRetryButton.get();
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
        return currentInstallState.get().isInstalling();
    }

    @Override
    public boolean currentInstallStateFailed() {
        return currentInstallState.get().isFailed();
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
        callNative.call(event, seq);
    }

    @Override
    public void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state) {
        callNativeWithSurfaceState.call(event, seq, state);
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
