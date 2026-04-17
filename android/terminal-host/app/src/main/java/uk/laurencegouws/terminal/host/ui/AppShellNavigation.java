package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * Owns harness app-shell navigation and view-selection state: slide-out drawer open
 * flag, active shell view identity, and per-view snapshots for multi-view hosting.
 *
 * <p>Chrome and startup code read this owner instead of scattering sidebar/view flags
 * across bridges. Initial {@link ShellViewId} must come from
 * {@link ProductTerminalSlotShellMapping} for product terminal slots so slot and
 * shell view vocabulary stay aligned.</p>
 */
public final class AppShellNavigation {
    private boolean sidebarOpen;
    private ShellViewId activeShellView;

    public AppShellNavigation(ShellViewId initialActiveShellView) {
        this.activeShellView = Objects.requireNonNull(initialActiveShellView, "initialActiveShellView");
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

    public void setActiveShellView(ShellViewId id) {
        this.activeShellView = id;
    }

    /** State row for the currently selected shell view. */
    public AppShellViewState activeViewState() {
        return new AppShellViewState(activeShellView, true, false);
    }
}
