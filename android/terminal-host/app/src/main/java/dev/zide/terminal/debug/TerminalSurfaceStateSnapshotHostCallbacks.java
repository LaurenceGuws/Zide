package dev.zide.terminal.debug;

import java.util.function.BooleanSupplier;
import java.util.function.IntSupplier;
import java.util.function.LongSupplier;

/** Functional callback adapter for {@link TerminalSurfaceStateSnapshotReader}. */
public final class TerminalSurfaceStateSnapshotHostCallbacks implements TerminalSurfaceStateSnapshotReader.Host {
    private final BooleanSupplier nativeLoaded;
    private final LongSupplier currentWindowToken;
    private final LongSupplier currentSurfaceEpoch;
    private final IntSupplier currentSurfaceTransition;
    private final IntSupplier currentRendererStatus;
    private final LongSupplier currentRendererSwapCount;
    private final LongSupplier currentRendererBoundEpoch;
    private final LongSupplier currentRendererContextCreateCount;
    private final LongSupplier currentRendererSurfaceCreateCount;
    private final LongSupplier currentRendererTextureCreateCount;
    private final BooleanSupplier currentRendererTextureAlive;
    private final LongSupplier currentRendererTextureUploadCount;
    private final LongSupplier currentRendererTextureUpdateCount;
    private final LongSupplier currentRendererTextureResizeCount;
    private final IntSupplier currentRendererTextureWidth;
    private final IntSupplier currentRendererTextureHeight;

    public TerminalSurfaceStateSnapshotHostCallbacks(
            BooleanSupplier nativeLoaded,
            LongSupplier currentWindowToken,
            LongSupplier currentSurfaceEpoch,
            IntSupplier currentSurfaceTransition,
            IntSupplier currentRendererStatus,
            LongSupplier currentRendererSwapCount,
            LongSupplier currentRendererBoundEpoch,
            LongSupplier currentRendererContextCreateCount,
            LongSupplier currentRendererSurfaceCreateCount,
            LongSupplier currentRendererTextureCreateCount,
            BooleanSupplier currentRendererTextureAlive,
            LongSupplier currentRendererTextureUploadCount,
            LongSupplier currentRendererTextureUpdateCount,
            LongSupplier currentRendererTextureResizeCount,
            IntSupplier currentRendererTextureWidth,
            IntSupplier currentRendererTextureHeight) {
        this.nativeLoaded = nativeLoaded;
        this.currentWindowToken = currentWindowToken;
        this.currentSurfaceEpoch = currentSurfaceEpoch;
        this.currentSurfaceTransition = currentSurfaceTransition;
        this.currentRendererStatus = currentRendererStatus;
        this.currentRendererSwapCount = currentRendererSwapCount;
        this.currentRendererBoundEpoch = currentRendererBoundEpoch;
        this.currentRendererContextCreateCount = currentRendererContextCreateCount;
        this.currentRendererSurfaceCreateCount = currentRendererSurfaceCreateCount;
        this.currentRendererTextureCreateCount = currentRendererTextureCreateCount;
        this.currentRendererTextureAlive = currentRendererTextureAlive;
        this.currentRendererTextureUploadCount = currentRendererTextureUploadCount;
        this.currentRendererTextureUpdateCount = currentRendererTextureUpdateCount;
        this.currentRendererTextureResizeCount = currentRendererTextureResizeCount;
        this.currentRendererTextureWidth = currentRendererTextureWidth;
        this.currentRendererTextureHeight = currentRendererTextureHeight;
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public long currentWindowToken() {
        return currentWindowToken.getAsLong();
    }

    @Override
    public long currentSurfaceEpoch() {
        return currentSurfaceEpoch.getAsLong();
    }

    @Override
    public int currentSurfaceTransition() {
        return currentSurfaceTransition.getAsInt();
    }

    @Override
    public int currentRendererStatus() {
        return currentRendererStatus.getAsInt();
    }

    @Override
    public long currentRendererSwapCount() {
        return currentRendererSwapCount.getAsLong();
    }

    @Override
    public long currentRendererBoundEpoch() {
        return currentRendererBoundEpoch.getAsLong();
    }

    @Override
    public long currentRendererContextCreateCount() {
        return currentRendererContextCreateCount.getAsLong();
    }

    @Override
    public long currentRendererSurfaceCreateCount() {
        return currentRendererSurfaceCreateCount.getAsLong();
    }

    @Override
    public long currentRendererTextureCreateCount() {
        return currentRendererTextureCreateCount.getAsLong();
    }

    @Override
    public boolean currentRendererTextureAlive() {
        return currentRendererTextureAlive.getAsBoolean();
    }

    @Override
    public long currentRendererTextureUploadCount() {
        return currentRendererTextureUploadCount.getAsLong();
    }

    @Override
    public long currentRendererTextureUpdateCount() {
        return currentRendererTextureUpdateCount.getAsLong();
    }

    @Override
    public long currentRendererTextureResizeCount() {
        return currentRendererTextureResizeCount.getAsLong();
    }

    @Override
    public int currentRendererTextureWidth() {
        return currentRendererTextureWidth.getAsInt();
    }

    @Override
    public int currentRendererTextureHeight() {
        return currentRendererTextureHeight.getAsInt();
    }
}
