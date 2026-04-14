package uk.laurencegouws.terminal.host.lifecycle;

/** Owns activity lifecycle wiring for native/status/session/surface hooks. */
public final class LifecycleController {
    /** Activity callbacks required for lifecycle wiring. */
    public interface Host {
        boolean nativeLoaded();

        long nativeOnStart();

        long nativeOnResume();

        long nativeOnPause();

        long nativeOnStop();

        long nativeOnWindowFocus(boolean hasFocus);

        void appendEvent(String event);

        void callNative(String event, long seq);

        void updateStatus(String statusLabel);

        void stopProductFrameLoop();

        void refreshUserlandSessionOnPause();

        void notifySurfacePause();

        void notifySurfaceResume(boolean debugRecreateSurfaceOnce, boolean debugResizeSurfaceOnce, boolean debugStartShellOnce);
    }

    private final Host host;

    public LifecycleController(Host host) {
        this.host = host;
    }

    public void onStart() {
        host.appendEvent("activity.on.start");
        host.callNative("native.onStart", host.nativeLoaded() ? host.nativeOnStart() : -1);
        host.updateStatus("activity.started");
    }

    public void onResume(
            boolean debugRecreateSurfaceOnce,
            boolean debugResizeSurfaceOnce,
            boolean debugStartShellOnce) {
        host.appendEvent("activity.on.resume");
        host.callNative("native.onResume", host.nativeLoaded() ? host.nativeOnResume() : -1);
        host.notifySurfaceResume(
                debugRecreateSurfaceOnce,
                debugResizeSurfaceOnce,
                debugStartShellOnce);
    }

    public void onPause() {
        host.appendEvent("activity.on.pause");
        host.callNative("native.onPause", host.nativeLoaded() ? host.nativeOnPause() : -1);
        host.stopProductFrameLoop();
        host.refreshUserlandSessionOnPause();
        host.notifySurfacePause();
        host.updateStatus("activity.paused");
    }

    public void onStop() {
        host.appendEvent("activity.on.stop");
        host.callNative("native.onStop", host.nativeLoaded() ? host.nativeOnStop() : -1);
        host.updateStatus("activity.stopped");
    }

    public void onWindowFocusChanged(boolean hasFocus) {
        host.appendEvent("activity.on.window_focus_changed focus=" + hasFocus);
        host.callNative("native.onWindowFocus", host.nativeLoaded() ? host.nativeOnWindowFocus(hasFocus) : -1);
        host.updateStatus(hasFocus ? "window-focused" : "window-unfocused");
    }
}
