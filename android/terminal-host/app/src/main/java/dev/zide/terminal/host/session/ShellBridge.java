package dev.zide.terminal.host.session;

import dev.zide.terminal.session.ShellSessionController;

/**
 * Adapts native shell callbacks to {@link ShellSessionController.Bridge}.
 */
public final class ShellBridge implements ShellSessionController.Bridge {
    /** Native callbacks used by shell session control. */
    public interface Callbacks {
        int restart();

        int poll();

        boolean isAlive();
    }

    private final Callbacks callbacks;

    public ShellBridge(Callbacks callbacks) {
        this.callbacks = callbacks;
    }

    @Override
    public int restart() {
        return callbacks.restart();
    }

    @Override
    public int poll() {
        return callbacks.poll();
    }

    @Override
    public boolean isAlive() {
        return callbacks.isAlive();
    }
}
