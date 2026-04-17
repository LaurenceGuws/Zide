package uk.laurencegouws.terminal.host.ui;

/**
 * Compile-visible identity for a harness-hosted terminal widget slot.
 *
 * <p>Today the product wires exactly one slot ({@link #PRIMARY}). Additional enum
 * constants are reserved for future multi-terminal hosting; tab UI and session
 * switching are separate product concerns.</p>
 *
 * <p>Aligns with app-shell {@link ShellViewId#TERMINAL} routing for the primary
 * terminal surface.</p>
 */
public enum TerminalWidgetSlotId {
    /** Primary product terminal widget slot (current single-terminal behavior). */
    PRIMARY
}
