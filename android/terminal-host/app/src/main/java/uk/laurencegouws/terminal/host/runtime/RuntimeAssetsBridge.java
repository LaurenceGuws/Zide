package uk.laurencegouws.terminal.host.runtime;

import android.content.Context;

/**
 * Adapts activity-owned runtime-asset callbacks to {@link RuntimeAssetsController.Host}.
 */
public final class RuntimeAssetsBridge implements RuntimeAssetsController.Host {
    /** Harness callback used by runtime-assets staging. */
    public interface Callbacks {
        void appendEvent(String event);
    }

    private final Context context;
    private final Callbacks callbacks;

    public RuntimeAssetsBridge(Context context, Callbacks callbacks) {
        this.context = context;
        this.callbacks = callbacks;
    }

    @Override
    public Context context() {
        return context;
    }

    @Override
    public void appendEvent(String event) {
        callbacks.appendEvent(event);
    }
}
