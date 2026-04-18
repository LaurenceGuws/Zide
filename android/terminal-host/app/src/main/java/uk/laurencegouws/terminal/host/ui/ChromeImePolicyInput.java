package uk.laurencegouws.terminal.host.ui;

/**
 * Harness-owned chrome IME policy input for {@link ChromeFactory} assembly.
 *
 * <p>Surfaces the same operations as the IME slice of {@link ChromeBridge.Callbacks}
 * / {@link ChromeController.Host} so chrome callback construction does not take raw
 * {@link java.util.function.BooleanSupplier} / {@link java.util.function.Consumer}
 * for visibility state.</p>
 */
public interface ChromeImePolicyInput {
    boolean chromeImeVisibilityPresent();

    void applyChromeImeVisibilityHidden();

    void applyChromeImeVisibilityFromOpenAttempt(boolean softInputShown, boolean shellInputHasFocus);
}
