package uk.laurencegouws.terminal.host.ui;

/**
 * Harness-owned IME visibility read for surface/native viewport assembly (non-chrome).
 *
 * <p>Distinct from {@link ChromeImePolicyInput}, which carries chrome policy mutations for
 * {@link ChromeFactory}. Surface wiring only needs the current visibility bit for viewport/native
 * callbacks.</p>
 */
@FunctionalInterface
public interface SurfaceWidgetHostImeVisibility {
    boolean currentImeVisible();
}
