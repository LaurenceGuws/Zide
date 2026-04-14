package uk.laurencegouws.terminal.host.interaction;

import android.app.Activity;
import android.os.Handler;
import android.widget.FrameLayout;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

/** Functional callback adapter for {@link InteractionAssembly.Host}. */
public final class InteractionCallbacks implements InteractionAssembly.Host {
    public static final class InteractionHostCallbacks {
        final Supplier<Activity> activity;
        final Supplier<Handler> handler;
        final Supplier<FrameLayout> productSurfaceContainer;
        final IntSupplier productViewportWidthPx;
        final IntSupplier productViewportHeightPx;

        private InteractionHostCallbacks(
                Supplier<Activity> activity,
                Supplier<Handler> handler,
                Supplier<FrameLayout> productSurfaceContainer,
                IntSupplier productViewportWidthPx,
                IntSupplier productViewportHeightPx) {
            this.activity = activity;
            this.handler = handler;
            this.productSurfaceContainer = productSurfaceContainer;
            this.productViewportWidthPx = productViewportWidthPx;
            this.productViewportHeightPx = productViewportHeightPx;
        }

        public static InteractionHostCallbacks of(
                Supplier<Activity> activity,
                Supplier<Handler> handler,
                Supplier<FrameLayout> productSurfaceContainer,
                IntSupplier productViewportWidthPx,
                IntSupplier productViewportHeightPx) {
            return new InteractionHostCallbacks(
                    activity,
                    handler,
                    productSurfaceContainer,
                    productViewportWidthPx,
                    productViewportHeightPx);
        }
    }

    public static final class InteractionRuntimeCallbacks {
        final BooleanSupplier nativeLoaded;
        final Runnable stopScrollbackFling;
        final Runnable refreshProductScrollOverlay;
        final Runnable reevaluateProductFrameLoop;
        final Consumer<String> appendEvent;

        private InteractionRuntimeCallbacks(
                BooleanSupplier nativeLoaded,
                Runnable stopScrollbackFling,
                Runnable refreshProductScrollOverlay,
                Runnable reevaluateProductFrameLoop,
                Consumer<String> appendEvent) {
            this.nativeLoaded = nativeLoaded;
            this.stopScrollbackFling = stopScrollbackFling;
            this.refreshProductScrollOverlay = refreshProductScrollOverlay;
            this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
            this.appendEvent = appendEvent;
        }

        public static InteractionRuntimeCallbacks of(
                BooleanSupplier nativeLoaded,
                Runnable stopScrollbackFling,
                Runnable refreshProductScrollOverlay,
                Runnable reevaluateProductFrameLoop,
                Consumer<String> appendEvent) {
            return new InteractionRuntimeCallbacks(
                    nativeLoaded,
                    stopScrollbackFling,
                    refreshProductScrollOverlay,
                    reevaluateProductFrameLoop,
                    appendEvent);
        }
    }

    private final InteractionHostCallbacks interactionHostCallbacks;
    private final InteractionRuntimeCallbacks interactionRuntimeCallbacks;

    public InteractionCallbacks(
            InteractionHostCallbacks interactionHostCallbacks,
            InteractionRuntimeCallbacks interactionRuntimeCallbacks) {
        this.interactionHostCallbacks = interactionHostCallbacks;
        this.interactionRuntimeCallbacks = interactionRuntimeCallbacks;
    }

    @Override
    public Activity activity() {
        return interactionHostCallbacks.activity.get();
    }

    @Override
    public Handler handler() {
        return interactionHostCallbacks.handler.get();
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return interactionHostCallbacks.productSurfaceContainer.get();
    }

    @Override
    public int productViewportWidthPx() {
        return interactionHostCallbacks.productViewportWidthPx.getAsInt();
    }

    @Override
    public int productViewportHeightPx() {
        return interactionHostCallbacks.productViewportHeightPx.getAsInt();
    }

    @Override
    public boolean nativeLoaded() {
        return interactionRuntimeCallbacks.nativeLoaded.getAsBoolean();
    }

    @Override
    public void stopScrollbackFling() {
        interactionRuntimeCallbacks.stopScrollbackFling.run();
    }

    @Override
    public void refreshProductScrollOverlay() {
        interactionRuntimeCallbacks.refreshProductScrollOverlay.run();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        interactionRuntimeCallbacks.reevaluateProductFrameLoop.run();
    }

    @Override
    public void appendEvent(String message) {
        interactionRuntimeCallbacks.appendEvent.accept(message);
    }
}
