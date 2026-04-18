package uk.laurencegouws.terminal.host.ui;

/**
 * Read/write IME visibility scratch for host callback wiring.
 *
 * <p>Implemented by {@link ProductHostImeState} so status/viewport/input adapters and
 * {@link uk.laurencegouws.terminal.host.input.InputFactory} consume one carrier-backed seam
 * instead of duplicated {@link java.util.function.BooleanSupplier} /
 * {@link java.util.function.Consumer} pairs.</p>
 */
public interface HostImeStateAccess {
    boolean imeVisible();

    void setImeVisible(boolean visible);
}
