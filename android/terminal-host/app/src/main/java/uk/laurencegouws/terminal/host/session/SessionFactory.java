package uk.laurencegouws.terminal.host.session;

import android.content.Context;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntFunction;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.session.ShellSessionController;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandRelease;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/** Session host assembly helpers. */
public final class SessionFactory {
    private SessionFactory() {
    }

    public static ShellSessionController createShellSessionController(
            Context context,
            Consumer<String> appendEvent,
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
                context,
                appendEvent,
                readinessStampPath,
                shellPath,
                userlandRelease,
                nativeLoaded);
    }

    public static UserlandSessionCoordinator.Host createUserlandSessionHost(
            Consumer<String> appendEvent,
            IntFunction<String> sessionStartStatusLabel,
            Consumer<UserlandReadinessState> applyReadinessState,
            Runnable refreshShellState,
            Runnable refreshStatusTelemetry,
            Consumer<String> updateStatus) {
        return new UserlandSessionCoordinator.Host() {
            @Override
            public void appendEvent(String event) {
                appendEvent.accept(event);
            }

            @Override
            public String sessionStartStatusLabel(int status) {
                return sessionStartStatusLabel.apply(status);
            }

            @Override
            public void applyReadinessState(UserlandReadinessState readinessState) {
                applyReadinessState.accept(readinessState);
            }

            @Override
            public void refreshShellState() {
                refreshShellState.run();
            }

            @Override
            public void refreshStatusTelemetry() {
                refreshStatusTelemetry.run();
            }

            @Override
            public void updateStatus(String statusLabel) {
                updateStatus.accept(statusLabel);
            }
        };
    }
}
