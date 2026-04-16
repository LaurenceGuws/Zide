package uk.laurencegouws.terminal.host.interaction;

import android.content.Context;
import android.widget.FrameLayout;

import uk.laurencegouws.terminal.selection.SelectionController;

/**
 * Adapts activity-owned callbacks to {@link SelectionController.Host}.
 */
public final class SelectionInteractionBridge implements SelectionController.Host {
    /** Activity callbacks required for selection interaction. */
    public interface Callbacks {
        int productViewportWidthPx();

        int productViewportHeightPx();

        void stopScrollbackFling();

        void refreshScrollOverlay();

        void reevaluateFrameLoop();

        void appendEvent(String event);
    }

    private final Context context;
    private final FrameLayout productSurfaceContainer;
    private final Callbacks callbacks;

    public SelectionInteractionBridge(
            Context context,
            FrameLayout productSurfaceContainer,
            Callbacks callbacks) {
        this.context = context;
        this.productSurfaceContainer = productSurfaceContainer;
        this.callbacks = callbacks;
    }

    @Override
    public Context context() {
        return context;
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return productSurfaceContainer;
    }

    @Override
    public int productViewportWidthPx() {
        return callbacks.productViewportWidthPx();
    }

    @Override
    public int productViewportHeightPx() {
        return callbacks.productViewportHeightPx();
    }

    @Override
    public void stopScrollbackFling() {
        callbacks.stopScrollbackFling();
    }

    @Override
    public void refreshScrollOverlay() {
        callbacks.refreshScrollOverlay();
    }

    @Override
    public void reevaluateFrameLoop() {
        callbacks.reevaluateFrameLoop();
    }

    @Override
    public void appendEvent(String event) {
        callbacks.appendEvent(event);
    }
}
