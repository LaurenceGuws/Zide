package uk.laurencegouws.terminal.host.ui;

import android.view.View;
import android.widget.FrameLayout;

import java.util.Objects;

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
    private final FrameLayout productSurfaceContainer;
    private final AppShellNavigation appShellNavigation;
    private final TerminalWidgetSlotId terminalWidgetSlot;
    private final Host host;

    public ViewModeController(
            View productView,
            FrameLayout productSurfaceContainer,
            AppShellNavigation appShellNavigation,
            TerminalWidgetSlotId terminalWidgetSlot,
            Host host) {
        this.productView = productView;
        this.productSurfaceContainer = productSurfaceContainer;
        this.appShellNavigation = appShellNavigation;
        this.terminalWidgetSlot = Objects.requireNonNull(terminalWidgetSlot, "terminalWidgetSlot");
        this.host = host;
    }

    public void applyCurrentViewMode() {
        appShellNavigation.setActiveShellView(
                ProductTerminalSlotShellMapping.shellViewIdForTerminalSlot(terminalWidgetSlot));
        productView.setVisibility(View.VISIBLE);
        productSurfaceContainer.post(() -> {
            host.notifyVisibleViewport("product-view");
            host.refreshScrollOverlay();
        });
    }

    public void showView(String eventName, String statusLabel) {
        host.appendEvent(eventName);
        applyCurrentViewMode();
        host.updateStatus(statusLabel);
    }
}
