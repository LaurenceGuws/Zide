package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * Compile-visible identity for a harness-hosted terminal widget slot.
 *
 * <p>Today the product wires exactly one <em>active</em> product slot ({@link #PRIMARY}).
 * Additional enum constants are reserved for future multi-terminal hosting; they must
 * not drive behavior until host policy defines them. Tab UI and session switching are
 * separate product concerns.</p>
 *
 * <p>Canonical alignment with app-shell view identity is
 * {@link ProductTerminalSlotShellMapping#shellViewIdForTerminalSlot} — today
 * {@link #PRIMARY} maps to {@link ShellViewId#TERMINAL}.</p>
 */
public enum TerminalWidgetSlotId {
    /**
     * Primary product terminal widget slot (current single-terminal behavior).
     * This is the only slot that {@link #checkActiveProductTerminalSlot} accepts today.
     */
    PRIMARY;

    /**
     * Enforces the current product invariant: only {@link #PRIMARY} is an active terminal
     * widget slot in harness wiring. Call from slot-typed assembly and composition entry
     * points. When additional slots become active, relax or replace this check alongside
     * host policy — do not use it to implement tab product behavior by itself.
     */
    public static void checkActiveProductTerminalSlot(TerminalWidgetSlotId slot) {
        Objects.requireNonNull(slot, "slot");
        if (slot != PRIMARY) {
            throw new IllegalStateException(
                    "Only TerminalWidgetSlotId.PRIMARY is active in current product wiring; got " + slot);
        }
    }
}
