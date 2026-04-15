package uk.laurencegouws.terminal.host.status;

import android.app.Activity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

import uk.laurencegouws.terminal.debug.TerminalSurfaceStateSnapshotReader;
import uk.laurencegouws.terminal.debug.TerminalSurfaceStateSnapshotHostCallbacks;
import uk.laurencegouws.terminal.debug.TerminalStatusController;
import uk.laurencegouws.terminal.host.ui.ActivityViewBindings;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.host.ui.ViewportController;
import uk.laurencegouws.terminal.host.ui.ViewportBridge;
import uk.laurencegouws.terminal.host.ui.ViewportCallbacks;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Owns activity view binding plus debug-status/viewport controller assembly. */
public final class StatusViewAssembly {
    /** Activity callbacks required for status/view assembly. */
    public interface Host {
        Activity activity();

        boolean debugViewEnabled();

        boolean nativeLoaded();

        boolean hasWindowFocusNow();

        boolean imeVisible();

        void setImeVisible(boolean visible);

        SurfaceBridge surfaceHostBridge();

        UserlandInstallState currentInstallState();

        UserlandReadinessState currentReadinessState();

        uk.laurencegouws.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();

        void notifyVisibleViewport(String reason);
    }

    /** Immutable assembled status/view wiring result. */
    public static final class Result {
        public final TextView packageStatusText;
        public final TextView productReadinessTitle;
        public final TextView productReadinessDetail;
        public final Button productReadinessRetryButton;
        public final Button productReadinessDebugButton;
        public final View rootView;
        public final View productView;
        public final View debugView;
        public final View productReadinessBlocker;
        public final View drawerScrim;
        public final View drawerEdgeHotspot;
        public final View leftSidebar;
        public final FrameLayout productSurfaceContainer;
        public final uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView terminalScrollOverlay;
        public final Button assistCtrlButton;
        public final Button assistAltButton;
        public final TerminalSurfaceStateSnapshotReader terminalSurfaceStateSnapshotReader;
        public final StatusBridge terminalStatusHostBridge;
        public final TerminalStatusController terminalStatusController;
        public final ViewportController terminalViewportController;

        private Result(
                TextView packageStatusText,
                TextView productReadinessTitle,
                TextView productReadinessDetail,
                Button productReadinessRetryButton,
                Button productReadinessDebugButton,
                View rootView,
                View productView,
                View debugView,
                View productReadinessBlocker,
                View drawerScrim,
                View drawerEdgeHotspot,
                View leftSidebar,
                FrameLayout productSurfaceContainer,
                uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView terminalScrollOverlay,
                Button assistCtrlButton,
                Button assistAltButton,
                TerminalSurfaceStateSnapshotReader terminalSurfaceStateSnapshotReader,
                StatusBridge terminalStatusHostBridge,
                TerminalStatusController terminalStatusController,
                ViewportController terminalViewportController) {
            this.packageStatusText = packageStatusText;
            this.productReadinessTitle = productReadinessTitle;
            this.productReadinessDetail = productReadinessDetail;
            this.productReadinessRetryButton = productReadinessRetryButton;
            this.productReadinessDebugButton = productReadinessDebugButton;
            this.rootView = rootView;
            this.productView = productView;
            this.debugView = debugView;
            this.productReadinessBlocker = productReadinessBlocker;
            this.drawerScrim = drawerScrim;
            this.drawerEdgeHotspot = drawerEdgeHotspot;
            this.leftSidebar = leftSidebar;
            this.productSurfaceContainer = productSurfaceContainer;
            this.terminalScrollOverlay = terminalScrollOverlay;
            this.assistCtrlButton = assistCtrlButton;
            this.assistAltButton = assistAltButton;
            this.terminalSurfaceStateSnapshotReader = terminalSurfaceStateSnapshotReader;
            this.terminalStatusHostBridge = terminalStatusHostBridge;
            this.terminalStatusController = terminalStatusController;
            this.terminalViewportController = terminalViewportController;
        }
    }

    private StatusViewAssembly() {
    }

    public static Result assemble(Host host) {
        final ActivityViewBindings viewBindings = ActivityViewBindings.from(host.activity());
        final TerminalSurfaceStateSnapshotReader terminalSurfaceStateSnapshotReader = new TerminalSurfaceStateSnapshotReader(
                new TerminalSurfaceStateSnapshotHostCallbacks(host::nativeLoaded));
        final StatusBridge terminalStatusHostBridge = new StatusBridge(new StatusCallbacks(
                host::debugViewEnabled,
                host::nativeLoaded,
                host::hasWindowFocusNow,
                host::imeVisible,
                host::surfaceHostBridge,
                host::currentInstallState,
                host::currentReadinessState,
                host::currentSurfaceStateSnapshot));
        final TerminalStatusController terminalStatusController = new TerminalStatusController(
                viewBindings.statusText,
                viewBindings.eventLogText,
                terminalStatusHostBridge);
        final ViewportController terminalViewportController = new ViewportController(
                new ViewportBridge(
                        viewBindings.productView,
                        viewBindings.productSurfaceContainer,
                        new ViewportCallbacks(
                                host::imeVisible,
                                host::setImeVisible,
                                host::notifyVisibleViewport)));
        return new Result(
                viewBindings.packageStatusText,
                viewBindings.productReadinessTitle,
                viewBindings.productReadinessDetail,
                viewBindings.productReadinessRetryButton,
                viewBindings.productReadinessDebugButton,
                viewBindings.rootView,
                viewBindings.productView,
                viewBindings.debugView,
                viewBindings.productReadinessBlocker,
                viewBindings.drawerScrim,
                viewBindings.drawerEdgeHotspot,
                viewBindings.leftSidebar,
                viewBindings.productSurfaceContainer,
                viewBindings.terminalScrollOverlay,
                viewBindings.assistCtrlButton,
                viewBindings.assistAltButton,
                terminalSurfaceStateSnapshotReader,
                terminalStatusHostBridge,
                terminalStatusController,
                terminalViewportController);
    }
}
