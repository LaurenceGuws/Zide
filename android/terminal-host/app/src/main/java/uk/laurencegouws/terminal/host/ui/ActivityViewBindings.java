package uk.laurencegouws.terminal.host.ui;

import android.app.Activity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

import uk.laurencegouws.terminal.R;
import uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView;

/** Captures activity-owned view references for terminal host wiring. */
public final class ActivityViewBindings {
    public final TextView statusText;
    public final TextView packageStatusText;
    public final TextView eventLogText;
    public final TextView productBootstrapTitle;
    public final TextView productBootstrapDetail;
    public final Button productBootstrapRetryButton;
    public final Button productBootstrapDebugButton;
    public final View rootView;
    public final View productView;
    public final View debugView;
    public final View productBootstrapBlocker;
    public final View drawerScrim;
    public final View drawerEdgeHotspot;
    public final View leftSidebar;
    public final FrameLayout productSurfaceContainer;
    public final TerminalScrollOverlayView terminalScrollOverlay;
    public final Button assistCtrlButton;
    public final Button assistAltButton;

    private ActivityViewBindings(
            TextView statusText,
            TextView packageStatusText,
            TextView eventLogText,
            TextView productBootstrapTitle,
            TextView productBootstrapDetail,
            Button productBootstrapRetryButton,
            Button productBootstrapDebugButton,
            View rootView,
            View productView,
            View debugView,
            View productBootstrapBlocker,
            View drawerScrim,
            View drawerEdgeHotspot,
            View leftSidebar,
            FrameLayout productSurfaceContainer,
            TerminalScrollOverlayView terminalScrollOverlay,
            Button assistCtrlButton,
            Button assistAltButton) {
        this.statusText = statusText;
        this.packageStatusText = packageStatusText;
        this.eventLogText = eventLogText;
        this.productBootstrapTitle = productBootstrapTitle;
        this.productBootstrapDetail = productBootstrapDetail;
        this.productBootstrapRetryButton = productBootstrapRetryButton;
        this.productBootstrapDebugButton = productBootstrapDebugButton;
        this.rootView = rootView;
        this.productView = productView;
        this.debugView = debugView;
        this.productBootstrapBlocker = productBootstrapBlocker;
        this.drawerScrim = drawerScrim;
        this.drawerEdgeHotspot = drawerEdgeHotspot;
        this.leftSidebar = leftSidebar;
        this.productSurfaceContainer = productSurfaceContainer;
        this.terminalScrollOverlay = terminalScrollOverlay;
        this.assistCtrlButton = assistCtrlButton;
        this.assistAltButton = assistAltButton;
    }

    public static ActivityViewBindings from(Activity activity) {
        return new ActivityViewBindings(
                activity.findViewById(R.id.status_text),
                activity.findViewById(R.id.package_status_text),
                activity.findViewById(R.id.event_log),
                activity.findViewById(R.id.product_readiness_title),
                activity.findViewById(R.id.product_readiness_detail),
                activity.findViewById(R.id.product_readiness_retry_button),
                activity.findViewById(R.id.product_readiness_debug_button),
                activity.findViewById(R.id.root_view),
                activity.findViewById(R.id.product_view),
                activity.findViewById(R.id.debug_view),
                activity.findViewById(R.id.product_readiness_blocker),
                activity.findViewById(R.id.drawer_scrim),
                activity.findViewById(R.id.left_edge_swipe_hotspot),
                activity.findViewById(R.id.left_sidebar),
                activity.findViewById(R.id.product_surface_container),
                activity.findViewById(R.id.terminal_scroll_overlay),
                activity.findViewById(R.id.assist_ctrl_button),
                activity.findViewById(R.id.assist_alt_button));
    }
}
