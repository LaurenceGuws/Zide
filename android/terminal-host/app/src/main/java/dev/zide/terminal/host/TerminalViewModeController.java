package dev.zide.terminal.host;

import android.view.View;
import android.widget.FrameLayout;

/** Owns Android product/debug view-mode switching policy. */
public final class TerminalViewModeController {
    /** Host callbacks for side effects that occur when view mode changes. */
    public interface Host {
        boolean debugViewEnabled();

        void setDebugViewEnabled(boolean enabled);

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void closeSidebar();

        void notifyVisibleViewport(String reason);

        void refreshProductScrollOverlay();

        void refreshShellStateForDebugView();
    }

    private final View productView;
    private final View debugView;
    private final View terminalScrollOverlay;
    private final FrameLayout productSurfaceContainer;
    private final Host host;

    public TerminalViewModeController(
            View productView,
            View debugView,
            View terminalScrollOverlay,
            FrameLayout productSurfaceContainer,
            Host host) {
        this.productView = productView;
        this.debugView = debugView;
        this.terminalScrollOverlay = terminalScrollOverlay;
        this.productSurfaceContainer = productSurfaceContainer;
        this.host = host;
    }

    public void applyCurrentViewMode() {
        final boolean debugViewEnabled = host.debugViewEnabled();
        productView.setVisibility(debugViewEnabled ? View.GONE : View.VISIBLE);
        debugView.setVisibility(debugViewEnabled ? View.VISIBLE : View.GONE);
        if (debugViewEnabled) {
            host.closeSidebar();
            terminalScrollOverlay.setVisibility(View.GONE);
        } else {
            productSurfaceContainer.post(() -> host.notifyVisibleViewport("product-view"));
            productSurfaceContainer.post(host::refreshProductScrollOverlay);
        }
    }

    public void showProductView(String eventName, String statusLabel) {
        host.setDebugViewEnabled(false);
        host.appendEvent(eventName);
        applyCurrentViewMode();
        host.updateStatus(statusLabel);
    }

    public void showDebugView(String eventName, String statusLabel) {
        host.setDebugViewEnabled(true);
        host.appendEvent(eventName);
        applyCurrentViewMode();
        host.refreshShellStateForDebugView();
        host.updateStatus(statusLabel);
    }
}
