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

    public static final class LifecycleHostBundle {
        final BooleanSupplier nativeLoaded;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;
        final Runnable stopProductFrameLoop;
        final Runnable refreshUserlandSessionOnPause;
        final Runnable notifySurfacePause;
        final SurfaceResumeCall notifySurfaceResume;

        private LifecycleHostBundle(
                BooleanSupplier nativeLoaded,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                Runnable stopProductFrameLoop,
                Runnable refreshUserlandSessionOnPause,
                Runnable notifySurfacePause,
                SurfaceResumeCall notifySurfaceResume) {
            this.nativeLoaded = nativeLoaded;
            this.appendEvent = appendEvent;
            this.updateStatus = updateStatus;
            this.stopProductFrameLoop = stopProductFrameLoop;
            this.refreshUserlandSessionOnPause = refreshUserlandSessionOnPause;
            this.notifySurfacePause = notifySurfacePause;
            this.notifySurfaceResume = notifySurfaceResume;
        }

        public static LifecycleHostBundle of(
                BooleanSupplier nativeLoaded,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                Runnable stopProductFrameLoop,
                Runnable refreshUserlandSessionOnPause,
                Runnable notifySurfacePause,
                SurfaceResumeCall notifySurfaceResume) {
            return new LifecycleHostBundle(
                    nativeLoaded,
                    appendEvent,
                    updateStatus,
                    stopProductFrameLoop,
                    refreshUserlandSessionOnPause,
                    notifySurfacePause,
                    notifySurfaceResume);
        }
    }

    private final LifecycleHostBundle lifecycleHostBundle;
    private final NativeLifecycleBundle nativeLifecycleBundle;

    public LifecycleCallbacks(
            LifecycleHostBundle lifecycleHostBundle,
            NativeLifecycleBundle nativeLifecycleBundle) {
        this.lifecycleHostBundle = lifecycleHostBundle;
        this.nativeLifecycleBundle = nativeLifecycleBundle;
    }

    @Override
    public boolean nativeLoaded() {
        return lifecycleHostBundle.nativeLoaded.getAsBoolean();
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
        lifecycleHostBundle.appendEvent.accept(event);
    }

    @Override
    public void callNative(String event, long seq) {
        nativeLifecycleBundle.callNative.call(event, seq);
    }

    @Override
    public void updateStatus(String statusLabel) {
        lifecycleHostBundle.updateStatus.accept(statusLabel);
    }

    @Override
    public void stopProductFrameLoop() {
        lifecycleHostBundle.stopProductFrameLoop.run();
    }

    @Override
    public void refreshUserlandSessionOnPause() {
        lifecycleHostBundle.refreshUserlandSessionOnPause.run();
    }

    @Override
    public void notifySurfacePause() {
        lifecycleHostBundle.notifySurfacePause.run();
    }

    @Override
    public void notifySurfaceResume(
            boolean debugRecreateSurfaceOnce,
            boolean debugResizeSurfaceOnce,
            boolean debugStartShellOnce) {
        lifecycleHostBundle.notifySurfaceResume.call(
                debugRecreateSurfaceOnce,
                debugResizeSurfaceOnce,
                debugStartShellOnce);
    }
}
