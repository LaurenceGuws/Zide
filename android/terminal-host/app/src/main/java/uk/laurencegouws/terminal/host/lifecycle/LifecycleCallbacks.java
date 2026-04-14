package uk.laurencegouws.terminal.host.lifecycle;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.LongSupplier;

import uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks;

/** Functional callback adapter for {@link LifecycleController.Host}. */
public final class LifecycleCallbacks implements LifecycleController.Host {
    /** Functional callback for boolean native bridge calls. */
    public interface NativeBooleanCall {
        long call(boolean value);
    }

    /** Functional callback for surface resume debug flags. */
    public interface SurfaceResumeCall {
        void call(boolean debugRecreateSurfaceOnce, boolean debugResizeSurfaceOnce, boolean debugStartShellOnce);
    }

    public static final class NativeLifecycleBundle {
        final LongSupplier nativeOnStart;
        final LongSupplier nativeOnResume;
        final LongSupplier nativeOnPause;
        final LongSupplier nativeOnStop;
        final NativeBooleanCall nativeOnWindowFocus;
        final SurfaceLifecycleCallbacks.NativeEventCallback callNative;

        private NativeLifecycleBundle(
                LongSupplier nativeOnStart,
                LongSupplier nativeOnResume,
                LongSupplier nativeOnPause,
                LongSupplier nativeOnStop,
                NativeBooleanCall nativeOnWindowFocus,
                SurfaceLifecycleCallbacks.NativeEventCallback callNative) {
            this.nativeOnStart = nativeOnStart;
            this.nativeOnResume = nativeOnResume;
            this.nativeOnPause = nativeOnPause;
            this.nativeOnStop = nativeOnStop;
            this.nativeOnWindowFocus = nativeOnWindowFocus;
            this.callNative = callNative;
        }

        public static NativeLifecycleBundle of(
                LongSupplier nativeOnStart,
                LongSupplier nativeOnResume,
                LongSupplier nativeOnPause,
                LongSupplier nativeOnStop,
                NativeBooleanCall nativeOnWindowFocus,
                SurfaceLifecycleCallbacks.NativeEventCallback callNative) {
            return new NativeLifecycleBundle(
                    nativeOnStart,
                    nativeOnResume,
                    nativeOnPause,
                    nativeOnStop,
                    nativeOnWindowFocus,
                    callNative);
        }
    }

    private final BooleanSupplier nativeLoaded;
    private final NativeLifecycleBundle nativeLifecycleBundle;
    private final Consumer<String> appendEvent;
    private final Consumer<String> updateStatus;
    private final Runnable stopProductFrameLoop;
    private final Runnable refreshUserlandSessionOnPause;
    private final Runnable notifySurfacePause;
    private final SurfaceResumeCall notifySurfaceResume;

    public LifecycleCallbacks(
            BooleanSupplier nativeLoaded,
            NativeLifecycleBundle nativeLifecycleBundle,
            Consumer<String> appendEvent,
            Consumer<String> updateStatus,
            Runnable stopProductFrameLoop,
            Runnable refreshUserlandSessionOnPause,
            Runnable notifySurfacePause,
            SurfaceResumeCall notifySurfaceResume) {
        this.nativeLoaded = nativeLoaded;
        this.nativeLifecycleBundle = nativeLifecycleBundle;
        this.appendEvent = appendEvent;
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
        return nativeLifecycleBundle.nativeOnStart.getAsLong();
    }

    @Override
    public long nativeOnResume() {
        return nativeLifecycleBundle.nativeOnResume.getAsLong();
    }

    @Override
    public long nativeOnPause() {
        return nativeLifecycleBundle.nativeOnPause.getAsLong();
    }

    @Override
    public long nativeOnStop() {
        return nativeLifecycleBundle.nativeOnStop.getAsLong();
    }

    @Override
    public long nativeOnWindowFocus(boolean hasFocus) {
        return nativeLifecycleBundle.nativeOnWindowFocus.call(hasFocus);
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public void callNative(String event, long seq) {
        nativeLifecycleBundle.callNative.call(event, seq);
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
