package dev.zide.terminal.host;

import android.content.Context;

/**
 * Adapts activity-owned runtime-asset callbacks to {@link TerminalRuntimeAssetsController.Host}.
 */
public final class TerminalRuntimeAssetsHostBridge implements TerminalRuntimeAssetsController.Host {
    /** Activity callback used by runtime-assets staging. */
    public interface Callbacks {
        void appendEvent(String event);
    }

    private final Context context;
    private final Callbacks callbacks;

    public TerminalRuntimeAssetsHostBridge(Context context, Callbacks callbacks) {
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
