package dev.zide.terminal.host;

import android.app.Activity;
import android.os.Handler;
import android.widget.FrameLayout;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

/** Functional callback adapter for {@link TerminalInteractionAssembly.Host}. */
public final class TerminalInteractionAssemblyHostCallbacks implements TerminalInteractionAssembly.Host {
    private final Supplier<Activity> activity;
    private final Supplier<Handler> handler;
    private final Supplier<FrameLayout> productSurfaceContainer;
    private final IntSupplier productViewportWidthPx;
    private final IntSupplier productViewportHeightPx;
    private final BooleanSupplier nativeLoaded;
    private final Runnable stopScrollbackFling;
    private final Runnable refreshProductScrollOverlay;
    private final Runnable reevaluateProductFrameLoop;
    private final Consumer<String> appendEvent;

    public TerminalInteractionAssemblyHostCallbacks(
            Supplier<Activity> activity,
            Supplier<Handler> handler,
            Supplier<FrameLayout> productSurfaceContainer,
            IntSupplier productViewportWidthPx,
            IntSupplier productViewportHeightPx,
            BooleanSupplier nativeLoaded,
            Runnable stopScrollbackFling,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop,
            Consumer<String> appendEvent) {
        this.activity = activity;
        this.handler = handler;
        this.productSurfaceContainer = productSurfaceContainer;
        this.productViewportWidthPx = productViewportWidthPx;
        this.productViewportHeightPx = productViewportHeightPx;
        this.nativeLoaded = nativeLoaded;
        this.stopScrollbackFling = stopScrollbackFling;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
        this.appendEvent = appendEvent;
    }

    @Override
    public Activity activity() {
        return activity.get();
    }

    @Override
    public Handler handler() {
        return handler.get();
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return productSurfaceContainer.get();
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
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
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
