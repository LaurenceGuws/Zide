package dev.zide.terminal.host;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.LongSupplier;

/** Functional callback adapter for {@link TerminalActivityLifecycleController.Host}. */
public final class TerminalActivityLifecycleHostCallbacks implements TerminalActivityLifecycleController.Host {
    /** Functional callback for boolean native bridge calls. */
    public interface NativeBooleanCall {
        long call(boolean value);
    }

    /** Functional callback for surface resume debug flags. */
    public interface SurfaceResumeCall {
        void call(boolean debugRecreateSurfaceOnce, boolean debugResizeSurfaceOnce, boolean debugStartShellOnce);
    }

    private final BooleanSupplier nativeLoaded;
    private final LongSupplier nativeOnStart;
    private final LongSupplier nativeOnResume;
    private final LongSupplier nativeOnPause;
    private final LongSupplier nativeOnStop;
    private final NativeBooleanCall nativeOnWindowFocus;
    private final Consumer<String> appendEvent;
    private final TerminalSurfaceHostLifecycleCallbacks.NativeEventCallback callNative;
    private final Consumer<String> updateStatus;
    private final Runnable stopProductFrameLoop;
    private final Runnable refreshUserlandSessionOnPause;
    private final Runnable notifySurfacePause;
    private final SurfaceResumeCall notifySurfaceResume;

    public TerminalActivityLifecycleHostCallbacks(
            BooleanSupplier nativeLoaded,
            LongSupplier nativeOnStart,
            LongSupplier nativeOnResume,
            LongSupplier nativeOnPause,
            LongSupplier nativeOnStop,
            NativeBooleanCall nativeOnWindowFocus,
            Consumer<String> appendEvent,
            TerminalSurfaceHostLifecycleCallbacks.NativeEventCallback callNative,
            Consumer<String> updateStatus,
            Runnable stopProductFrameLoop,
            Runnable refreshUserlandSessionOnPause,
            Runnable notifySurfacePause,
            SurfaceResumeCall notifySurfaceResume) {
        this.nativeLoaded = nativeLoaded;
        this.nativeOnStart = nativeOnStart;
        this.nativeOnResume = nativeOnResume;
        this.nativeOnPause = nativeOnPause;
        this.nativeOnStop = nativeOnStop;
        this.nativeOnWindowFocus = nativeOnWindowFocus;
        this.appendEvent = appendEvent;
        this.callNative = callNative;
        this.updateStatus = updateStatus;
        this.stopProductFrameLoop = stopProductFrameLoop;
        this.refreshUserlandSessionOnPause = refreshUserlandSessionOnPause;
        this.notifySurfacePause = notifySurfacePause;
        this.notifySurfaceResume = notifySurfaceResume;
    }

    @Override
    public boolean nativeLoaded() {
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public long nativeOnStart() {
        return nativeOnStart.getAsLong();
    }

    @Override
    public long nativeOnResume() {
        return nativeOnResume.getAsLong();
    }

    @Override
    public long nativeOnPause() {
        return nativeOnPause.getAsLong();
    }

    @Override
    public long nativeOnStop() {
        return nativeOnStop.getAsLong();
    }

    @Override
    public long nativeOnWindowFocus(boolean hasFocus) {
        return nativeOnWindowFocus.call(hasFocus);
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public void callNative(String event, long seq) {
        callNative.call(event, seq);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }

    @Override
    public void stopProductFrameLoop() {
        stopProductFrameLoop.run();
    }

    @Override
    public void refreshUserlandSessionOnPause() {
        refreshUserlandSessionOnPause.run();
    }

    @Override
    public void notifySurfacePause() {
        notifySurfacePause.run();
    }

    @Override
    public void notifySurfaceResume(
            boolean debugRecreateSurfaceOnce,
            boolean debugResizeSurfaceOnce,
            boolean debugStartShellOnce) {
        notifySurfaceResume.call(
                debugRecreateSurfaceOnce,
                debugResizeSurfaceOnce,
                debugStartShellOnce);
    }
}
