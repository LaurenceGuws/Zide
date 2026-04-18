package uk.laurencegouws.terminal.host.ui;

/**
 * Activity-owned scratch state for IME visibility used across harness assembly wiring.
 *
 * <p>Consolidates the boolean read/write pair that was previously duplicated as
 * {@code () -> imeVisible} / {@code this::setImeVisible} fan-out in {@code ZideActivity}.
 * Implements {@link SurfaceWidgetHostImeVisibility} for surface assembly; chrome policy uses
 * {@link #chromeImePolicyInput()} (B15/B14 seam names unchanged). Implements {@link HostImeStateAccess}
 * for unified status/viewport/input callback wiring (B18).</p>
 */
public final class ProductHostImeState implements SurfaceWidgetHostImeVisibility, HostImeStateAccess {
    private boolean imeVisible;

    @Override
    public boolean imeVisible() {
        return imeVisible;
    }

    @Override
    public boolean currentImeVisible() {
        return imeVisible;
    }

    @Override
    public void setImeVisible(boolean visible) {
        imeVisible = visible;
    }

    /** Chrome IME policy for {@link ChromeFactory}; behavior matches prior activity-local anonymous. */
    public ChromeImePolicyInput chromeImePolicyInput() {
        return new ChromeImePolicyInput() {
            @Override
            public boolean chromeImeVisibilityPresent() {
                return ProductHostImeState.this.imeVisible();
            }

            @Override
            public void applyChromeImeVisibilityHidden() {
                ProductHostImeState.this.setImeVisible(false);
            }

            @Override
            public void applyChromeImeVisibilityFromOpenAttempt(
                    boolean softInputShown, boolean shellInputHasFocus) {
                ProductHostImeState.this.setImeVisible(softInputShown || shellInputHasFocus);
            }
        };
    }
}
