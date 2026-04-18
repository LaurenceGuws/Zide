package uk.laurencegouws.terminal.host.ui;

/**
 * Canonical mapping from product {@link TerminalWidgetSlotId} to app-shell
 * {@link ShellViewId} for harness navigation and chrome routing.
 *
 * <p>This is the single contract seam aligning terminal widget slot vocabulary with
 * shell view identity. It does not implement tab switching or multi-instance product
 * behavior — those require explicit policy and additional {@link ShellViewId} values.</p>
 *
 * <p>Product harness wiring resolves the slot once via
 * {@link AppShellNavigation#forProductTerminalSlot}; steady-state re-assert of the
 * product terminal shell view goes through {@link AppShellTerminalViewPolicy#applyActiveProductTerminalShellView}
 * (delegating to {@link AppShellNavigation#applyProductTerminalShellViewActive}) without calling this mapping again.</p>
 */
public final class ProductTerminalSlotShellMapping {
    private ProductTerminalSlotShellMapping() {
    }

    /**
     * Resolves the shell content identity for the given product terminal widget slot.
     * Invokes {@link TerminalWidgetSlotId#checkActiveProductTerminalSlot} — only
     * {@link TerminalWidgetSlotId#PRIMARY} is active today and maps to
     * {@link ShellViewId#TERMINAL}.
     */
    public static ShellViewId shellViewIdForTerminalSlot(TerminalWidgetSlotId slot) {
        TerminalWidgetSlotId.checkActiveProductTerminalSlot(slot);
        return ShellViewId.TERMINAL;
    }
}
