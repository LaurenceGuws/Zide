package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * Owns harness app-shell navigation and view-selection state: slide-out drawer open
 * flag, active shell view identity, and per-view snapshots for multi-view hosting.
 *
 * <p>Chrome and startup code read this owner instead of scattering sidebar/view flags
 * across bridges. For product terminal wiring, construct via
 * {@link #forProductTerminalSlot} so slot→{@link ShellViewId} resolution happens once
 * via {@link ProductTerminalSlotShellMapping}.</p>
 *
 * <p><strong>Active-view mutation:</strong> product wiring uses
 * {@link #applyProductTerminalShellViewActive} only — there is no public arbitrary
 * shell-view setter. Harness view-mode and bundle wiring reach this through
 * {@link AppShellTerminalViewPolicy} so terminal-view activation policy stays explicit.
 * Future multi-view harness policy extends that owner (and/or adds explicit methods
 * here) rather than a generic setter.</p>
 *
 * <p><strong>Invariants:</strong> {@link #activeShellView()} is never {@code null};
 * internal replacement uses {@link Objects#requireNonNull}.</p>
 *
 * <p><strong>Chrome drawer sidebar:</strong> mutation uses
 * {@link #applyChromeDrawerSidebarOpen} / {@link #applyChromeDrawerSidebarClosed} only
 * — no generic boolean sidebar setter.</p>
 *
 * <p><strong>Product terminal tab strip (slice 1):</strong> harness keeps a small fixed
 * tab count ({@link #productTerminalTabCount}) and the selected index
 * ({@link #selectedProductTerminalTabIndex} / {@link #applySelectProductTerminalTab}).
 * Distinct tab selections trigger a native shell restart from {@link ChromeController}
 * wiring (single PTY; prior tab transcript is not preserved). This does not add a second
 * {@link TerminalWidgetSlotId} or {@link TerminalWidgetInstance}.</p>
 *
 * @see ProductTerminalTabSessionContract
 */
public final class AppShellNavigation {
    /** Fixed tab count for the first tab-state vertical slice (chrome only). */
    public static final int PRODUCT_TERMINAL_TAB_COUNT = 2;

    private boolean chromeDrawerSidebarOpen;
    /**
     * Resolved shell view for this navigation instance’s product terminal slot (mapping
     * runs once in {@link #forProductTerminalSlot}).
     */
    private final ShellViewId productTerminalShellViewId;
    private ShellViewId activeShellView;
    private int selectedProductTerminalTabIndex;

    /**
     * Product harness wiring: resolves the slot once and seeds {@link #activeShellView}.
     */
    public static AppShellNavigation forProductTerminalSlot(TerminalWidgetSlotId slot) {
        ShellViewId resolved = ProductTerminalSlotShellMapping.shellViewIdForTerminalSlot(slot);
        return new AppShellNavigation(resolved);
    }

    private AppShellNavigation(ShellViewId productTerminalShellViewId) {
        this.productTerminalShellViewId =
                Objects.requireNonNull(productTerminalShellViewId, "productTerminalShellViewId");
        replaceActiveShellView(this.productTerminalShellViewId);
        this.selectedProductTerminalTabIndex = 0;
    }

    /**
     * Re-asserts the resolved product-terminal shell view as active without re-running
     * slot mapping or {@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}.
     */
    public void applyProductTerminalShellViewActive() {
        replaceActiveShellView(productTerminalShellViewId);
    }

    /** Number of product terminal tabs in the app-shell chrome strip (slice 1). */
    public int productTerminalTabCount() {
        return PRODUCT_TERMINAL_TAB_COUNT;
    }

    /** Selected tab index {@code [0, productTerminalTabCount())}. */
    public int selectedProductTerminalTabIndex() {
        return selectedProductTerminalTabIndex;
    }

    /**
     * Selects a product terminal tab in harness chrome. Re-asserts the active shell view
     * for the resolved product slot (single {@link ShellViewId} today).
     *
     * @throws IllegalArgumentException if {@code tabIndex} is out of range
     */
    /**
     * @return {@code true} if the selected tab index changed
     */
    public boolean applySelectProductTerminalTab(final int tabIndex) {
        if (tabIndex < 0 || tabIndex >= PRODUCT_TERMINAL_TAB_COUNT) {
            throw new IllegalArgumentException(
                    "tabIndex must be in [0, " + PRODUCT_TERMINAL_TAB_COUNT + "), got " + tabIndex);
        }
        if (tabIndex == selectedProductTerminalTabIndex) {
            return false;
        }
        selectedProductTerminalTabIndex = tabIndex;
        applyProductTerminalShellViewActive();
        return true;
    }

    /** Whether the slide-out chrome drawer sidebar is open (visible). */
    public boolean chromeDrawerSidebarOpen() {
        return chromeDrawerSidebarOpen;
    }

    /** Records chrome policy: drawer sidebar should be open. */
    public void applyChromeDrawerSidebarOpen() {
        this.chromeDrawerSidebarOpen = true;
    }

    /** Records chrome policy: drawer sidebar should be closed. */
    public void applyChromeDrawerSidebarClosed() {
        this.chromeDrawerSidebarOpen = false;
    }

    public ShellViewId activeShellView() {
        return activeShellView;
    }

    private void replaceActiveShellView(ShellViewId id) {
        this.activeShellView = Objects.requireNonNull(id, "activeShellView");
    }

    /**
     * State row for the currently selected shell view ({@code selected=true},
     * {@code contentReady=false} — reserved bit for future readiness wiring).
     */
    public AppShellViewState activeViewState() {
        return new AppShellViewState(activeShellView, true, false);
    }
}
