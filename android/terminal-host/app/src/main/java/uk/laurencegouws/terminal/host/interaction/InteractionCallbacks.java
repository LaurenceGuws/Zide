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
    public static final class InteractionHostBundle {
        final Supplier<Activity> activity;
        final Supplier<Handler> handler;
        final Supplier<FrameLayout> productSurfaceContainer;
        final IntSupplier productViewportWidthPx;
        final IntSupplier productViewportHeightPx;

        private InteractionHostBundle(
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

        public static InteractionHostBundle of(
                Supplier<Activity> activity,
                Supplier<Handler> handler,
                Supplier<FrameLayout> productSurfaceContainer,
                IntSupplier productViewportWidthPx,
                IntSupplier productViewportHeightPx) {
            return new InteractionHostBundle(
                    activity,
                    handler,
                    productSurfaceContainer,
                    productViewportWidthPx,
                    productViewportHeightPx);
        }
    }

    public static final class InteractionRuntimeBundle {
        final BooleanSupplier nativeLoaded;
        final Runnable stopScrollbackFling;
        final Runnable refreshProductScrollOverlay;
        final Runnable reevaluateProductFrameLoop;
        final Consumer<String> appendEvent;

        private InteractionRuntimeBundle(
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

        public static InteractionRuntimeBundle of(
                BooleanSupplier nativeLoaded,
                Runnable stopScrollbackFling,
                Runnable refreshProductScrollOverlay,
                Runnable reevaluateProductFrameLoop,
                Consumer<String> appendEvent) {
            return new InteractionRuntimeBundle(
                    nativeLoaded,
                    stopScrollbackFling,
                    refreshProductScrollOverlay,
                    reevaluateProductFrameLoop,
                    appendEvent);
        }
    }

    private final InteractionHostBundle interactionHostBundle;
    private final InteractionRuntimeBundle interactionRuntimeBundle;

    public InteractionCallbacks(
            InteractionHostBundle interactionHostBundle,
            InteractionRuntimeBundle interactionRuntimeBundle) {
        this.interactionHostBundle = interactionHostBundle;
        this.interactionRuntimeBundle = interactionRuntimeBundle;
    }

    @Override
    public Activity activity() {
        return interactionHostBundle.activity.get();
    }

    @Override
    public Handler handler() {
        return interactionHostBundle.handler.get();
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return interactionHostBundle.productSurfaceContainer.get();
    }

    @Override
    public int productViewportWidthPx() {
        return interactionHostBundle.productViewportWidthPx.getAsInt();
    }

    @Override
    public int productViewportHeightPx() {
        return interactionHostBundle.productViewportHeightPx.getAsInt();
    }

    @Override
    public boolean nativeLoaded() {
        return interactionRuntimeBundle.nativeLoaded.getAsBoolean();
    }

    @Override
    public void stopScrollbackFling() {
        interactionRuntimeBundle.stopScrollbackFling.run();
    }

    @Override
    public void refreshProductScrollOverlay() {
        interactionRuntimeBundle.refreshProductScrollOverlay.run();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        interactionRuntimeBundle.reevaluateProductFrameLoop.run();
    }

    @Override
    public void appendEvent(String message) {
        interactionRuntimeBundle.appendEvent.accept(message);
    }
}
