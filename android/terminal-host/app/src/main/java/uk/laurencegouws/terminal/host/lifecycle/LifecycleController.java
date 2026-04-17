package uk.laurencegouws.terminal.host.lifecycle;

/** Owns activity lifecycle wiring for native/status/session/surface hooks. */
public final class LifecycleController {
    /** Harness callbacks required for lifecycle wiring. */
    public interface Host {
        boolean nativeLoaded();

        String nativeLoadError();

        long nativeOnCreate();

        long nativeOnStart();

        long nativeOnResume();

        long nativeOnPause();

        long nativeOnStop();

        long nativeOnWindowFocus(boolean hasFocus);

        void appendEvent(String event);

        void callNative(String event, long seq);

        void updateStatus(String statusLabel);

        void stopFrameLoop();

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
        host.updateStatus("activity.state.started");
    }

    public void onNewIntent() {
        host.appendEvent("activity.on.new.intent");
    }

    public void onCreate() {
        host.appendEvent("activity.on.create nativeLoaded=" + host.nativeLoaded());
        final String nativeLoadError = host.nativeLoadError();
        if (nativeLoadError != null) {
            host.appendEvent("native.load.error detail=" + nativeLoadError);
        }
        host.callNative("native.onCreate", host.nativeLoaded() ? host.nativeOnCreate() : -1);
        host.updateStatus("activity.state.created");
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
        host.stopFrameLoop();
        host.refreshUserlandSessionOnPause();
        host.notifySurfacePause();
        host.updateStatus("activity.state.paused");
    }

    public void onStop() {
        host.appendEvent("activity.on.stop");
        host.callNative("native.onStop", host.nativeLoaded() ? host.nativeOnStop() : -1);
        host.updateStatus("activity.state.stopped");
    }

    public void onWindowFocusChanged(boolean hasFocus) {
        host.appendEvent("activity.on.window.focus.changed focus=" + hasFocus);
        host.callNative("native.onWindowFocus", host.nativeLoaded() ? host.nativeOnWindowFocus(hasFocus) : -1);
        host.updateStatus(hasFocus ? "window.focused.state" : "window.unfocused.state");
    }
}
