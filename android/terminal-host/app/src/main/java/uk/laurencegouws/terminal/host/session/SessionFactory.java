package uk.laurencegouws.terminal.host.session;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntFunction;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.host.userland.SessionBridge;
import uk.laurencegouws.terminal.host.userland.SessionCallbacks;
import uk.laurencegouws.terminal.session.ShellSessionController;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandRelease;

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
            IntFunction<String> sessionStartStatusLabel,
            Consumer<UserlandReadinessState> applyReadinessState,
            Runnable refreshProductShellState,
            Runnable refreshDebugStatusSurface,
            Consumer<String> updateStatus) {
        return new SessionBridge(
                new SessionCallbacks(
                        appendEvent,
                        sessionStartStatusLabel,
                        applyReadinessState,
                        refreshProductShellState,
                        refreshDebugStatusSurface,
                        updateStatus));
    }
}
