package uk.laurencegouws.terminal.host.lifecycle;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.TerminalNativeBridge;
import uk.laurencegouws.terminal.host.surface.SurfaceLifecycleCallbacks;

/** Functional callback adapter for {@link LifecycleController.Host}. */
public final class LifecycleCallbacks implements LifecycleController.Host {
    /** Functional callback for surface resume debug flags. */
    public interface SurfaceResumeCall {
        void call(boolean debugRecreateSurfaceOnce, boolean debugResizeSurfaceOnce, boolean debugStartShellOnce);
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
    private final SurfaceLifecycleCallbacks.NativeEventCallback callNative;

    public LifecycleCallbacks(
            LifecycleHostCallbacks lifecycleHostCallbacks,
            SurfaceLifecycleCallbacks.NativeEventCallback callNative) {
        this.lifecycleHostCallbacks = lifecycleHostCallbacks;
        this.callNative = callNative;
    }

    @Override
    public boolean nativeLoaded() {
        return lifecycleHostCallbacks.nativeLoaded.getAsBoolean();
    }

    @Override
    public long nativeOnStart() {
        return TerminalNativeBridge.nativeOnStartBridge();
    }

    @Override
    public String nativeLoadError() {
        return lifecycleHostCallbacks.nativeLoadError.get();
    }

    @Override
    public long nativeOnCreate() {
        return TerminalNativeBridge.nativeOnCreateBridge();
    }

    @Override
    public long nativeOnResume() {
        return TerminalNativeBridge.nativeOnResumeBridge();
    }

    @Override
    public long nativeOnPause() {
        return TerminalNativeBridge.nativeOnPauseBridge();
    }

    @Override
    public long nativeOnStop() {
        return TerminalNativeBridge.nativeOnStopBridge();
    }

    @Override
    public long nativeOnWindowFocus(boolean hasFocus) {
        return TerminalNativeBridge.nativeOnWindowFocusBridge(hasFocus);
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
