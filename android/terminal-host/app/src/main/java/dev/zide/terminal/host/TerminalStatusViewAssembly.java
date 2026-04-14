package dev.zide.terminal.host;

import android.app.Activity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

import dev.zide.terminal.debug.TerminalSurfaceStateSnapshotReader;
import dev.zide.terminal.debug.TerminalSurfaceStateSnapshotHostCallbacks;
import dev.zide.terminal.debug.TerminalStatusController;
import dev.zide.terminal.host.status.StatusBridge;
import dev.zide.terminal.host.status.StatusCallbacks;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;

/** Owns activity view binding plus debug-status/viewport controller assembly. */
public final class TerminalStatusViewAssembly {
    /** Activity callbacks required for status/view assembly. */
    public interface Host {
        Activity activity();

        boolean debugViewEnabled();

        boolean nativeLoaded();

        boolean hasWindowFocusNow();

        boolean imeVisible();

        void setImeVisible(boolean visible);

        TerminalSurfaceHostBridge surfaceHostBridge();

        UserlandInstallState currentInstallState();

        UserlandReadinessState currentReadinessState();

        dev.zide.terminal.debug.AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();

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
        public final dev.zide.terminal.scroll.TerminalScrollOverlayView terminalScrollOverlay;
        public final Button assistCtrlButton;
        public final Button assistAltButton;
        public final TerminalSurfaceStateSnapshotReader terminalSurfaceStateSnapshotReader;
        public final StatusBridge terminalStatusHostBridge;
        public final TerminalStatusController terminalStatusController;
        public final TerminalViewportController terminalViewportController;

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
                dev.zide.terminal.scroll.TerminalScrollOverlayView terminalScrollOverlay,
                Button assistCtrlButton,
                Button assistAltButton,
                TerminalSurfaceStateSnapshotReader terminalSurfaceStateSnapshotReader,
                StatusBridge terminalStatusHostBridge,
                TerminalStatusController terminalStatusController,
                TerminalViewportController terminalViewportController) {
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

    private TerminalStatusViewAssembly() {
    }

    public static Result assemble(Host host) {
        final TerminalActivityViewBindings viewBindings = TerminalActivityViewBindings.from(host.activity());
        final TerminalSurfaceStateSnapshotReader terminalSurfaceStateSnapshotReader = new TerminalSurfaceStateSnapshotReader(
                new TerminalSurfaceStateSnapshotHostCallbacks(
                        host::nativeLoaded,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentWindowTokenBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentSurfaceEpochBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentSurfaceTransitionBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererStatusBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererSwapCountBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererBoundEpochBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererContextCreateCountBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererSurfaceCreateCountBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererTextureCreateCountBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererTextureAliveBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererTextureUploadCountBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererTextureUpdateCountBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererTextureResizeCountBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererTextureWidthBridge,
                        dev.zide.terminal.TerminalNativeBridge::nativeCurrentRendererTextureHeightBridge));
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
        final TerminalViewportController terminalViewportController = new TerminalViewportController(
                new TerminalViewportHostBridge(
                        viewBindings.productView,
                        viewBindings.productSurfaceContainer,
                        new TerminalViewportHostCallbacks(
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
