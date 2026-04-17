package uk.laurencegouws.terminal.host.ui;

/**
 * Identifies a hosted shell content slot in the app chrome.
 *
 * <p>Today only the terminal view exists; additional values are reserved for
 * future multi-view / tab parity without changing harness seams. Product
 * terminal slot → shell view mapping for active wiring lives in
 * {@link ProductTerminalSlotShellMapping}.</p>
 */
public enum ShellViewId {
    /** Primary terminal surface + assist chrome. */
    TERMINAL,
}
