package dev.zide.terminal.host;

import android.view.View;
import android.widget.FrameLayout;

/**
 * Adapts activity-owned viewport callbacks to {@link TerminalViewportController.Host}.
 */
public final class TerminalViewportHostBridge implements TerminalViewportController.Host {
    /** Callbacks used for mutable viewport/IME state and notifications. */
    public interface Callbacks {
        boolean imeVisible();

        void setImeVisible(boolean imeVisible);

        void notifyVisibleViewport(String reason);
    }

    private final View productView;
    private final FrameLayout productSurfaceContainer;
    private final Callbacks callbacks;

    public TerminalViewportHostBridge(View productView, FrameLayout productSurfaceContainer, Callbacks callbacks) {
        this.productView = productView;
        this.productSurfaceContainer = productSurfaceContainer;
        this.callbacks = callbacks;
    }

    @Override
    public View productView() {
        return productView;
    }

    @Override
    public FrameLayout productSurfaceContainer() {
        return productSurfaceContainer;
    }

    @Override
    public boolean imeVisible() {
        return callbacks.imeVisible();
    }

    @Override
    public void setImeVisible(boolean imeVisible) {
        callbacks.setImeVisible(imeVisible);
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        callbacks.notifyVisibleViewport(reason);
    }
}
