package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * Host-side startup seam bundling declared-slot catalog truth and the selected app-shell routing
 * slot for one product onCreate path.
 *
 * <p>Built once per activity startup; {@link uk.laurencegouws.terminal.ZideActivity} and
 * {@link WidgetAssembly} consume the same instance so catalog membership, active-slot checks, and
 * selected-slot reads are not repeated ad hoc across interaction wiring and widget assembly.
 * {@link ProductHostDeclaredTerminalWidgetSlot#terminalWidgetSlotForProductHarness} is the conversion
 * choke point feeding {@link AppShellTerminalSelectionPolicy#forDeclaredHostSlot}. Today
 * this still resolves to a single {@link TerminalWidgetSlotId#PRIMARY} path; it does not enable
 * multi-slot runtime behavior.</p>
 *
 * @see AppShellTerminalSelectionPolicy
 * @see DeclaredTerminalWidgetSlotCatalog
 * @see ProductHostDeclaredTerminalWidgetSlot
 */
public final class AppShellTerminalHostSelectionContext {
    private final ProductHostDeclaredTerminalWidgetSlot hostDeclaredTerminalWidgetSlot;
    private final DeclaredTerminalWidgetSlotCatalog declaredSlotCatalog;
    private final TerminalWidgetSlotId selectedProductTerminalSlotForAppShell;
    private final AppShellTerminalSelectionPolicy appShellTerminalSelectionPolicy;

    private AppShellTerminalHostSelectionContext(
            final ProductHostDeclaredTerminalWidgetSlot hostDeclaredTerminalWidgetSlot,
            final DeclaredTerminalWidgetSlotCatalog declaredSlotCatalog,
            final TerminalWidgetSlotId selectedProductTerminalSlotForAppShell,
            final AppShellTerminalSelectionPolicy appShellTerminalSelectionPolicy) {
        this.hostDeclaredTerminalWidgetSlot =
                Objects.requireNonNull(hostDeclaredTerminalWidgetSlot, "hostDeclaredTerminalWidgetSlot");
        this.declaredSlotCatalog = Objects.requireNonNull(declaredSlotCatalog, "declaredSlotCatalog");
        this.selectedProductTerminalSlotForAppShell =
                Objects.requireNonNull(selectedProductTerminalSlotForAppShell, "selectedProductTerminalSlotForAppShell");
        this.appShellTerminalSelectionPolicy =
                Objects.requireNonNull(appShellTerminalSelectionPolicy, "appShellTerminalSelectionPolicy");
    }

    /**
     * Resolves catalog + {@link AppShellTerminalSelectionPolicy} for the harness-declared widget slot
     * (catalog membership and {@link TerminalWidgetSlotId#checkActiveProductTerminalSlot}).
     */
    public static AppShellTerminalHostSelectionContext forProductHostStartup(
            final ProductHostDeclaredTerminalWidgetSlot hostDeclaredTerminalWidgetSlot) {
        Objects.requireNonNull(hostDeclaredTerminalWidgetSlot, "hostDeclaredTerminalWidgetSlot");
        final AppShellTerminalSelectionPolicy policy =
                AppShellTerminalSelectionPolicy.forDeclaredHostSlot(
                        hostDeclaredTerminalWidgetSlot.terminalWidgetSlotForProductHarness());
        return new AppShellTerminalHostSelectionContext(
                hostDeclaredTerminalWidgetSlot,
                policy.declaredSlotCatalog(),
                policy.selectedProductTerminalSlotForAppShell(),
                policy);
    }

    /** Host-declared terminal widget slot value this context was built from. */
    public ProductHostDeclaredTerminalWidgetSlot hostDeclaredTerminalWidgetSlot() {
        return hostDeclaredTerminalWidgetSlot;
    }

    public DeclaredTerminalWidgetSlotCatalog declaredSlotCatalog() {
        return declaredSlotCatalog;
    }

    public TerminalWidgetSlotId selectedProductTerminalSlotForAppShell() {
        return selectedProductTerminalSlotForAppShell;
    }

    public AppShellTerminalSelectionPolicy appShellTerminalSelectionPolicy() {
        return appShellTerminalSelectionPolicy;
    }
}
