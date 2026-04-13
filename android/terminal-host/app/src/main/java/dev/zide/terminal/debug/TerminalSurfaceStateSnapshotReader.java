package dev.zide.terminal.debug;

import java.util.function.BooleanSupplier;
import java.util.function.IntSupplier;
import java.util.function.LongSupplier;

/** Reads one native-backed surface snapshot for debug status rendering. */
public final class TerminalSurfaceStateSnapshotReader {
    /** Host callbacks that provide native-backed renderer/surface snapshot values. */
    public interface Host {
        boolean nativeLoaded();

        long currentWindowToken();

        long currentSurfaceEpoch();

        int currentSurfaceTransition();

        int currentRendererStatus();

        long currentRendererSwapCount();

        long currentRendererBoundEpoch();

        long currentRendererContextCreateCount();

        long currentRendererSurfaceCreateCount();

        long currentRendererTextureCreateCount();

        boolean currentRendererTextureAlive();

        long currentRendererTextureUploadCount();

        long currentRendererTextureUpdateCount();

        long currentRendererTextureResizeCount();

        int currentRendererTextureWidth();

        int currentRendererTextureHeight();
    }

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

    public TerminalSurfaceStateSnapshotReader(Host host) {
        this.nativeLoaded = host::nativeLoaded;
        this.currentWindowToken = host::currentWindowToken;
        this.currentSurfaceEpoch = host::currentSurfaceEpoch;
        this.currentSurfaceTransition = host::currentSurfaceTransition;
        this.currentRendererStatus = host::currentRendererStatus;
        this.currentRendererSwapCount = host::currentRendererSwapCount;
        this.currentRendererBoundEpoch = host::currentRendererBoundEpoch;
        this.currentRendererContextCreateCount = host::currentRendererContextCreateCount;
        this.currentRendererSurfaceCreateCount = host::currentRendererSurfaceCreateCount;
        this.currentRendererTextureCreateCount = host::currentRendererTextureCreateCount;
        this.currentRendererTextureAlive = host::currentRendererTextureAlive;
        this.currentRendererTextureUploadCount = host::currentRendererTextureUploadCount;
        this.currentRendererTextureUpdateCount = host::currentRendererTextureUpdateCount;
        this.currentRendererTextureResizeCount = host::currentRendererTextureResizeCount;
        this.currentRendererTextureWidth = host::currentRendererTextureWidth;
        this.currentRendererTextureHeight = host::currentRendererTextureHeight;
    }

    public AndroidDebugFormatter.SurfaceEventSnapshot read() {
        final boolean nativeLoaded = this.nativeLoaded.getAsBoolean();
        return new AndroidDebugFormatter.SurfaceEventSnapshot(
                0,
                nativeLoaded ? currentWindowToken.getAsLong() : 0,
                nativeLoaded ? currentSurfaceEpoch.getAsLong() : 0,
                TerminalNativeStatusLabels.surfaceTransitionLabel(nativeLoaded ? currentSurfaceTransition.getAsInt() : 0),
                TerminalNativeStatusLabels.glesRendererStatusLabel(nativeLoaded ? currentRendererStatus.getAsInt() : 0),
                nativeLoaded ? currentRendererSwapCount.getAsLong() : 0,
                nativeLoaded ? currentRendererBoundEpoch.getAsLong() : 0,
                nativeLoaded ? currentRendererContextCreateCount.getAsLong() : 0,
                nativeLoaded ? currentRendererSurfaceCreateCount.getAsLong() : 0,
                nativeLoaded ? currentRendererTextureCreateCount.getAsLong() : 0,
                nativeLoaded && currentRendererTextureAlive.getAsBoolean(),
                nativeLoaded ? currentRendererTextureUploadCount.getAsLong() : 0,
                nativeLoaded ? currentRendererTextureUpdateCount.getAsLong() : 0,
                nativeLoaded ? currentRendererTextureResizeCount.getAsLong() : 0,
                nativeLoaded ? currentRendererTextureWidth.getAsInt() : 0,
                nativeLoaded ? currentRendererTextureHeight.getAsInt() : 0);
    }
}
