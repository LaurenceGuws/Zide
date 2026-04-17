package uk.laurencegouws.terminal.host.ui;

/**
 * Identifies a hosted shell content slot in the app chrome.
 *
 * <p>Today only the terminal view exists; additional values are reserved for
 * future multi-view / tab parity without changing harness seams.
 */
public enum ShellViewId {
    /** Primary terminal surface + assist chrome. */
    TERMINAL,
}
