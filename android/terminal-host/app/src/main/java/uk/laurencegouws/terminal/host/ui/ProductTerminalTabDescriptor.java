package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * Immutable metadata for one product-terminal session tab in app-shell chrome (sidebar strip).
 *
 * <p>Stable {@link #stableId} is for logging and future persistence beyond raw index; display
 * {@link #label} is resolved at policy construction time (typically from {@code strings.xml}).</p>
 *
 * @see AppShellTerminalViewPolicy#productTerminalTabDescriptors()
 */
public final class ProductTerminalTabDescriptor {
    private final String stableId;
    private final String label;
    private final int tabIndex;

    public ProductTerminalTabDescriptor(final String stableId, final String label, final int tabIndex) {
        this.stableId = Objects.requireNonNull(stableId, "stableId");
        this.label = Objects.requireNonNull(label, "label");
        if (tabIndex < 0) {
            throw new IllegalArgumentException("tabIndex must be non-negative, got " + tabIndex);
        }
        this.tabIndex = tabIndex;
    }

    /** Stable product id (not tied to layout or list order refactors). */
    public String stableId() {
        return stableId;
    }

    /** Display label for the tab control. */
    public String label() {
        return label;
    }

    /** Index used with {@link AppShellNavigation#applySelectProductTerminalTab} and restore seeding. */
    public int tabIndex() {
        return tabIndex;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof ProductTerminalTabDescriptor)) {
            return false;
        }
        final ProductTerminalTabDescriptor that = (ProductTerminalTabDescriptor) o;
        return tabIndex == that.tabIndex
                && stableId.equals(that.stableId)
                && label.equals(that.label);
    }

    @Override
    public int hashCode() {
        return Objects.hash(stableId, label, tabIndex);
    }
}
