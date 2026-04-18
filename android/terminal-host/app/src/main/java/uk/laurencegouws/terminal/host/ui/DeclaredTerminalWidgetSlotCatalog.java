package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * Declared set of {@link TerminalWidgetSlotId} values the product harness knows about for
 * terminal widget hosting (the terminal-slot <strong>catalog</strong>).
 *
 * <p>Distinct from <em>active</em> runtime slot policy
 * ({@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}): a slot may appear in the
 * catalog before multi-slot runtime is enabled. {@link AppShellTerminalSelectionPolicy} routes
 * selection through this owner.</p>
 *
 * <p>Today the catalog is {@link TerminalWidgetSlotId#PRIMARY} only; this does not enable
 * multi-slot runtime behavior or tab UI.</p>
 *
 * @see ProductHostDeclaredTerminalWidgetSlot immutable host-declared value built from this catalog’s default
 */
public final class DeclaredTerminalWidgetSlotCatalog {
    private static final TerminalWidgetSlotId[] PRODUCT_HARNESS_DECLARED = {
        TerminalWidgetSlotId.PRIMARY,
    };
    private static final DeclaredTerminalWidgetSlotCatalog CURRENT_PRODUCT_HARNESS =
            new DeclaredTerminalWidgetSlotCatalog();

    private DeclaredTerminalWidgetSlotCatalog() {
    }

    /** Current product harness: declared slots for terminal widget surfaces (PRIMARY-only today). */
    public static DeclaredTerminalWidgetSlotCatalog currentProductHarness() {
        return CURRENT_PRODUCT_HARNESS;
    }

    /** Immutable snapshot of declared slots (defensive copy). */
    public TerminalWidgetSlotId[] declaredProductTerminalSlots() {
        return PRODUCT_HARNESS_DECLARED.clone();
    }

    public boolean isDeclaredForProductHarness(final TerminalWidgetSlotId slot) {
        Objects.requireNonNull(slot, "slot");
        for (final TerminalWidgetSlotId s : PRODUCT_HARNESS_DECLARED) {
            if (s == slot) {
                return true;
            }
        }
        return false;
    }

    public void requireSlotDeclaredForProductHarness(final TerminalWidgetSlotId slot) {
        if (!isDeclaredForProductHarness(Objects.requireNonNull(slot, "slot"))) {
            throw new IllegalArgumentException("Terminal slot not in declared product harness catalog: " + slot);
        }
    }

    /**
     * Default app-shell selection when the product runs a single active terminal (today the sole
     * declared slot).
     */
    public TerminalWidgetSlotId defaultSelectedTerminalSlotForAppShell() {
        return PRODUCT_HARNESS_DECLARED[0];
    }
}
