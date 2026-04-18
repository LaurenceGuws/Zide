package uk.laurencegouws.terminal.host.ui;

import java.util.List;
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
 * <p>Product terminal tab metadata (APX-B15): {@link #productTerminalTabDescriptors()} is the
 * policy-owned surface for stable ids + labels paired with tab indices; selected index and
 * mutation still delegate to {@link AppShellNavigation}.</p>
 */
public final class AppShellTerminalViewPolicy {
    private final AppShellNavigation appShellNavigation;
    private final List<ProductTerminalTabDescriptor> productTerminalTabDescriptors;

    public AppShellTerminalViewPolicy(
            final AppShellNavigation appShellNavigation,
            final List<ProductTerminalTabDescriptor> productTerminalTabDescriptors) {
        this.appShellNavigation = Objects.requireNonNull(appShellNavigation, "appShellNavigation");
        this.productTerminalTabDescriptors =
                List.copyOf(Objects.requireNonNull(productTerminalTabDescriptors, "productTerminalTabDescriptors"));
        if (this.productTerminalTabDescriptors.size() != appShellNavigation.productTerminalTabCount()) {
            throw new IllegalArgumentException(
                    "descriptor count "
                            + this.productTerminalTabDescriptors.size()
                            + " != navigation tab count "
                            + appShellNavigation.productTerminalTabCount());
        }
        for (int i = 0; i < this.productTerminalTabDescriptors.size(); i++) {
            if (this.productTerminalTabDescriptors.get(i).tabIndex() != i) {
                throw new IllegalArgumentException(
                        "descriptor at list index " + i + " has tabIndex " +
                                this.productTerminalTabDescriptors.get(i).tabIndex() + ", expected " + i);
            }
        }
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

    /**
     * Ordered tab descriptors aligned with {@code [0, productTerminalTabCount())} — chrome binds
     * labels and click targets from this list, not from hardcoded sidebar assumptions.
     */
    public List<ProductTerminalTabDescriptor> productTerminalTabDescriptors() {
        return productTerminalTabDescriptors;
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
