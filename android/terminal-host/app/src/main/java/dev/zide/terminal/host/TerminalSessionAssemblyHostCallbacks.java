package dev.zide.terminal.host;

import android.content.Context;
import android.os.Handler;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;
import java.util.function.Supplier;

import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandRelease;

/** Functional callback adapter for {@link TerminalSessionAssembly.Host}. */
public final class TerminalSessionAssemblyHostCallbacks implements TerminalSessionAssembly.Host {
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
    private final IntSupplier nativeRestartShellSession;
    private final IntSupplier nativePollShellSession;
    private final BooleanSupplier nativeIsShellSessionAlive;

    public TerminalSessionAssemblyHostCallbacks(
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
            IntSupplier nativeRestartShellSession,
            IntSupplier nativePollShellSession,
            BooleanSupplier nativeIsShellSessionAlive) {
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
        this.nativeRestartShellSession = nativeRestartShellSession;
        this.nativePollShellSession = nativePollShellSession;
        this.nativeIsShellSessionAlive = nativeIsShellSessionAlive;
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
    public int nativeRestartShellSession() {
        return nativeRestartShellSession.getAsInt();
    }

    @Override
    public int nativePollShellSession() {
        return nativePollShellSession.getAsInt();
    }

    @Override
    public boolean nativeIsShellSessionAlive() {
        return nativeIsShellSessionAlive.getAsBoolean();
    }
}
