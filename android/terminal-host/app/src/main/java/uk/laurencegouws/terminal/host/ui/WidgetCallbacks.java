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
    private final Activity activity;
    private final android.os.Handler handler;
    private final BooleanSupplier debugViewEnabled;
    private final Consumer<Boolean> setDebugViewEnabled;
    private final BooleanSupplier imeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final View rootView;
    private final View productView;
    private final View debugView;
    private final View productReadinessBlocker;
    private final View drawerScrim;
    private final View drawerEdgeHotspot;
    private final View leftSidebar;
    private final FrameLayout productSurfaceContainer;
    private final TerminalScrollOverlayView terminalScrollOverlay;
    private final TextView productReadinessTitle;
    private final TextView productReadinessDetail;
    private final Button productReadinessRetryButton;
    private final Button assistCtrlButton;
    private final Button assistAltButton;
    private final ShellInputView shellInputView;
    private final TerminalSelectionController selectionController;
    private final TerminalGestureStateController terminalGestureStateController;
    private final SurfaceBridge surfaceHostBridge;
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
            Activity activity,
            android.os.Handler handler,
            BooleanSupplier debugViewEnabled,
            Consumer<Boolean> setDebugViewEnabled,
            BooleanSupplier imeVisible,
            Consumer<Boolean> setImeVisible,
            View rootView,
            View productView,
            View debugView,
            View productReadinessBlocker,
            View drawerScrim,
            View drawerEdgeHotspot,
            View leftSidebar,
            FrameLayout productSurfaceContainer,
            TerminalScrollOverlayView terminalScrollOverlay,
            TextView productReadinessTitle,
            TextView productReadinessDetail,
            Button productReadinessRetryButton,
            Button assistCtrlButton,
            Button assistAltButton,
            ShellInputView shellInputView,
            TerminalSelectionController selectionController,
            TerminalGestureStateController terminalGestureStateController,
            SurfaceBridge surfaceHostBridge,
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
        return activity;
    }

    @Override
    public android.os.Handler handler() {
        return handler;
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
        return rootView;
    }

    @Override
    public View productView() {
        return productView;
    }

    @Override
    public View debugView() {
        return debugView;
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
    public View leftSidebar() {
        return leftSidebar;
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return productSurfaceContainer;
    }

    @Override
    public TerminalScrollOverlayView terminalScrollOverlay() {
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
    public TerminalSelectionController selectionController() {
        return selectionController;
    }

    @Override
    public TerminalGestureStateController terminalGestureStateController() {
        return terminalGestureStateController;
    }

    @Override
    public SurfaceBridge surfaceHostBridge() {
        return surfaceHostBridge;
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
