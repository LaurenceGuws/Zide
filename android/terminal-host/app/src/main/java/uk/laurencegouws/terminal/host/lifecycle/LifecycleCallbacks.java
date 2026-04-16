package uk.laurencegouws.terminal.host.lifecycle;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks;

/** Functional callback adapter for {@link LifecycleController.Host}. */
public final class LifecycleCallbacks implements LifecycleController.Host {
    /** Functional callback for surface resume debug flags. */
    public interface SurfaceResumeCall {
        void call(boolean debugRecreateSurfaceOnce, boolean debugResizeSurfaceOnce, boolean debugStartShellOnce);
    }

    public static final class LifecycleHostCallbacks {
        final Supplier<String> nativeLoadError;
        final Consumer<String> appendEvent;
        final Consumer<String> updateStatus;
        final Runnable stopProductFrameLoop;
        final Runnable refreshUserlandSessionOnPause;
        final Runnable notifySurfacePause;
        final SurfaceResumeCall notifySurfaceResume;

        private LifecycleHostCallbacks(
                Supplier<String> nativeLoadError,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                Runnable stopProductFrameLoop,
                Runnable refreshUserlandSessionOnPause,
                Runnable notifySurfacePause,
                SurfaceResumeCall notifySurfaceResume) {
            this.nativeLoadError = nativeLoadError;
            this.appendEvent = appendEvent;
            this.updateStatus = updateStatus;
            this.stopProductFrameLoop = stopProductFrameLoop;
            this.refreshUserlandSessionOnPause = refreshUserlandSessionOnPause;
            this.notifySurfacePause = notifySurfacePause;
            this.notifySurfaceResume = notifySurfaceResume;
        }

        public static LifecycleHostCallbacks of(
                Supplier<String> nativeLoadError,
                Consumer<String> appendEvent,
                Consumer<String> updateStatus,
                Runnable stopProductFrameLoop,
                Runnable refreshUserlandSessionOnPause,
                Runnable notifySurfacePause,
                SurfaceResumeCall notifySurfaceResume) {
            return new LifecycleHostCallbacks(
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
    private final SurfaceLifecycleCallbacks.NativeEventCallback callNative;

    public LifecycleCallbacks(
            LifecycleHostCallbacks lifecycleHostCallbacks,
            SurfaceLifecycleCallbacks.NativeEventCallback callNative) {
        this.lifecycleHostCallbacks = lifecycleHostCallbacks;
        this.callNative = callNative;
    }

    @Override
    public boolean nativeLoaded() {
        return NativeBridge.nativeLoaded();
    }

    @Override
    public long nativeOnStart() {
        return NativeBridge.nativeOnStartBridge();
    }

    @Override
    public String nativeLoadError() {
        return lifecycleHostCallbacks.nativeLoadError.get();
    }

    @Override
    public long nativeOnCreate() {
        return NativeBridge.nativeOnCreateBridge();
    }

    @Override
    public long nativeOnResume() {
        return NativeBridge.nativeOnResumeBridge();
    }

    @Override
    public long nativeOnPause() {
        return NativeBridge.nativeOnPauseBridge();
    }

    @Override
    public long nativeOnStop() {
        return NativeBridge.nativeOnStopBridge();
    }

    @Override
    public long nativeOnWindowFocus(boolean hasFocus) {
        return NativeBridge.nativeOnWindowFocusBridge(hasFocus);
    }

    @Override
    public void appendEvent(String event) {
        lifecycleHostCallbacks.appendEvent.accept(event);
    }

    @Override
    public void callNative(String event, long seq) {
        callNative.call(event, seq);
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
