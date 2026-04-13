package dev.zide.terminal.host;

import java.util.function.Consumer;

/** Functional callback adapter for {@link TerminalRuntimeAssetsHostBridge}. */
public final class TerminalRuntimeAssetsHostCallbacks implements TerminalRuntimeAssetsHostBridge.Callbacks {
    private final Consumer<String> appendEvent;

    public TerminalRuntimeAssetsHostCallbacks(Consumer<String> appendEvent) {
        this.appendEvent = appendEvent;
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }
}
