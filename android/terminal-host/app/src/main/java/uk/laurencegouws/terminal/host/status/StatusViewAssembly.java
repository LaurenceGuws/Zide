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
        public final uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView terminalScrollOverlay;
        public final Button assistCtrlButton;
        public final Button assistAltButton;
        public final TerminalSurfaceStateSnapshotReader terminalSurfaceStateSnapshotReader;
        public final StatusBridge terminalStatusHostBridge;
        public final TerminalStatusController terminalStatusController;
        public final ViewportController terminalViewportController;

        private Result(
                TextView packageStatusText,
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
                uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView terminalScrollOverlay,
                Button assistCtrlButton,
                Button assistAltButton,
                TerminalSurfaceStateSnapshotReader terminalSurfaceStateSnapshotReader,
                StatusBridge terminalStatusHostBridge,
                TerminalStatusController terminalStatusController,
                ViewportController terminalViewportController) {
            this.packageStatusText = packageStatusText;
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
                new TerminalSurfaceStateSnapshotHostCallbacks(
                        host::nativeLoaded,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentWindowTokenBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentSurfaceEpochBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentSurfaceTransitionBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererStatusBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererSwapCountBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererBoundEpochBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererContextCreateCountBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererSurfaceCreateCountBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererTextureCreateCountBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererTextureAliveBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererTextureUploadCountBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererTextureUpdateCountBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererTextureResizeCountBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererTextureWidthBridge,
                        uk.laurencegouws.terminal.TerminalNativeBridge::nativeCurrentRendererTextureHeightBridge));
        final StatusBridge terminalStatusHostBridge = new StatusBridge(new StatusCallbacks(
                host::debugViewEnabled,
                host::nativeLoaded,
                host::hasWindowFocusNow,
                host::imeVisible,
                () -> host.surfaceHostBridge() != null ? host.surfaceHostBridge().currentSurfaceView() : null,
                () -> host.surfaceHostBridge() != null ? host.surfaceHostBridge().currentVisibleViewportWidth() : 0,
                () -> host.surfaceHostBridge() != null ? host.surfaceHostBridge().currentVisibleViewportHeight() : 0,
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
                viewBindings.productBootstrapTitle,
                viewBindings.productBootstrapDetail,
                viewBindings.productBootstrapRetryButton,
                viewBindings.productBootstrapDebugButton,
                viewBindings.rootView,
                viewBindings.productView,
                viewBindings.debugView,
                viewBindings.productBootstrapBlocker,
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
