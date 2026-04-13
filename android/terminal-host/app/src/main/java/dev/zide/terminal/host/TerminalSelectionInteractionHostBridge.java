package dev.zide.terminal.host;

import android.content.Context;
import android.widget.FrameLayout;

import dev.zide.terminal.selection.TerminalSelectionController;

/**
 * Adapts activity-owned callbacks to {@link TerminalSelectionController.Host}.
 */
public final class TerminalSelectionInteractionHostBridge implements TerminalSelectionController.Host {
    /** Activity callbacks required for selection interaction. */
    public interface Callbacks {
        int productViewportWidthPx();

        int productViewportHeightPx();

        void stopScrollbackFling();

        void refreshProductScrollOverlay();

        void reevaluateProductFrameLoop();

        void appendEvent(String event);
    }

    private final Context context;
    private final FrameLayout productSurfaceContainer;
    private final Callbacks callbacks;

    public TerminalSelectionInteractionHostBridge(
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
    public void refreshProductScrollOverlay() {
        callbacks.refreshProductScrollOverlay();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        callbacks.reevaluateProductFrameLoop();
    }

    @Override
    public void appendEvent(String event) {
        callbacks.appendEvent(event);
    }
}
