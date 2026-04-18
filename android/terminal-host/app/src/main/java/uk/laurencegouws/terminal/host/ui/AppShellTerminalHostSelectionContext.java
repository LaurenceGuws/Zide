package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * Host-side startup seam bundling declared-slot catalog truth and the selected app-shell routing
 * slot for one product onCreate path.
 *
 * <p>Built once per activity startup; {@link uk.laurencegouws.terminal.ZideActivity} and
 * {@link WidgetAssembly} consume the same instance so catalog membership, active-slot checks, and
 * selected-slot reads are not repeated ad hoc across interaction wiring and widget assembly. Today
 * this still resolves to a single {@link TerminalWidgetSlotId#PRIMARY} path; it does not enable
 * multi-slot runtime behavior.</p>
 *
 * @see AppShellTerminalSelectionPolicy
 * @see DeclaredTerminalWidgetSlotCatalog
 * @see ProductHostDeclaredTerminalWidgetSlot
 */
public final class AppShellTerminalHostSelectionContext {
    private final DeclaredTerminalWidgetSlotCatalog declaredSlotCatalog;
    private final TerminalWidgetSlotId selectedProductTerminalSlotForAppShell;
    private final AppShellTerminalSelectionPolicy appShellTerminalSelectionPolicy;

    private AppShellTerminalHostSelectionContext(
            final DeclaredTerminalWidgetSlotCatalog declaredSlotCatalog,
            final TerminalWidgetSlotId selectedProductTerminalSlotForAppShell,
            final AppShellTerminalSelectionPolicy appShellTerminalSelectionPolicy) {
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
    public static AppShellTerminalHostSelectionContext forProductHostStartup(final TerminalWidgetSlotId hostDeclaredSlot) {
        final AppShellTerminalSelectionPolicy policy =
                AppShellTerminalSelectionPolicy.forDeclaredHostSlot(hostDeclaredSlot);
        return new AppShellTerminalHostSelectionContext(
                policy.declaredSlotCatalog(),
                policy.selectedProductTerminalSlotForAppShell(),
                policy);
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
