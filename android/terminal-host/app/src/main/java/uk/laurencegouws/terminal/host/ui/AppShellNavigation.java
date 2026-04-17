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
 * <p><strong>Invariants:</strong> {@link #activeShellView()} is never {@code null}.
 * {@link #setActiveShellView} rejects {@code null} at the harness boundary.</p>
 */
public final class AppShellNavigation {
    private boolean sidebarOpen;
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
        this.activeShellView = this.productTerminalShellViewId;
    }

    /**
     * Re-asserts the resolved product-terminal shell view as active without re-running
     * slot mapping or {@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}.
     */
    public void applyProductTerminalShellViewActive() {
        setActiveShellView(productTerminalShellViewId);
    }

    public boolean isSidebarOpen() {
        return sidebarOpen;
    }

    public void setSidebarOpen(boolean open) {
        this.sidebarOpen = open;
    }

    public ShellViewId activeShellView() {
        return activeShellView;
    }

    /**
     * Sets which shell content view is active. Must not be {@code null}; future
     * multi-view hosting will pass additional {@link ShellViewId} values under explicit
     * harness policy.
     */
    public void setActiveShellView(ShellViewId id) {
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
