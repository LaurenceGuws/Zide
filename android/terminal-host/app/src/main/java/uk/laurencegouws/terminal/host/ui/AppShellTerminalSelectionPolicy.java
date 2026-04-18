package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * App-shell <strong>selection</strong> policy: which product {@link TerminalWidgetSlotId} the harness
 * treats as selected for terminal routing (shell view mapping, widget assembly alignment).
 *
 * <p>Selection is constrained by the {@link DeclaredTerminalWidgetSlotCatalog} and active-slot
 * checks ({@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}). Today this resolves to the
 * sole declared slot only; future multi-terminal hosting extends these owners without shipping tab
 * UI by itself.</p>
 *
 * <p><strong>Activation</strong> (which shell view is visibly active / drawer chrome) is
 * {@link AppShellTerminalViewPolicy}, built from navigation resolved for the selected slot.</p>
 *
 * @see AppShellTerminalViewPolicy
 * @see DeclaredTerminalWidgetSlotCatalog
 * @see AppShellTerminalHostSelectionContext
 * @see ProductTerminalSlotShellMapping
 */
public final class AppShellTerminalSelectionPolicy {
    private static final AppShellTerminalSelectionPolicy SINGLE_TERMINAL_PRODUCT =
            new AppShellTerminalSelectionPolicy(DeclaredTerminalWidgetSlotCatalog.currentProductHarness());

    private final DeclaredTerminalWidgetSlotCatalog declaredSlotCatalog;

    private AppShellTerminalSelectionPolicy(final DeclaredTerminalWidgetSlotCatalog declaredSlotCatalog) {
        this.declaredSlotCatalog = Objects.requireNonNull(declaredSlotCatalog, "declaredSlotCatalog");
    }

    /** Declared terminal-slot catalog backing this selection policy instance. */
    public DeclaredTerminalWidgetSlotCatalog declaredSlotCatalog() {
        return declaredSlotCatalog;
    }

    /**
     * Product default: single active terminal slot for app-shell routing when the activity does not
     * receive a per-widget host declaration. Uses {@link DeclaredTerminalWidgetSlotCatalog#currentProductHarness()}.
     */
    public static AppShellTerminalSelectionPolicy singleTerminalProduct() {
        return SINGLE_TERMINAL_PRODUCT;
    }

    /**
     * Selection policy aligned with a {@link WidgetAssembly.Host} slot declaration. Validates the
     * host slot against the declared catalog and current active-slot policy
     * ({@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}).
     */
    public static AppShellTerminalSelectionPolicy forDeclaredHostSlot(final TerminalWidgetSlotId hostDeclaredSlot) {
        final TerminalWidgetSlotId slot = Objects.requireNonNull(hostDeclaredSlot, "hostDeclaredSlot");
        SINGLE_TERMINAL_PRODUCT.declaredSlotCatalog.requireSlotDeclaredForProductHarness(slot);
        TerminalWidgetSlotId.checkActiveProductTerminalSlot(slot);
        return SINGLE_TERMINAL_PRODUCT;
    }

    /**
     * The terminal slot selected for app-shell routing (mapping to {@link ShellViewId} via
     * {@link ProductTerminalSlotShellMapping} inside {@link AppShellNavigation#forProductTerminalSlot}).
     */
    public TerminalWidgetSlotId selectedProductTerminalSlotForAppShell() {
        return declaredSlotCatalog.defaultSelectedTerminalSlotForAppShell();
    }
}
