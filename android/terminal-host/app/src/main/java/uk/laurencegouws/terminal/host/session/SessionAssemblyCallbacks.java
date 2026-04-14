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
    public static final class SessionHostBundle {
        final Supplier<Context> context;
        final Supplier<UserlandRelease> userlandRelease;
        final Supplier<Handler> handler;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;

        private SessionHostBundle(
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

        public static SessionHostBundle of(
                Supplier<Context> context,
                Supplier<UserlandRelease> userlandRelease,
                Supplier<Handler> handler,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus) {
            return new SessionHostBundle(
                    context,
                    userlandRelease,
                    handler,
                    appendEvent,
                    updateStatus);
        }
    }

    public static final class NativeSessionBundle {
        final IntSupplier nativeRestartSession;
        final IntSupplier nativePollSession;
        final BooleanSupplier nativeIsSessionAlive;

        private NativeSessionBundle(
                IntSupplier nativeRestartSession,
                IntSupplier nativePollSession,
                BooleanSupplier nativeIsSessionAlive) {
            this.nativeRestartSession = nativeRestartSession;
            this.nativePollSession = nativePollSession;
            this.nativeIsSessionAlive = nativeIsSessionAlive;
        }

        public static NativeSessionBundle of(
                IntSupplier nativeRestartSession,
                IntSupplier nativePollSession,
                BooleanSupplier nativeIsSessionAlive) {
            return new NativeSessionBundle(
                    nativeRestartSession,
                    nativePollSession,
                    nativeIsSessionAlive);
        }
    }

    public static final class SessionRuntimeBundle {
        final BooleanSupplier nativeLoaded;
        final Consumer<UserlandReadinessState> applyReadinessState;
        final Runnable refreshProductShellState;
        final Runnable refreshDebugStatusSurface;
        final BooleanSupplier shouldRunProductFrameLoop;
        final IntSupplier tickProductFrame;
        final NativeSessionBundle nativeSessionBundle;

        private SessionRuntimeBundle(
                BooleanSupplier nativeLoaded,
                Consumer<UserlandReadinessState> applyReadinessState,
                Runnable refreshProductShellState,
                Runnable refreshDebugStatusSurface,
                BooleanSupplier shouldRunProductFrameLoop,
                IntSupplier tickProductFrame,
                NativeSessionBundle nativeSessionBundle) {
            this.nativeLoaded = nativeLoaded;
            this.applyReadinessState = applyReadinessState;
            this.refreshProductShellState = refreshProductShellState;
            this.refreshDebugStatusSurface = refreshDebugStatusSurface;
            this.shouldRunProductFrameLoop = shouldRunProductFrameLoop;
            this.tickProductFrame = tickProductFrame;
            this.nativeSessionBundle = nativeSessionBundle;
        }

        public static SessionRuntimeBundle of(
                BooleanSupplier nativeLoaded,
                Consumer<UserlandReadinessState> applyReadinessState,
                Runnable refreshProductShellState,
                Runnable refreshDebugStatusSurface,
                BooleanSupplier shouldRunProductFrameLoop,
                IntSupplier tickProductFrame,
                NativeSessionBundle nativeSessionBundle) {
            return new SessionRuntimeBundle(
                    nativeLoaded,
                    applyReadinessState,
                    refreshProductShellState,
                    refreshDebugStatusSurface,
                    shouldRunProductFrameLoop,
                    tickProductFrame,
                    nativeSessionBundle);
        }
    }

    private final SessionHostBundle sessionHostBundle;
    private final SessionRuntimeBundle sessionRuntimeBundle;

    public SessionAssemblyCallbacks(
            SessionHostBundle sessionHostBundle,
            SessionRuntimeBundle sessionRuntimeBundle) {
        this.sessionHostBundle = sessionHostBundle;
        this.sessionRuntimeBundle = sessionRuntimeBundle;
    }

    @Override
    public Context context() {
        return sessionHostBundle.context.get();
    }

    @Override
    public UserlandRelease userlandRelease() {
        return sessionHostBundle.userlandRelease.get();
    }

    @Override
    public boolean nativeLoaded() {
        return sessionRuntimeBundle.nativeLoaded.getAsBoolean();
    }

    @Override
    public Handler handler() {
        return sessionHostBundle.handler.get();
    }

    @Override
    public void appendEvent(String event) {
        sessionHostBundle.appendEvent.accept(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        sessionHostBundle.updateStatus.accept(statusLabel);
    }

    @Override
    public void applyReadinessState(UserlandReadinessState readinessState) {
        sessionRuntimeBundle.applyReadinessState.accept(readinessState);
    }

    @Override
    public void refreshProductShellState() {
        sessionRuntimeBundle.refreshProductShellState.run();
    }

    @Override
    public void refreshDebugStatusSurface() {
        sessionRuntimeBundle.refreshDebugStatusSurface.run();
    }

    @Override
    public boolean shouldRunProductFrameLoop() {
        return sessionRuntimeBundle.shouldRunProductFrameLoop.getAsBoolean();
    }

    @Override
    public int tickProductFrame() {
        return sessionRuntimeBundle.tickProductFrame.getAsInt();
    }

    @Override
    public int nativeRestartSession() {
        return sessionRuntimeBundle.nativeSessionBundle.nativeRestartSession.getAsInt();
    }

    @Override
    public int nativePollSession() {
        return sessionRuntimeBundle.nativeSessionBundle.nativePollSession.getAsInt();
    }

    @Override
    public boolean nativeIsSessionAlive() {
        return sessionRuntimeBundle.nativeSessionBundle.nativeIsSessionAlive.getAsBoolean();
    }
}
