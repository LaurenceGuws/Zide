package uk.laurencegouws.terminal.host.runtime;

import java.util.function.Consumer;

/** Functional callback adapter for {@link RuntimeAssetsBridge}. */
public final class RuntimeAssetsCallbacks implements RuntimeAssetsBridge.Callbacks {
    private final Consumer<String> appendEvent;

    public RuntimeAssetsCallbacks(Consumer<String> appendEvent) {
        this.appendEvent = appendEvent;
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }
}
