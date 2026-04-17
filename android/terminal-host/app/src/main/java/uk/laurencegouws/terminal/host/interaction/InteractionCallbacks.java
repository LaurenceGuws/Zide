package uk.laurencegouws.terminal.host.interaction;

import android.content.Context;
import android.os.Handler;
import android.widget.FrameLayout;

import java.util.function.Consumer;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.host.ui.TerminalWidgetSlotId;

/** Functional callback adapter for {@link InteractionAssembly.Host}. */
public final class InteractionCallbacks implements InteractionAssembly.Host {
    private final TerminalWidgetSlotId terminalWidgetSlot;
    private final Context harnessContext;
    private final Handler handler;
    private final FrameLayout productSurfaceContainer;
    private final IntSupplier productViewportWidthPx;
    private final IntSupplier productViewportHeightPx;
    private final Runnable stopScrollbackFling;
    private final Runnable refreshScrollOverlay;
    private final Runnable reevaluateFrameLoop;
    private final Consumer<String> appendEvent;

    public InteractionCallbacks(
            TerminalWidgetSlotId terminalWidgetSlot,
            Context harnessContext,
            Handler handler,
            FrameLayout productSurfaceContainer,
            IntSupplier productViewportWidthPx,
            IntSupplier productViewportHeightPx,
            Runnable stopScrollbackFling,
            Runnable refreshScrollOverlay,
            Runnable reevaluateFrameLoop,
            Consumer<String> appendEvent) {
        this.terminalWidgetSlot = terminalWidgetSlot;
        this.harnessContext = harnessContext;
        this.handler = handler;
        this.productSurfaceContainer = productSurfaceContainer;
        this.productViewportWidthPx = productViewportWidthPx;
        this.productViewportHeightPx = productViewportHeightPx;
        this.stopScrollbackFling = stopScrollbackFling;
        this.refreshScrollOverlay = refreshScrollOverlay;
        this.reevaluateFrameLoop = reevaluateFrameLoop;
        this.appendEvent = appendEvent;
    }

    @Override
    public TerminalWidgetSlotId terminalWidgetSlot() {
        return terminalWidgetSlot;
    }

    @Override
    public Context harnessContext() {
        return harnessContext;
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
    public void refreshScrollOverlay() {
        refreshScrollOverlay.run();
    }

    @Override
    public void reevaluateFrameLoop() {
        reevaluateFrameLoop.run();
    }

    @Override
    public void appendEvent(String message) {
        appendEvent.accept(message);
    }
}
