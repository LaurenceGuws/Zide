package uk.laurencegouws.terminal.host.session;

import java.util.function.BooleanSupplier;
import java.util.function.IntSupplier;

/** Functional callback adapter for {@link ShellBridge}. */
public final class ShellCallbacks implements ShellBridge.Callbacks {
    private final IntSupplier restart;
    private final IntSupplier poll;
    private final BooleanSupplier isAlive;

    public ShellCallbacks(
            IntSupplier restart,
            IntSupplier poll,
            BooleanSupplier isAlive) {
        this.restart = restart;
        this.poll = poll;
        this.isAlive = isAlive;
    }

    @Override
    public int restart() {
        return restart.getAsInt();
    }

    @Override
    public int poll() {
        return poll.getAsInt();
    }

    @Override
    public boolean isAlive() {
        return isAlive.getAsBoolean();
    }
}
