package uk.laurencegouws.terminal.host.status;

import android.app.Activity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

import uk.laurencegouws.terminal.debug.SurfaceStateSnapshotReader;
import uk.laurencegouws.terminal.debug.SurfaceStateSnapshotHostCallbacks;
import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.host.ui.ActivityViewBindings;
import uk.laurencegouws.terminal.host.surface.SurfaceBridge;
import uk.laurencegouws.terminal.host.ui.ViewportController;
import uk.laurencegouws.terminal.host.ui.ViewportBridge;
import uk.laurencegouws.terminal.host.ui.ViewportCallbacks;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Owns activity view binding plus debug-status/viewport controller assembly. */
public final class StatusViewAssembly {
    /** Harness callbacks required for status/view assembly (Activity for content binding). */
    public interface Host {
        Activity activity();

        boolean nativeLoaded();

        boolean hasWindowFocus();

        boolean imeVisible();

        void setImeVisible(boolean visible);

        SurfaceBridge surfaceHostBridge();

        UserlandInstallState currentInstallState();

        UserlandReadinessState currentReadinessState();

        void notifyVisibleViewport(String reason);
    }

    /** Immutable assembled status/view wiring result. */
    public static final class Result {
        /**
         * Authoritative view lookup for this assembly; same instance used during
         * {@link #assemble} — avoids duplicate {@link ActivityViewBindings#from(android.app.Activity)}
         * calls in activity wiring.
         */
        public final ActivityViewBindings activityViewBindings;
        public final TextView productReadinessTitle;
        public final TextView productReadinessDetail;
        public final Button productReadinessRetryButton;
        public final View rootView;
        public final View productView;
        public final View productReadinessBlocker;
        public final View drawerScrim;
        public final View drawerEdgeHotspot;
        public final View leftSidebar;
        public final FrameLayout productSurfaceContainer;
        public final uk.laurencegouws.terminal.scroll.ScrollOverlayView terminalScrollOverlay;
        public final Button assistCtrlButton;
        public final Button assistAltButton;
        public final SurfaceStateSnapshotReader SurfaceStateSnapshotReader;
        public final StatusController.Host terminalStatusHost;
        public final StatusController StatusController;
        public final ViewportController terminalViewportController;

        private Result(
                ActivityViewBindings activityViewBindings,
                TextView productReadinessTitle,
                TextView productReadinessDetail,
                Button productReadinessRetryButton,
                View rootView,
                View productView,
                View productReadinessBlocker,
                View drawerScrim,
                View drawerEdgeHotspot,
                View leftSidebar,
                FrameLayout productSurfaceContainer,
                uk.laurencegouws.terminal.scroll.ScrollOverlayView terminalScrollOverlay,
                Button assistCtrlButton,
                Button assistAltButton,
                SurfaceStateSnapshotReader SurfaceStateSnapshotReader,
                StatusController.Host terminalStatusHost,
                StatusController StatusController,
                ViewportController terminalViewportController) {
            this.activityViewBindings = activityViewBindings;
            this.productReadinessTitle = productReadinessTitle;
            this.productReadinessDetail = productReadinessDetail;
            this.productReadinessRetryButton = productReadinessRetryButton;
            this.rootView = rootView;
            this.productView = productView;
            this.productReadinessBlocker = productReadinessBlocker;
            this.drawerScrim = drawerScrim;
            this.drawerEdgeHotspot = drawerEdgeHotspot;
            this.leftSidebar = leftSidebar;
            this.productSurfaceContainer = productSurfaceContainer;
            this.terminalScrollOverlay = terminalScrollOverlay;
            this.assistCtrlButton = assistCtrlButton;
            this.assistAltButton = assistAltButton;
            this.SurfaceStateSnapshotReader = SurfaceStateSnapshotReader;
            this.terminalStatusHost = terminalStatusHost;
            this.StatusController = StatusController;
            this.terminalViewportController = terminalViewportController;
        }
    }

    private StatusViewAssembly() {
    }

    public static Result assemble(Host host) {
        final ActivityViewBindings viewBindings = ActivityViewBindings.from(host.activity());
        final SurfaceStateSnapshotReader SurfaceStateSnapshotReader = new SurfaceStateSnapshotReader(
                new SurfaceStateSnapshotHostCallbacks());
        final StatusController.Host terminalStatusHost = new StatusController.Host() {
            @Override
            public boolean nativeLoaded() {
                return host.nativeLoaded();
            }

            @Override
            public boolean hasWindowFocus() {
                return host.hasWindowFocus();
            }

            @Override
            public boolean imeVisible() {
                return host.imeVisible();
            }

            @Override
            public android.view.SurfaceView surfaceView() {
                final SurfaceBridge bridge = host.surfaceHostBridge();
                return bridge != null ? bridge.currentSurfaceView() : null;
            }

            @Override
            public int visibleViewportWidth() {
                final SurfaceBridge bridge = host.surfaceHostBridge();
                return bridge != null ? bridge.currentVisibleViewportWidth() : 0;
            }

            @Override
            public int visibleViewportHeight() {
                final SurfaceBridge bridge = host.surfaceHostBridge();
                return bridge != null ? bridge.currentVisibleViewportHeight() : 0;
            }

            @Override
            public UserlandInstallState installState() {
                return host.currentInstallState();
            }

            @Override
            public UserlandReadinessState readinessState() {
                return host.currentReadinessState();
            }

            @Override
            public uk.laurencegouws.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
                return SurfaceStateSnapshotReader.read();
            }
        };
        final StatusController StatusController = new StatusController(terminalStatusHost);
        final ViewportController terminalViewportController = new ViewportController(
                new ViewportBridge(
                        viewBindings.productView,
                        viewBindings.productSurfaceContainer,
                        new ViewportCallbacks(
                                host::imeVisible,
                                host::setImeVisible,
                                host::notifyVisibleViewport)));
        return new Result(
                viewBindings,
                viewBindings.productReadinessTitle,
                viewBindings.productReadinessDetail,
                viewBindings.productReadinessRetryButton,
                viewBindings.rootView,
                viewBindings.productView,
                viewBindings.productReadinessBlocker,
                viewBindings.drawerScrim,
                viewBindings.drawerEdgeHotspot,
                viewBindings.leftSidebar,
                viewBindings.productSurfaceContainer,
                viewBindings.terminalScrollOverlay,
                viewBindings.assistCtrlButton,
                viewBindings.assistAltButton,
                SurfaceStateSnapshotReader,
                terminalStatusHost,
                StatusController,
                terminalViewportController);
    }
}
