package uk.laurencegouws.terminal.host.session;

import android.content.Context;
import android.os.Handler;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandRelease;

/** Functional callback adapter for {@link SessionAssembly.Host}. */
public final class SessionAssemblyCallbacks implements SessionAssembly.Host {
    private final Context context;
    private final UserlandRelease userlandRelease;
    private final Handler handler;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Consumer<UserlandReadinessState> applyReadinessState;
    private final Runnable refreshShellState;
    private final Runnable refreshDebugStatusSurface;
    private final BooleanSupplier shouldRunFrameLoop;
    private final IntSupplier tickFrame;

    public SessionAssemblyCallbacks(
            Context context,
            UserlandRelease userlandRelease,
            Handler handler,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Consumer<UserlandReadinessState> applyReadinessState,
            Runnable refreshShellState,
            Runnable refreshDebugStatusSurface,
            BooleanSupplier shouldRunFrameLoop,
            IntSupplier tickFrame) {
        this.context = context;
        this.userlandRelease = userlandRelease;
        this.handler = handler;
        this.appendEvent = appendEvent;
        this.updateStatus = updateStatus;
        this.applyReadinessState = applyReadinessState;
        this.refreshShellState = refreshShellState;
        this.refreshDebugStatusSurface = refreshDebugStatusSurface;
        this.shouldRunFrameLoop = shouldRunFrameLoop;
        this.tickFrame = tickFrame;
    }

    @Override
    public Context context() {
        return context;
    }

    @Override
    public UserlandRelease userlandRelease() {
        return userlandRelease;
    }

    @Override
    public Handler handler() {
        return handler;
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
    public void refreshShellState() {
        refreshShellState.run();
    }

    @Override
    public void refreshDebugStatusSurface() {
        refreshDebugStatusSurface.run();
    }

    @Override
    public boolean shouldRunFrameLoop() {
        return shouldRunFrameLoop.getAsBoolean();
    }

    @Override
    public int tickFrame() {
        return tickFrame.getAsInt();
    }

    @Override
    public int nativeRestartSession() {
        return NativeBridge.nativeRestartSessionBridge();
    }

    @Override
    public int nativePollSession() {
        return NativeBridge.nativePollSessionBridge();
    }

    @Override
    public boolean nativeIsSessionAlive() {
        return NativeBridge.nativeIsSessionAliveBridge();
    }
}
