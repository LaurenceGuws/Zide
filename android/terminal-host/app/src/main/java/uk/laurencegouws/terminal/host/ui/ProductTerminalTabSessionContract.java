package uk.laurencegouws.terminal.host.ui;

/**
 * Product terminal tab/session semantics for the current single-PTY native runtime.
 *
 * <p><strong>Single PTY:</strong> the host drives one native shell session at a time. A
 * <em>user-driven</em> switch to a different product terminal tab (distinct index via
 * {@link AppShellNavigation#applySelectProductTerminalTab}) triggers a native shell restart and
 * userland refresh. Prior tab transcript is not preserved.</p>
 *
 * <p><strong>Activity recreate:</strong> the selected tab index may be restored by seeding
 * {@link AppShellNavigation} through {@link AppShellNavigation#forProductTerminalSlot(TerminalWidgetSlotId, int)}
 * so the UI matches without calling {@code applySelectProductTerminalTab} — that avoids a synthetic
 * restart on restore while preserving APX-B9 restart semantics for real tab clicks.</p>
 *
 * <p><strong>Tab metadata (APX-B15):</strong> stable ids and display labels are owned by
 * {@link AppShellTerminalViewPolicy#productTerminalTabDescriptors()} and consumed by chrome binding.</p>
 *
 * <p><strong>Persistence (APX-B16):</strong> activity instance state stores the selected tab’s
 * {@link ProductTerminalTabDescriptor#stableId()}; restore resolves to a seed index via the same
 * descriptor table before {@link AppShellNavigation#forProductTerminalSlot(TerminalWidgetSlotId, int)}
 * runs (no synthetic selection restart). Legacy bundles may still carry only a raw index key.</p>
 *
 * <p><strong>UX placement:</strong> session/tab controls are <em>AppShell navigation</em> — they
 * belong in the left slide-out sidebar alongside other harness actions, not inline above the
 * assist/input helper strip. The assist row remains dedicated to terminal input helpers (IME,
 * keys, modifiers).</p>
 *
 * <p><strong>Non-goals in this product cut:</strong> dual-PTY hosting, per-tab native session
 * persistence, or cross-tab shell state restore — those require explicit multi-session policy and
 * native work beyond the APX-B9/B10 slice.</p>
 *
 * @see AppShellNavigation
 * @see ChromeController
 * @see uk.laurencegouws.terminal.host.runtime.RuntimeController#restartShellSessionForProductTab
 */
public final class ProductTerminalTabSessionContract {
    private ProductTerminalTabSessionContract() {
    }
}
