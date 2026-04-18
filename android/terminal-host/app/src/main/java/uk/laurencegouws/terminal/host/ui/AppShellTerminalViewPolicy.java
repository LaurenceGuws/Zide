package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * App-shell policy for which shell view is active for the product terminal surface.
 *
 * <p>Today: single {@link TerminalWidgetSlotId#PRIMARY} harness maps to one resolved
 * {@link ShellViewId} via {@link AppShellNavigation#forProductTerminalSlot}; view-mode
 * and future harness callers re-assert the active terminal shell view through this owner
 * rather than invoking {@link AppShellNavigation} activation ad hoc.</p>
 *
 * <p>Future multi-view / tab hosting extends this policy type with explicit methods; it does
 * not add tab UI or product behavior by itself.</p>
 */
public final class AppShellTerminalViewPolicy {
    private final AppShellNavigation appShellNavigation;

    public AppShellTerminalViewPolicy(final AppShellNavigation appShellNavigation) {
        this.appShellNavigation = Objects.requireNonNull(appShellNavigation, "appShellNavigation");
    }

    /** Harness navigation state (drawer, active shell view); chrome and shell-state readers use this. */
    public AppShellNavigation appShellNavigation() {
        return appShellNavigation;
    }

    /**
     * Re-asserts the resolved product-terminal shell view as the active app-shell view without
     * re-running slot mapping or {@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}.
     */
    public void applyActiveProductTerminalShellView() {
        appShellNavigation.applyProductTerminalShellViewActive();
    }
}
