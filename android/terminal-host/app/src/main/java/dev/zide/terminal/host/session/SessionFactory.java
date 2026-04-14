package dev.zide.terminal.host.session;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.IntSupplier;

import dev.zide.terminal.host.userland.SessionBridge;
import dev.zide.terminal.host.userland.SessionCallbacks;
import dev.zide.terminal.session.ShellSessionController;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandRelease;

/** Session host assembly helpers. */
public final class SessionFactory {
    private SessionFactory() {
    }

    public static ShellSessionController createShellSessionController(
            String readinessStampPath,
            String shellPath,
            UserlandRelease userlandRelease,
            boolean nativeLoaded,
            IntSupplier restart,
            IntSupplier poll,
            BooleanSupplier isAlive) {
        return new ShellSessionController(
                new ShellBridge(new ShellCallbacks(
                        restart,
                        poll,
                        isAlive)),
                readinessStampPath,
                shellPath,
                userlandRelease,
                nativeLoaded);
    }

    public static SessionBridge createUserlandSessionHostBridge(
            Consumer<String> appendEvent,
            Function<Integer, String> shellStartStatusLabel,
            Consumer<UserlandReadinessState> applyReadinessState,
            Runnable refreshProductShellState,
            Runnable refreshDebugStatusSurface,
            Consumer<String> updateStatus) {
        return new SessionBridge(
                new SessionCallbacks(
                        appendEvent,
                        shellStartStatusLabel,
                        applyReadinessState,
                        refreshProductShellState,
                        refreshDebugStatusSurface,
                        updateStatus));
    }
}
