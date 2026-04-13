package dev.zide.terminal.host;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;

/** Functional callback adapter for {@link TerminalViewportHostBridge}. */
public final class TerminalViewportHostCallbacks implements TerminalViewportHostBridge.Callbacks {
    private final BooleanSupplier imeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final Consumer<String> notifyVisibleViewport;

    public TerminalViewportHostCallbacks(
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
