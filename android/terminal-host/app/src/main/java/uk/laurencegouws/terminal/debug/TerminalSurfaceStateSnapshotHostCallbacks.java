package uk.laurencegouws.terminal.debug;

import java.util.function.BooleanSupplier;

import uk.laurencegouws.terminal.TerminalNativeBridge;

/** Functional callback adapter for {@link TerminalSurfaceStateSnapshotReader}. */
public final class TerminalSurfaceStateSnapshotHostCallbacks implements TerminalSurfaceStateSnapshotReader.Host {
    private final BooleanSupplier nativeLoaded;

    public TerminalSurfaceStateSnapshotHostCallbacks(BooleanSupplier nativeLoaded) {
        this.nativeLoaded = nativeLoaded;
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public long currentWindowToken() {
        return TerminalNativeBridge.nativeCurrentWindowTokenBridge();
    }

    @Override
    public long currentSurfaceEpoch() {
        return TerminalNativeBridge.nativeCurrentSurfaceEpochBridge();
    }

    @Override
    public int currentSurfaceTransition() {
        return TerminalNativeBridge.nativeCurrentSurfaceTransitionBridge();
    }

    @Override
    public int currentRendererStatus() {
        return TerminalNativeBridge.nativeCurrentRendererStatusBridge();
    }

    @Override
    public long currentRendererSwapCount() {
        return TerminalNativeBridge.nativeCurrentRendererSwapCountBridge();
    }

    @Override
    public long currentRendererBoundEpoch() {
        return TerminalNativeBridge.nativeCurrentRendererBoundEpochBridge();
    }

    @Override
    public long currentRendererContextCreateCount() {
        return TerminalNativeBridge.nativeCurrentRendererContextCreateCountBridge();
    }

    @Override
    public long currentRendererSurfaceCreateCount() {
        return TerminalNativeBridge.nativeCurrentRendererSurfaceCreateCountBridge();
    }

    @Override
    public long currentRendererTextureCreateCount() {
        return TerminalNativeBridge.nativeCurrentRendererTextureCreateCountBridge();
    }

    @Override
    public boolean currentRendererTextureAlive() {
        return TerminalNativeBridge.nativeCurrentRendererTextureAliveBridge();
    }

    @Override
    public long currentRendererTextureUploadCount() {
        return TerminalNativeBridge.nativeCurrentRendererTextureUploadCountBridge();
    }

    @Override
    public long currentRendererTextureUpdateCount() {
        return TerminalNativeBridge.nativeCurrentRendererTextureUpdateCountBridge();
    }

    @Override
    public long currentRendererTextureResizeCount() {
        return TerminalNativeBridge.nativeCurrentRendererTextureResizeCountBridge();
    }

    @Override
    public int currentRendererTextureWidth() {
        return TerminalNativeBridge.nativeCurrentRendererTextureWidthBridge();
    }

    @Override
    public int currentRendererTextureHeight() {
        return TerminalNativeBridge.nativeCurrentRendererTextureHeightBridge();
    }
}
