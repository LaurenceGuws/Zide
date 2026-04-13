package dev.zide.terminal.host;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.IntSupplier;

import dev.zide.terminal.session.ShellSessionController;
import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandRelease;

/** Session host assembly helpers. */
public final class TerminalSessionHostFactory {
    private TerminalSessionHostFactory() {
    }

    public static ShellSessionController createShellSessionController(
            String bootstrapStampPath,
            String shellPath,
            UserlandRelease userlandRelease,
            boolean nativeLoaded,
            IntSupplier restart,
            IntSupplier poll,
            BooleanSupplier isAlive) {
        return new ShellSessionController(
                new TerminalShellSessionBridge(new TerminalShellSessionCallbacks(
                        restart,
                        poll,
                        isAlive)),
                bootstrapStampPath,
                shellPath,
                userlandRelease,
                nativeLoaded);
    }

    public static TerminalUserlandSessionHostBridge createUserlandSessionHostBridge(
            Consumer<String> appendEvent,
            Function<Integer, String> shellStartStatusLabel,
            Consumer<UserlandBootstrapState> applyBootstrapState,
            Runnable refreshProductShellState,
            Runnable refreshDebugStatusSurface,
            Consumer<String> updateStatus) {
        return new TerminalUserlandSessionHostBridge(
                new TerminalUserlandSessionHostCallbacks(
                        appendEvent,
                        shellStartStatusLabel,
                        applyBootstrapState,
                        refreshProductShellState,
                        refreshDebugStatusSurface,
                        updateStatus));
    }
}
