package uk.laurencegouws.terminal.host.surface;

/** Surface host assembly helpers. */
public final class SurfaceFactory {
    private SurfaceFactory() {
    }

    public static SurfaceBridge createSurfaceHostBridge(SurfaceBridge.Callbacks callbacks) {
        return new SurfaceBridge(callbacks);
    }
}
