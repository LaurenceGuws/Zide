package uk.laurencegouws.terminal.host.interaction;

import android.app.Activity;
import android.os.Handler;
import android.widget.FrameLayout;

import java.util.function.Consumer;
import java.util.function.IntSupplier;

/** Functional callback adapter for {@link InteractionAssembly.Host}. */
public final class InteractionCallbacks implements InteractionAssembly.Host {
    private final Activity activity;
    private final Handler handler;
    private final FrameLayout productSurfaceContainer;
    private final IntSupplier productViewportWidthPx;
    private final IntSupplier productViewportHeightPx;
    private final Runnable stopScrollbackFling;
    private final Runnable refreshProductScrollOverlay;
    private final Runnable reevaluateProductFrameLoop;
    private final Consumer<String> appendEvent;

    public InteractionCallbacks(
            Activity activity,
            Handler handler,
            FrameLayout productSurfaceContainer,
            IntSupplier productViewportWidthPx,
            IntSupplier productViewportHeightPx,
            Runnable stopScrollbackFling,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop,
            Consumer<String> appendEvent) {
        this.activity = activity;
        this.handler = handler;
        this.productSurfaceContainer = productSurfaceContainer;
        this.productViewportWidthPx = productViewportWidthPx;
        this.productViewportHeightPx = productViewportHeightPx;
        this.stopScrollbackFling = stopScrollbackFling;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
        this.appendEvent = appendEvent;
    }

    @Override
    public Activity activity() {
        return activity;
    }

    @Override
    public Handler handler() {
        return handler;
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return productSurfaceContainer;
    }

    @Override
    public int productViewportWidthPx() {
        return productViewportWidthPx.getAsInt();
    }

    @Override
    public int productViewportHeightPx() {
        return productViewportHeightPx.getAsInt();
    }

    @Override
    public void stopScrollbackFling() {
        stopScrollbackFling.run();
    }

    @Override
    public void refreshProductScrollOverlay() {
        refreshProductScrollOverlay.run();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        reevaluateProductFrameLoop.run();
    }

    @Override
    public void appendEvent(String message) {
        appendEvent.accept(message);
    }
}
