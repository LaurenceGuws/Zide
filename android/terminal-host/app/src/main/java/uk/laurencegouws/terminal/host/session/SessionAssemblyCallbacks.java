package uk.laurencegouws.terminal.host.session;

import android.content.Context;
import android.os.Handler;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.TerminalNativeBridge;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandRelease;

/** Functional callback adapter for {@link SessionAssembly.Host}. */
public final class SessionAssemblyCallbacks implements SessionAssembly.Host {
    private final Supplier<Context> context;
    private final Supplier<UserlandRelease> userlandRelease;
    private final Supplier<Handler> handler;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Consumer<UserlandReadinessState> applyReadinessState;
    private final Runnable refreshProductShellState;
    private final Runnable refreshDebugStatusSurface;
    private final BooleanSupplier shouldRunProductFrameLoop;
    private final IntSupplier tickProductFrame;

    public SessionAssemblyCallbacks(
            Supplier<Context> context,
            Supplier<UserlandRelease> userlandRelease,
            Supplier<Handler> handler,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Consumer<UserlandReadinessState> applyReadinessState,
            Runnable refreshProductShellState,
            Runnable refreshDebugStatusSurface,
            BooleanSupplier shouldRunProductFrameLoop,
            IntSupplier tickProductFrame) {
        this.context = context;
        this.userlandRelease = userlandRelease;
        this.handler = handler;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.applyReadinessState = applyReadinessState;
        this.refreshProductShellState = refreshProductShellState;
        this.refreshDebugStatusSurface = refreshDebugStatusSurface;
        this.shouldRunProductFrameLoop = shouldRunProductFrameLoop;
        this.tickProductFrame = tickProductFrame;
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
        return TerminalNativeBridge.nativeRestartSessionBridge();
    }

    @Override
    public int nativePollSession() {
        return TerminalNativeBridge.nativePollSessionBridge();
    }

    @Override
    public boolean nativeIsSessionAlive() {
        return TerminalNativeBridge.nativeIsSessionAliveBridge();
    }
}
