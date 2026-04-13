package dev.zide.terminal.host;

import android.graphics.Insets;
import android.view.View;
import android.view.WindowInsets;
import android.widget.FrameLayout;

/** Owns visible viewport insets handling and product viewport size authority. */
public final class TerminalViewportController {
    public interface Host {
        View productView();

        FrameLayout productSurfaceContainer();

        boolean imeVisible();

        void setImeVisible(boolean imeVisible);

        void notifyVisibleViewport(String reason);
    }

    private final Host host;
    private int productViewBasePaddingLeft;
    private int productViewBasePaddingTop;
    private int productViewBasePaddingRight;
    private int productViewBasePaddingBottom;

    public TerminalViewportController(Host host) {
        this.host = host;
    }

    public void installInsetsHandling() {
        final View productView = host.productView();
        productViewBasePaddingLeft = productView.getPaddingLeft();
        productViewBasePaddingTop = productView.getPaddingTop();
        productViewBasePaddingRight = productView.getPaddingRight();
        productViewBasePaddingBottom = productView.getPaddingBottom();
        productView.setOnApplyWindowInsetsListener((view, windowInsets) -> {
            final Insets navInsets = windowInsets.getInsets(WindowInsets.Type.navigationBars());
            final Insets imeInsets = windowInsets.getInsets(WindowInsets.Type.ime());
            final int bottomInset = Math.max(navInsets.bottom, imeInsets.bottom);
            host.setImeVisible(imeInsets.bottom > navInsets.bottom);
            view.setPadding(
                    productViewBasePaddingLeft,
                    productViewBasePaddingTop,
                    productViewBasePaddingRight,
                    productViewBasePaddingBottom + bottomInset);
            host.productSurfaceContainer().post(() -> host.notifyVisibleViewport("insets"));
            return windowInsets;
        });
        productView.requestApplyInsets();
    }

    public void installViewportTracking() {
        host.productSurfaceContainer().addOnLayoutChangeListener(
                (view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {
                    if (left == oldLeft && top == oldTop && right == oldRight && bottom == oldBottom) {
                        return;
                    }
                    host.notifyVisibleViewport("layout");
                });
    }

    public boolean currentImeVisible() {
        final WindowInsets insets = host.productView().getRootWindowInsets();
        if (insets == null) {
            return host.imeVisible();
        }
        final Insets navInsets = insets.getInsets(WindowInsets.Type.navigationBars());
        final Insets imeInsets = insets.getInsets(WindowInsets.Type.ime());
        return imeInsets.bottom > navInsets.bottom;
    }

    public int productViewportWidthPx() {
        return host.productSurfaceContainer().getWidth();
    }

    public int productViewportHeightPx() {
        return host.productSurfaceContainer().getHeight();
    }
}
