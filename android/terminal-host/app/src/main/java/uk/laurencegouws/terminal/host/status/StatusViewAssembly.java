package uk.laurencegouws.terminal.host.status;

import android.app.Activity;

import uk.laurencegouws.terminal.debug.SurfaceStateSnapshotReader;
import uk.laurencegouws.terminal.debug.SurfaceStateSnapshotHostCallbacks;
import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.host.ui.ActivityViewBindings;
import uk.laurencegouws.terminal.host.ui.HostImeStateAccess;
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

        HostImeStateAccess hostImeStateAccess();

        SurfaceBridge surfaceHostBridge();

        UserlandInstallState currentInstallState();

        UserlandReadinessState currentReadinessState();

        void notifyVisibleViewport(String reason);
    }

    /**
     * Immutable assembled status/view wiring result: canonical {@link ActivityViewBindings}
     * plus status/viewport controllers. Per-view accessors live on {@code activityViewBindings}
     * only (bindings-first shape).
     */
    public static final class Result {
        public final ActivityViewBindings activityViewBindings;
        public final SurfaceStateSnapshotReader SurfaceStateSnapshotReader;
        public final StatusController StatusController;
        public final ViewportController terminalViewportController;

        private Result(
                ActivityViewBindings activityViewBindings,
                SurfaceStateSnapshotReader SurfaceStateSnapshotReader,
                StatusController StatusController,
                ViewportController terminalViewportController) {
            this.activityViewBindings = activityViewBindings;
            this.SurfaceStateSnapshotReader = SurfaceStateSnapshotReader;
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
                return host.hostImeStateAccess().imeVisible();
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
                                host.hostImeStateAccess(),
                                host::notifyVisibleViewport)));
        return new Result(
                viewBindings,
                SurfaceStateSnapshotReader,
                StatusController,
                terminalViewportController);
    }
}
