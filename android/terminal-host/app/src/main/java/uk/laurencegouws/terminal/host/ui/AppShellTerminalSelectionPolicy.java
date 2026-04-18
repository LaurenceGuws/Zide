package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * App-shell <strong>selection</strong> policy: which product {@link TerminalWidgetSlotId} the harness
 * treats as selected for terminal routing (shell view mapping, widget assembly alignment).
 *
 * <p>Today this is always {@link TerminalWidgetSlotId#PRIMARY}. Future multi-terminal hosting
 * extends this owner with additional selection state; this type does not ship tab UI or session
 * switching.</p>
 *
 * <p><strong>Activation</strong> (which shell view is visibly active / drawer chrome) is
 * {@link AppShellTerminalViewPolicy}, built from navigation resolved for the selected slot.</p>
 *
 * @see AppShellTerminalViewPolicy
 * @see ProductTerminalSlotShellMapping
 */
public final class AppShellTerminalSelectionPolicy {
    private static final AppShellTerminalSelectionPolicy SINGLE_TERMINAL_PRODUCT = new AppShellTerminalSelectionPolicy();

    private AppShellTerminalSelectionPolicy() {
    }

    /**
     * Product default: single active terminal slot ({@link TerminalWidgetSlotId#PRIMARY}) for
     * app-shell routing when the activity does not receive a per-widget host declaration.
     */
    public static AppShellTerminalSelectionPolicy singleTerminalProduct() {
        return SINGLE_TERMINAL_PRODUCT;
    }

    /**
     * Selection policy aligned with a {@link WidgetAssembly.Host} slot declaration. Validates the
     * host slot against current active-slot policy ({@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}).
     */
    public static AppShellTerminalSelectionPolicy forDeclaredHostSlot(final TerminalWidgetSlotId hostDeclaredSlot) {
        TerminalWidgetSlotId.checkActiveProductTerminalSlot(
                Objects.requireNonNull(hostDeclaredSlot, "hostDeclaredSlot"));
        return SINGLE_TERMINAL_PRODUCT;
    }

    /**
     * The terminal slot selected for app-shell routing (mapping to {@link ShellViewId} via
     * {@link ProductTerminalSlotShellMapping} inside {@link AppShellNavigation#forProductTerminalSlot}).
     */
    public TerminalWidgetSlotId selectedProductTerminalSlotForAppShell() {
        return TerminalWidgetSlotId.PRIMARY;
    }
}
