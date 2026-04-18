package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * App-shell <strong>activation</strong> policy: which shell view is active for the product terminal
 * surface (re-assert product terminal shell view, chrome drawer sidebar reads/writes).
 *
 * <p>Today: single {@link TerminalWidgetSlotId#PRIMARY} harness maps to one resolved
 * {@link ShellViewId} via {@link AppShellNavigation#forProductTerminalSlot}; view-mode
 * and future harness callers re-assert the active terminal shell view through this owner
 * rather than invoking {@link AppShellNavigation} activation ad hoc.</p>
 *
 * <p>Chrome drawer sidebar policy ({@link #chromeDrawerSidebarOpen},
 * {@link #applyChromeDrawerSidebarOpen}, {@link #applyChromeDrawerSidebarClosed}) is forwarded
 * here so {@link ChromeBridge} does not take a raw {@link AppShellNavigation} reference.</p>
 *
 * <p>Product terminal tab-strip selection (slice 1) is forwarded here so chrome wiring does not
 * reach {@link AppShellNavigation} directly for tab indices.</p>
 */
public final class AppShellTerminalViewPolicy {
    private final AppShellNavigation appShellNavigation;

    public AppShellTerminalViewPolicy(final AppShellNavigation appShellNavigation) {
        this.appShellNavigation = Objects.requireNonNull(appShellNavigation, "appShellNavigation");
    }

    /**
     * Re-asserts the resolved product-terminal shell view as the active app-shell view without
     * re-running slot mapping or {@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}.
     */
    public void applyActiveProductTerminalShellView() {
        appShellNavigation.applyProductTerminalShellViewActive();
    }

    /** @see AppShellNavigation#productTerminalTabCount */
    public int productTerminalTabCount() {
        return appShellNavigation.productTerminalTabCount();
    }

    /** @see AppShellNavigation#selectedProductTerminalTabIndex */
    public int selectedProductTerminalTabIndex() {
        return appShellNavigation.selectedProductTerminalTabIndex();
    }

    /** @see AppShellNavigation#applySelectProductTerminalTab */
    public boolean applySelectProductTerminalTab(final int tabIndex) {
        return appShellNavigation.applySelectProductTerminalTab(tabIndex);
    }

    /** Whether the slide-out chrome drawer sidebar is open (visible). */
    public boolean chromeDrawerSidebarOpen() {
        return appShellNavigation.chromeDrawerSidebarOpen();
    }

    /** Records chrome policy: drawer sidebar should be open. */
    public void applyChromeDrawerSidebarOpen() {
        appShellNavigation.applyChromeDrawerSidebarOpen();
    }

    /** Records chrome policy: drawer sidebar should be closed. */
    public void applyChromeDrawerSidebarClosed() {
        appShellNavigation.applyChromeDrawerSidebarClosed();
    }
}
