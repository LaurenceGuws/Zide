package uk.laurencegouws.terminal.host.surface;

import java.util.function.Consumer;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.TerminalNativeBridge;

/** Functional callback adapter for {@link SurfaceWidgetController}. */
public final class SurfaceWidgetCallbacks implements SurfaceWidgetController.Host {
    private final IntSupplier productViewportHeightPx;
    private final Consumer<String> appendEvent;
    private final Runnable refreshProductScrollOverlay;
    private final Runnable reevaluateProductFrameLoop;

    public SurfaceWidgetCallbacks(
            IntSupplier productViewportHeightPx,
            Consumer<String> appendEvent,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop) {
        this.productViewportHeightPx = productViewportHeightPx;
        this.appendEvent = appendEvent;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
    }

    @Override
    public boolean nativeLoaded() {
        return TerminalNativeBridge.nativeLoaded();
    }

    @Override
    public int setShellScrollbackOffset(int offsetRows) {
        return TerminalNativeBridge.nativeSetSessionScrollbackOffsetBridge(offsetRows);
    }

    @Override
    public int followShellLiveBottom() {
        return TerminalNativeBridge.nativeFollowSessionLiveBottomBridge();
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
