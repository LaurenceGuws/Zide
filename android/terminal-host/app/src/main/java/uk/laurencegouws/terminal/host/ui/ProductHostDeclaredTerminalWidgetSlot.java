package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * Immutable harness <strong>value</strong> for the terminal {@link TerminalWidgetSlotId} the product
 * host declares for widget hosting at startup.
 *
 * <p>Startup wiring passes this type into {@link AppShellTerminalHostSelectionContext#forProductHostStartup}.
 * Use {@link #terminalWidgetSlotForProductHarness()} as the <strong>sole</strong> public conversion to
 * {@link TerminalWidgetSlotId} for harness assembly and active-slot checks — do not scatter raw unwraps.
 * Today the value is the catalog default only ({@code PRIMARY}); no multi-slot runtime or tab behavior.</p>
 *
 * @see DeclaredTerminalWidgetSlotCatalog
 * @see AppShellTerminalHostSelectionContext
 */
public final class ProductHostDeclaredTerminalWidgetSlot {
    private final TerminalWidgetSlotId terminalWidgetSlot;

    private ProductHostDeclaredTerminalWidgetSlot(final TerminalWidgetSlotId terminalWidgetSlot) {
        this.terminalWidgetSlot = Objects.requireNonNull(terminalWidgetSlot, "terminalWidgetSlot");
    }

    /** Declared slot for the current product harness (catalog default today). */
    public static ProductHostDeclaredTerminalWidgetSlot forCurrentProductHarness() {
        return new ProductHostDeclaredTerminalWidgetSlot(
                DeclaredTerminalWidgetSlotCatalog.currentProductHarness().defaultSelectedTerminalSlotForAppShell());
    }

    /**
     * Canonical startup choke point: {@link TerminalWidgetSlotId} for product harness wiring
     * ({@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}, selection policy, host interfaces).
     */
    public TerminalWidgetSlotId terminalWidgetSlotForProductHarness() {
        return terminalWidgetSlot;
    }

    @Override
    public boolean equals(final Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof ProductHostDeclaredTerminalWidgetSlot)) {
            return false;
        }
        final ProductHostDeclaredTerminalWidgetSlot that = (ProductHostDeclaredTerminalWidgetSlot) o;
        return terminalWidgetSlot == that.terminalWidgetSlot;
    }

    @Override
    public int hashCode() {
        return Objects.hashCode(terminalWidgetSlot);
    }

    @Override
    public String toString() {
        return "ProductHostDeclaredTerminalWidgetSlot{" + terminalWidgetSlot + "}";
    }
}
