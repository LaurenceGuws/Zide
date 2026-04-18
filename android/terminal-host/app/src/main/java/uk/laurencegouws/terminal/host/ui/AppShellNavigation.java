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
 */
public final class AppShellNavigation {
    private boolean chromeDrawerSidebarOpen;
    /**
     * Resolved shell view for this navigation instance’s product terminal slot (mapping
     * runs once in {@link #forProductTerminalSlot}).
     */
    private final ShellViewId productTerminalShellViewId;
    private ShellViewId activeShellView;

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
    }

    /**
     * Re-asserts the resolved product-terminal shell view as active without re-running
     * slot mapping or {@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}.
     */
    public void applyProductTerminalShellViewActive() {
        replaceActiveShellView(productTerminalShellViewId);
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
