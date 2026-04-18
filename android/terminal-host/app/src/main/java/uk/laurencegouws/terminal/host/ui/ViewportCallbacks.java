package uk.laurencegouws.terminal.host.ui;

import java.util.function.Consumer;

/** Functional callback adapter for {@link ViewportBridge}. */
public final class ViewportCallbacks implements ViewportBridge.Callbacks {
    private final HostImeStateAccess hostImeState;
    private final Consumer<String> notifyVisibleViewport;

    public ViewportCallbacks(HostImeStateAccess hostImeState, Consumer<String> notifyVisibleViewport) {
        this.hostImeState = hostImeState;
        this.notifyVisibleViewport = notifyVisibleViewport;
    }

    @Override
    public boolean imeVisible() {
        return hostImeState.imeVisible();
    }

    @Override
    public void setImeVisible(boolean imeVisible) {
        hostImeState.setImeVisible(imeVisible);
    }

    @Override
    public void notifyVisibleViewport(String reason) {
        notifyVisibleViewport.accept(reason);
    }
}
