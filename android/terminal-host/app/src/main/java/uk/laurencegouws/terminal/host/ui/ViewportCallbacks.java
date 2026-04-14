package uk.laurencegouws.terminal.host.ui;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;

/** Functional callback adapter for {@link ViewportBridge}. */
public final class ViewportCallbacks implements ViewportBridge.Callbacks {
    private final BooleanSupplier imeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final Consumer<String> notifyVisibleViewport;

    public ViewportCallbacks(
            BooleanSupplier imeVisible,
            Consumer<Boolean> setImeVisible,
            Consumer<String> notifyVisibleViewport) {
        this.imeVisible = imeVisible;
        this.setImeVisible = setImeVisible;
        this.notifyVisibleViewport = notifyVisibleViewport;
    }

    @Override
    public boolean imeVisible() {
        return imeVisible.getAsBoolean();
    }

    @Override
    public void setImeVisible(boolean imeVisible) {
        setImeVisible.accept(imeVisible);
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        notifyVisibleViewport.accept(reason);
    }
}
