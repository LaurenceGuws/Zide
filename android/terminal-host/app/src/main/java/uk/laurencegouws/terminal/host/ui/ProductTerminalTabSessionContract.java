package uk.laurencegouws.terminal.host.ui;

/**
 * Product terminal tab/session semantics for the current single-PTY native runtime.
 *
 * <p><strong>Single PTY:</strong> the host drives one native shell session at a time. Selecting a
 * different product terminal tab (distinct index after {@link AppShellNavigation} policy) triggers
 * a native shell restart and userland refresh. Prior tab transcript is not preserved.</p>
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
