package uk.laurencegouws.terminal.host.lifecycle;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.LongSupplier;
import java.util.function.Supplier;

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

    public static final class NativeLifecycleCallbacks {
        final LongSupplier nativeOnCreate;
        final LongSupplier nativeOnStart;
        final LongSupplier nativeOnResume;
        final LongSupplier nativeOnPause;
        final LongSupplier nativeOnStop;
        final NativeBooleanCall nativeOnWindowFocus;
        final SurfaceLifecycleCallbacks.NativeEventCallback callNative;

        private NativeLifecycleCallbacks(
                LongSupplier nativeOnCreate,
                LongSupplier nativeOnStart,
                LongSupplier nativeOnResume,
                LongSupplier nativeOnPause,
                LongSupplier nativeOnStop,
                NativeBooleanCall nativeOnWindowFocus,
                SurfaceLifecycleCallbacks.NativeEventCallback callNative) {
            this.nativeOnCreate = nativeOnCreate;
            this.nativeOnStart = nativeOnStart;
            this.nativeOnResume = nativeOnResume;
            this.nativeOnPause = nativeOnPause;
            this.nativeOnStop = nativeOnStop;
            this.nativeOnWindowFocus = nativeOnWindowFocus;
            this.callNative = callNative;
        }

        public static NativeLifecycleCallbacks of(
                LongSupplier nativeOnCreate,
                LongSupplier nativeOnStart,
                LongSupplier nativeOnResume,
                LongSupplier nativeOnPause,
                LongSupplier nativeOnStop,
                NativeBooleanCall nativeOnWindowFocus,
                SurfaceLifecycleCallbacks.NativeEventCallback callNative) {
            return new NativeLifecycleCallbacks(
                    nativeOnCreate,
                    nativeOnStart,
                    nativeOnResume,
                    nativeOnPause,
                    nativeOnStop,
                    nativeOnWindowFocus,
                    callNative);
        }
    }

    public static final class LifecycleHostCallbacks {
        final BooleanSupplier nativeLoaded;
        final Supplier<String> nativeLoadError;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;
        final Runnable stopProductFrameLoop;
        final Runnable refreshUserlandSessionOnPause;
        final Runnable notifySurfacePause;
        final SurfaceResumeCall notifySurfaceResume;

        private LifecycleHostCallbacks(
                BooleanSupplier nativeLoaded,
                Supplier<String> nativeLoadError,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                Runnable stopProductFrameLoop,
                Runnable refreshUserlandSessionOnPause,
                Runnable notifySurfacePause,
                SurfaceResumeCall notifySurfaceResume) {
            this.nativeLoaded = nativeLoaded;
            this.nativeLoadError = nativeLoadError;
            this.appendEvent = appendEvent;
            this.updateStatus = updateStatus;
            this.stopProductFrameLoop = stopProductFrameLoop;
            this.refreshUserlandSessionOnPause = refreshUserlandSessionOnPause;
            this.notifySurfacePause = notifySurfacePause;
            this.notifySurfaceResume = notifySurfaceResume;
        }

        public static LifecycleHostCallbacks of(
                BooleanSupplier nativeLoaded,
                Supplier<String> nativeLoadError,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                Runnable stopProductFrameLoop,
                Runnable refreshUserlandSessionOnPause,
                Runnable notifySurfacePause,
                SurfaceResumeCall notifySurfaceResume) {
            return new LifecycleHostCallbacks(
                    nativeLoaded,
                    nativeLoadError,
                    appendEvent,
                    updateStatus,
                    stopProductFrameLoop,
                    refreshUserlandSessionOnPause,
                    notifySurfacePause,
                    notifySurfaceResume);
        }
    }

    private final LifecycleHostCallbacks lifecycleHostCallbacks;
    private final NativeLifecycleCallbacks nativeLifecycleCallbacks;

    public LifecycleCallbacks(
            LifecycleHostCallbacks lifecycleHostCallbacks,
            NativeLifecycleCallbacks nativeLifecycleCallbacks) {
        this.lifecycleHostCallbacks = lifecycleHostCallbacks;
        this.nativeLifecycleCallbacks = nativeLifecycleCallbacks;
    }

    @Override
    public boolean nativeLoaded() {
        return lifecycleHostCallbacks.nativeLoaded.getAsBoolean();
    }

    @Override
    public long nativeOnStart() {
        return nativeLifecycleCallbacks.nativeOnStart.getAsLong();
    }

    @Override
    public String nativeLoadError() {
        return lifecycleHostCallbacks.nativeLoadError.get();
    }

    @Override
    public long nativeOnCreate() {
        return nativeLifecycleCallbacks.nativeOnCreate.getAsLong();
    }

    @Override
    public long nativeOnResume() {
        return nativeLifecycleCallbacks.nativeOnResume.getAsLong();
    }

    @Override
    public long nativeOnPause() {
        return nativeLifecycleCallbacks.nativeOnPause.getAsLong();
    }

    @Override
    public long nativeOnStop() {
        return nativeLifecycleCallbacks.nativeOnStop.getAsLong();
    }

    @Override
    public long nativeOnWindowFocus(boolean hasFocus) {
        return nativeLifecycleCallbacks.nativeOnWindowFocus.call(hasFocus);
    }

    @Override
    public void appendEvent(String event) {
        lifecycleHostCallbacks.appendEvent.accept(event);
    }

    @Override
    public void callNative(String event, long seq) {
        nativeLifecycleCallbacks.callNative.call(event, seq);
    }

    @Override
    public void updateStatus(String statusLabel) {
        lifecycleHostCallbacks.updateStatus.accept(statusLabel);
    }

    @Override
    public void stopProductFrameLoop() {
        lifecycleHostCallbacks.stopProductFrameLoop.run();
    }

    @Override
    public void refreshUserlandSessionOnPause() {
        lifecycleHostCallbacks.refreshUserlandSessionOnPause.run();
    }

    @Override
    public void notifySurfacePause() {
        lifecycleHostCallbacks.notifySurfacePause.run();
    }

    @Override
    public void notifySurfaceResume(
            boolean debugRecreateSurfaceOnce,
            boolean debugResizeSurfaceOnce,
            boolean debugStartShellOnce) {
        lifecycleHostCallbacks.notifySurfaceResume.call(
                debugRecreateSurfaceOnce,
                debugResizeSurfaceOnce,
                debugStartShellOnce);
    }
}
