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

    private final Supplier<Context> context;
    private final Supplier<UserlandRelease> userlandRelease;
    private final BooleanSupplier nativeLoaded;
    private final Supplier<Handler> handler;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Consumer<UserlandReadinessState> applyReadinessState;
    private final Runnable refreshProductShellState;
    private final Runnable refreshDebugStatusSurface;
    private final BooleanSupplier shouldRunProductFrameLoop;
    private final IntSupplier tickProductFrame;
    private final NativeSessionBundle nativeSessionBundle;

    public SessionAssemblyCallbacks(
            Supplier<Context> context,
            Supplier<UserlandRelease> userlandRelease,
            BooleanSupplier nativeLoaded,
            Supplier<Handler> handler,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Consumer<UserlandReadinessState> applyReadinessState,
            Runnable refreshProductShellState,
            Runnable refreshDebugStatusSurface,
            BooleanSupplier shouldRunProductFrameLoop,
            IntSupplier tickProductFrame,
            NativeSessionBundle nativeSessionBundle) {
        this.context = context;
        this.userlandRelease = userlandRelease;
        this.nativeLoaded = nativeLoaded;
        this.handler = handler;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.applyReadinessState = applyReadinessState;
        this.refreshProductShellState = refreshProductShellState;
        this.refreshDebugStatusSurface = refreshDebugStatusSurface;
        this.shouldRunProductFrameLoop = shouldRunProductFrameLoop;
        this.tickProductFrame = tickProductFrame;
        this.nativeSessionBundle = nativeSessionBundle;
    }

    @Override
    public Context context() {
        return context.get();
    }

    @Override
    public UserlandRelease userlandRelease() {
        return userlandRelease.get();
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public Handler handler() {
        return handler.get();
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }

    @Override
    public void applyReadinessState(UserlandReadinessState readinessState) {
        applyReadinessState.accept(readinessState);
    }

    @Override
    public void refreshProductShellState() {
        refreshProductShellState.run();
    }

    @Override
    public void refreshDebugStatusSurface() {
        refreshDebugStatusSurface.run();
    }

    @Override
    public boolean shouldRunProductFrameLoop() {
        return shouldRunProductFrameLoop.getAsBoolean();
    }

    @Override
    public int tickProductFrame() {
        return tickProductFrame.getAsInt();
    }

    @Override
    public int nativeRestartSession() {
        return nativeSessionBundle.nativeRestartSession.getAsInt();
    }

    @Override
    public int nativePollSession() {
        return nativeSessionBundle.nativePollSession.getAsInt();
    }

    @Override
    public boolean nativeIsSessionAlive() {
        return nativeSessionBundle.nativeIsSessionAlive.getAsBoolean();
    }
}
