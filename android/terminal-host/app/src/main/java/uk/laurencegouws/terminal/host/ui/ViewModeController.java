package uk.laurencegouws.terminal.host.ui;

import android.view.View;
import android.widget.FrameLayout;

/** Owns Android product view-mode stabilization policy. */
public final class ViewModeController {
    /** Host callbacks for side effects that occur when product view is applied. */
    public interface Host {
        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void notifyVisibleViewport(String reason);

        void refreshScrollOverlay();
    }

    private final View productView;
    private final View terminalScrollOverlay;
    private final FrameLayout productSurfaceContainer;
    private final AppShellNavigation appShellNavigation;
    private final Host host;

    public ViewModeController(
            View productView,
            View terminalScrollOverlay,
            FrameLayout productSurfaceContainer,
            AppShellNavigation appShellNavigation,
            Host host) {
        this.productView = productView;
        this.terminalScrollOverlay = terminalScrollOverlay;
        this.productSurfaceContainer = productSurfaceContainer;
        this.appShellNavigation = appShellNavigation;
        this.host = host;
    }

    public void applyCurrentViewMode() {
        appShellNavigation.setActiveShellView(ShellViewId.PRODUCT_TERMINAL);
        productView.setVisibility(View.VISIBLE);
        productSurfaceContainer.post(() -> host.notifyVisibleViewport("product-view"));
        productSurfaceContainer.post(host::refreshScrollOverlay);
    }

    public void showView(String eventName, String statusLabel) {
        host.appendEvent(eventName);
        applyCurrentViewMode();
        host.updateStatus(statusLabel);
    }
}
