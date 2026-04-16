package uk.laurencegouws.terminal.debug;

import uk.laurencegouws.terminal.NativeBridge;

/** Functional callback adapter for {@link SurfaceStateSnapshotReader}. */
public final class SurfaceStateSnapshotHostCallbacks implements SurfaceStateSnapshotReader.Host {
    @Override
    public boolean nativeLoaded() {
        return NativeBridge.nativeLoaded();
    }

    @Override
    public long currentWindowToken() {
        return NativeBridge.nativeCurrentWindowTokenBridge();
    }

    @Override
    public long currentSurfaceEpoch() {
        return NativeBridge.nativeCurrentSurfaceEpochBridge();
    }

    @Override
    public int currentSurfaceTransition() {
        return NativeBridge.nativeCurrentSurfaceTransitionBridge();
    }

    @Override
    public int currentRendererStatus() {
        return NativeBridge.nativeCurrentRendererStatusBridge();
    }

    @Override
    public long currentRendererSwapCount() {
        return NativeBridge.nativeCurrentRendererSwapCountBridge();
    }

    @Override
    public long currentRendererBoundEpoch() {
        return NativeBridge.nativeCurrentRendererBoundEpochBridge();
    }

    @Override
    public long currentRendererContextCreateCount() {
        return NativeBridge.nativeCurrentRendererContextCreateCountBridge();
    }

    @Override
    public long currentRendererSurfaceCreateCount() {
        return NativeBridge.nativeCurrentRendererSurfaceCreateCountBridge();
    }

    @Override
    public long currentRendererTextureCreateCount() {
        return NativeBridge.nativeCurrentRendererTextureCreateCountBridge();
    }

    @Override
    public boolean currentRendererTextureAlive() {
        return NativeBridge.nativeCurrentRendererTextureAliveBridge();
    }

    @Override
    public long currentRendererTextureUploadCount() {
        return NativeBridge.nativeCurrentRendererTextureUploadCountBridge();
    }

    @Override
    public long currentRendererTextureUpdateCount() {
        return NativeBridge.nativeCurrentRendererTextureUpdateCountBridge();
    }

    @Override
    public long currentRendererTextureResizeCount() {
        return NativeBridge.nativeCurrentRendererTextureResizeCountBridge();
    }

    @Override
    public int currentRendererTextureWidth() {
        return NativeBridge.nativeCurrentRendererTextureWidthBridge();
    }

    @Override
    public int currentRendererTextureHeight() {
        return NativeBridge.nativeCurrentRendererTextureHeightBridge();
    }
}
