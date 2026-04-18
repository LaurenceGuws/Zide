package uk.laurencegouws.terminal.host.ui;

/**
 * Explicit harness seam for the terminal {@link TerminalWidgetSlotId} the product host declares for
 * widget hosting at startup.
 *
 * <p>Startup wiring builds {@link AppShellTerminalHostSelectionContext} via
 * {@link AppShellTerminalHostSelectionContext#forProductHostStartup} from this value. Today it is the
 * sole default entry from {@link DeclaredTerminalWidgetSlotCatalog#currentProductHarness()} — no
 * multi-slot runtime or tab behavior.</p>
 *
 * @see DeclaredTerminalWidgetSlotCatalog
 * @see AppShellTerminalHostSelectionContext
 */
public final class ProductHostDeclaredTerminalWidgetSlot {
    private ProductHostDeclaredTerminalWidgetSlot() {
    }

    /** Host-declared terminal widget slot for the current product harness ({@code PRIMARY} today). */
    public static TerminalWidgetSlotId forCurrentProductHarness() {
        return DeclaredTerminalWidgetSlotCatalog.currentProductHarness().defaultSelectedTerminalSlotForAppShell();
    }
}
