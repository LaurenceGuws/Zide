package uk.laurencegouws.terminal.host.surface;

import java.util.function.Consumer;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.NativeBridge;

/** Functional callback adapter for {@link SurfaceWidgetController}. */
public final class SurfaceWidgetCallbacks implements SurfaceWidgetController.Host {
    private final IntSupplier productViewportHeightPx;
    private final Consumer<String> appendEvent;
    private final Runnable refreshScrollOverlay;
    private final Runnable reevaluateFrameLoop;

    public SurfaceWidgetCallbacks(
            IntSupplier productViewportHeightPx,
            Consumer<String> appendEvent,
            Runnable refreshScrollOverlay,
            Runnable reevaluateFrameLoop) {
        this.productViewportHeightPx = productViewportHeightPx;
        this.appendEvent = appendEvent;
        this.refreshScrollOverlay = refreshScrollOverlay;
        this.reevaluateFrameLoop = reevaluateFrameLoop;
    }

    @Override
    public boolean nativeLoaded() {
        return NativeBridge.nativeLoaded();
    }

    @Override
    public int setShellScrollbackOffset(int offsetRows) {
        return NativeBridge.nativeSetSessionScrollbackOffsetBridge(offsetRows);
    }

    @Override
    public int followShellLiveBottom() {
        return NativeBridge.nativeFollowSessionLiveBottomBridge();
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
    public void refreshScrollOverlay() {
        refreshScrollOverlay.run();
    }

    @Override
    public void reevaluateFrameLoop() {
        reevaluateFrameLoop.run();
    }
}
