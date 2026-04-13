package dev.zide.terminal.host;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.IntUnaryOperator;

/** Functional callback adapter for {@link TerminalSurfaceWidgetController}. */
public final class TerminalSurfaceWidgetHostCallbacks implements TerminalSurfaceWidgetController.Host {
    private final BooleanSupplier nativeLoaded;
    private final IntUnaryOperator setShellScrollbackOffset;
    private final IntSupplier followShellLiveBottom;
    private final IntSupplier productViewportHeightPx;
    private final Consumer<String> appendEvent;
    private final Runnable refreshProductScrollOverlay;
    private final Runnable reevaluateProductFrameLoop;

    public TerminalSurfaceWidgetHostCallbacks(
            BooleanSupplier nativeLoaded,
            IntUnaryOperator setShellScrollbackOffset,
            IntSupplier followShellLiveBottom,
            IntSupplier productViewportHeightPx,
            Consumer<String> appendEvent,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop) {
        this.nativeLoaded = nativeLoaded;
        this.setShellScrollbackOffset = setShellScrollbackOffset;
        this.followShellLiveBottom = followShellLiveBottom;
        this.productViewportHeightPx = productViewportHeightPx;
        this.appendEvent = appendEvent;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public int setShellScrollbackOffset(int offsetRows) {
        return setShellScrollbackOffset.applyAsInt(offsetRows);
    }

    @Override
    public int followShellLiveBottom() {
        return followShellLiveBottom.getAsInt();
    }

    @Override
    public int productViewportHeightPx() {
        return productViewportHeightPx.getAsInt();
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public void refreshProductScrollOverlay() {
        refreshProductScrollOverlay.run();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        reevaluateProductFrameLoop.run();
    }
}
