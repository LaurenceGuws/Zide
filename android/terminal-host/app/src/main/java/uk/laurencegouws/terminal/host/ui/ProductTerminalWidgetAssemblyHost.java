package uk.laurencegouws.terminal.host.ui;

import android.content.Context;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.host.userland.ShellPresentationHostInputs;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.scroll.ScrollOverlayView;
import uk.laurencegouws.terminal.selection.SelectionController;

/**
 * {@link WidgetAssembly.Host} for the single product terminal slot. {@link WidgetHostAssemblyContext} carries
 * {@link ProductHostDeclaredTerminalWidgetSlot#terminalWidgetSlotForProductHarness()} for {@link #terminalWidgetSlot()} so
 * {@code ZideActivity} stays orchestration-only.
 */
public final class ProductTerminalWidgetAssemblyHost implements WidgetAssembly.Host {
    private final WidgetHostAssemblyContext c;

    public ProductTerminalWidgetAssemblyHost(WidgetHostAssemblyContext c) {
        this.c = c;
    }

    @Override
    public TerminalWidgetSlotId terminalWidgetSlot() {
        return c.hostDeclaredTerminalWidgetSlot.terminalWidgetSlotForProductHarness();
    }

    @Override
    public Context harnessContext() {
        return c.harnessContext;
    }

    @Override
    public android.os.Handler handler() {
        return c.handler;
    }

    @Override
    public SurfaceWidgetHostImeVisibility surfaceWidgetHostImeVisibility() {
        return c.productHostImeState;
    }

    @Override
    public ChromeImePolicyInput chromeImePolicyInput() {
        return c.productHostImeState.chromeImePolicyInput();
    }

    @Override
    public View rootView() {
        return c.activityViewBindings.rootView;
    }

    @Override
    public View productView() {
        return c.activityViewBindings.productView;
    }

    @Override
    public View productReadinessBlocker() {
        return c.activityViewBindings.productReadinessBlocker;
    }

    @Override
    public View drawerScrim() {
        return c.activityViewBindings.drawerScrim;
    }

    @Override
    public View drawerEdgeHotspot() {
        return c.activityViewBindings.drawerEdgeHotspot;
    }

    @Override
    public View drawerSidebar() {
        return c.activityViewBindings.leftSidebar;
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return c.activityViewBindings.productSurfaceContainer;
    }

    @Override
    public ScrollOverlayView terminalScrollOverlay() {
        return c.activityViewBindings.terminalScrollOverlay;
    }

    @Override
    public TextView productReadinessTitle() {
        return c.activityViewBindings.productReadinessTitle;
    }

    @Override
    public TextView productReadinessDetail() {
        return c.activityViewBindings.productReadinessDetail;
    }

    @Override
    public Button productReadinessRetryButton() {
        return c.activityViewBindings.productReadinessRetryButton;
    }

    @Override
    public Button assistCtrlButton() {
        return c.activityViewBindings.assistCtrlButton;
    }

    @Override
    public Button assistAltButton() {
        return c.activityViewBindings.assistAltButton;
    }

    @Override
    public ShellInputView shellInputView() {
        return c.shellInputView.get();
    }

    @Override
    public SelectionController selectionController() {
        return c.interaction.selectionController;
    }

    @Override
    public GestureStateController GestureStateController() {
        return c.interaction.GestureStateController;
    }

    @Override
    public ShellPresentationHostInputs shellPresentationHostInputs() {
        return new ShellPresentationHostInputs(
                c.currentReadinessState,
                c.currentInstallState);
    }

    @Override
    public boolean shouldRunFrameLoop() {
        return c.hostStartup.runtime.shouldRunFrameLoop();
    }

    @Override
    public void refreshScrollOverlay() {
        c.hostStartup.runtime.refreshScrollOverlayIfReady();
    }

    @Override
    public void appendEvent(String event) {
        c.statusController.appendEvent(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        c.statusController.updateStatus(statusLabel);
    }

    @Override
    public void callNative(String event, long seq) {
        c.statusController.callNative(event, seq);
    }

    @Override
    public void callNativeWithSurfaceState(
            String event,
            long seq,
            AndroidDebugFormatter.SurfaceEventSnapshot state) {
        c.statusController.callNativeWithSurfaceState(event, seq, state);
    }

    @Override
    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return c.surfaceStateSnapshotReader.read();
    }

    @Override
    public void handleShellStateEvent() {
        c.hostStartup.runtime.handleShellStateEventIfReady();
    }

    @Override
    public int productViewportHeightPx() {
        return c.terminalViewportController.productViewportHeightPx();
    }

    @Override
    public void reevaluateFrameLoop() {
        c.hostStartup.frameLoop.reevaluateFrameLoopIfReady();
    }

    @Override
    public void requestPackageDiagnostics() {
        c.userlandWorkflowController.runPackageDoctor();
    }

    @Override
    public void requestAndroidEdgeTestBinaryInstall() {
        c.userlandWorkflowController.installAndroidEdgeTestBinary();
    }

    @Override
    public void onProductTerminalTabSessionActivated(final int tabIndex) {
        c.hostStartup.runtime.restartShellSessionForProductTabIfReady(tabIndex, true);
    }

    @Override
    public void sendDirectText(String text) {
        c.sendDirectText.accept(text);
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        c.hostStartup.surface.notifyVisibleViewportIfReady(reason);
    }
}
