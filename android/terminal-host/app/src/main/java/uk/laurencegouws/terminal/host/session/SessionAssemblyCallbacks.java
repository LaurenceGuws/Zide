package uk.laurencegouws.terminal.host.session;

import android.content.Context;
import android.os.Handler;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandRelease;

/** Functional callback adapter for {@link SessionAssembly.Host}. */
public final class SessionAssemblyCallbacks implements SessionAssembly.Host {
    public static final class SessionHostCallbacks {
        final Supplier<Context> context;
        final Supplier<UserlandRelease> userlandRelease;
        final Supplier<Handler> handler;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;

        private SessionHostCallbacks(
                Supplier<Context> context,
                Supplier<UserlandRelease> userlandRelease,
                Supplier<Handler> handler,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus) {
            this.context = context;
            this.userlandRelease = userlandRelease;
            this.handler = handler;
            this.appendEvent = appendEvent;
            this.updateStatus = updateStatus;
        }

        public static SessionHostCallbacks of(
                Supplier<Context> context,
                Supplier<UserlandRelease> userlandRelease,
                Supplier<Handler> handler,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus) {
            return new SessionHostCallbacks(
                    context,
                    userlandRelease,
                    handler,
                    appendEvent,
                    updateStatus);
        }
    }

    public static final class NativeSessionCallbacks {
        final IntSupplier nativeRestartSession;
        final IntSupplier nativePollSession;
        final BooleanSupplier nativeIsSessionAlive;

        private NativeSessionCallbacks(
                IntSupplier nativeRestartSession,
                IntSupplier nativePollSession,
                BooleanSupplier nativeIsSessionAlive) {
            this.nativeRestartSession = nativeRestartSession;
            this.nativePollSession = nativePollSession;
            this.nativeIsSessionAlive = nativeIsSessionAlive;
        }

        public static NativeSessionCallbacks of(
                IntSupplier nativeRestartSession,
                IntSupplier nativePollSession,
                BooleanSupplier nativeIsSessionAlive) {
            return new NativeSessionCallbacks(
                    nativeRestartSession,
                    nativePollSession,
                    nativeIsSessionAlive);
        }
    }

    public static final class SessionRuntimeCallbacks {
        final BooleanSupplier nativeLoaded;
        final Consumer<UserlandReadinessState> applyReadinessState;
        final Runnable refreshProductShellState;
        final Runnable refreshDebugStatusSurface;
        final BooleanSupplier shouldRunProductFrameLoop;
        final IntSupplier tickProductFrame;
        final NativeSessionCallbacks nativeSessionCallbacks;

        private SessionRuntimeCallbacks(
                BooleanSupplier nativeLoaded,
                Consumer<UserlandReadinessState> applyReadinessState,
                Runnable refreshProductShellState,
                Runnable refreshDebugStatusSurface,
                BooleanSupplier shouldRunProductFrameLoop,
                IntSupplier tickProductFrame,
                NativeSessionCallbacks nativeSessionCallbacks) {
            this.nativeLoaded = nativeLoaded;
            this.applyReadinessState = applyReadinessState;
            this.refreshProductShellState = refreshProductShellState;
            this.refreshDebugStatusSurface = refreshDebugStatusSurface;
            this.shouldRunProductFrameLoop = shouldRunProductFrameLoop;
            this.tickProductFrame = tickProductFrame;
            this.nativeSessionCallbacks = nativeSessionCallbacks;
        }

        public static SessionRuntimeCallbacks of(
                BooleanSupplier nativeLoaded,
                Consumer<UserlandReadinessState> applyReadinessState,
                Runnable refreshProductShellState,
                Runnable refreshDebugStatusSurface,
                BooleanSupplier shouldRunProductFrameLoop,
                IntSupplier tickProductFrame,
                NativeSessionCallbacks nativeSessionCallbacks) {
            return new SessionRuntimeCallbacks(
                    nativeLoaded,
                    applyReadinessState,
                    refreshProductShellState,
                    refreshDebugStatusSurface,
                    shouldRunProductFrameLoop,
                    tickProductFrame,
                    nativeSessionCallbacks);
        }
    }

    private final SessionHostCallbacks sessionHostCallbacks;
    private final SessionRuntimeCallbacks sessionRuntimeCallbacks;

    public SessionAssemblyCallbacks(
            SessionHostCallbacks sessionHostCallbacks,
            SessionRuntimeCallbacks sessionRuntimeCallbacks) {
        this.sessionHostCallbacks = sessionHostCallbacks;
        this.sessionRuntimeCallbacks = sessionRuntimeCallbacks;
    }

    @Override
    public Context context() {
        return sessionHostCallbacks.context.get();
    }

    @Override
    public UserlandRelease userlandRelease() {
        return sessionHostCallbacks.userlandRelease.get();
    }

    @Override
    public boolean nativeLoaded() {
        return sessionRuntimeCallbacks.nativeLoaded.getAsBoolean();
    }

    @Override
    public Handler handler() {
        return sessionHostCallbacks.handler.get();
    }

    @Override
    public void appendEvent(String event) {
        sessionHostCallbacks.appendEvent.accept(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        sessionHostCallbacks.updateStatus.accept(statusLabel);
    }

    @Override
    public void applyReadinessState(UserlandReadinessState readinessState) {
        sessionRuntimeCallbacks.applyReadinessState.accept(readinessState);
    }

    @Override
    public void refreshProductShellState() {
        sessionRuntimeCallbacks.refreshProductShellState.run();
    }

    @Override
    public void refreshDebugStatusSurface() {
        sessionRuntimeCallbacks.refreshDebugStatusSurface.run();
    }

    @Override
    public boolean shouldRunProductFrameLoop() {
        return sessionRuntimeCallbacks.shouldRunProductFrameLoop.getAsBoolean();
    }

    @Override
    public int tickProductFrame() {
        return sessionRuntimeCallbacks.tickProductFrame.getAsInt();
    }

    @Override
    public int nativeRestartSession() {
        return sessionRuntimeCallbacks.nativeSessionCallbacks.nativeRestartSession.getAsInt();
    }

    @Override
    public int nativePollSession() {
        return sessionRuntimeCallbacks.nativeSessionCallbacks.nativePollSession.getAsInt();
    }

    @Override
    public boolean nativeIsSessionAlive() {
        return sessionRuntimeCallbacks.nativeSessionCallbacks.nativeIsSessionAlive.getAsBoolean();
    }
}
