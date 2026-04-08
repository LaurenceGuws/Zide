package dev.zide.androidbootstrap;

import android.app.Activity;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.Log;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.widget.TextView;

public final class ZideBootstrapActivity extends Activity implements SurfaceHolder.Callback2 {
    private static final String TAG = "ZideAndroidBootstrap";
    private static final int MAX_LOG_CHARS = 12000;

    private static boolean nativeLoaded = false;
    private static String nativeLoadError = null;

    static {
        try {
            System.loadLibrary("zide_android_bridge");
            nativeLoaded = true;
        } catch (UnsatisfiedLinkError err) {
            nativeLoadError = err.toString();
            Log.e(TAG, "failed to load native bridge", err);
        }
    }

    private final StringBuilder eventLog = new StringBuilder();
    private TextView statusText;
    private TextView eventLogText;
    private SurfaceView surfaceView;

    private static native long nativeOnCreateBridge();
    private static native long nativeOnStartBridge();
    private static native long nativeOnResumeBridge();
    private static native long nativeOnPauseBridge();
    private static native long nativeOnStopBridge();
    private static native long nativeOnWindowFocusBridge(boolean focused);
    private static native long nativeOnSurfaceAvailableBridge(Surface surface, int width, int height);
    private static native long nativeOnSurfaceDestroyedBridge();
    private static native long nativeCurrentWindowTokenBridge();
    private static native long nativeCurrentSurfaceEpochBridge();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        statusText = findViewById(R.id.status_text);
        eventLogText = findViewById(R.id.event_log);
        surfaceView = findViewById(R.id.host_surface);
        surfaceView.getHolder().addCallback(this);

        appendEvent("activity.onCreate nativeLoaded=" + nativeLoaded);
        if (nativeLoadError != null) {
            appendEvent("native.load.error=" + nativeLoadError);
        }
        callNative("native.onCreate", nativeLoaded ? nativeOnCreateBridge() : -1);
        updateStatus("created");
    }

    @Override
    protected void onStart() {
        super.onStart();
        appendEvent("activity.onStart");
        callNative("native.onStart", nativeLoaded ? nativeOnStartBridge() : -1);
        updateStatus("started");
    }

    @Override
    protected void onResume() {
        super.onResume();
        appendEvent("activity.onResume");
        callNative("native.onResume", nativeLoaded ? nativeOnResumeBridge() : -1);
        updateStatus("resumed");
    }

    @Override
    protected void onPause() {
        appendEvent("activity.onPause");
        callNative("native.onPause", nativeLoaded ? nativeOnPauseBridge() : -1);
        updateStatus("paused");
        super.onPause();
    }

    @Override
    protected void onStop() {
        appendEvent("activity.onStop");
        callNative("native.onStop", nativeLoaded ? nativeOnStopBridge() : -1);
        updateStatus("stopped");
        super.onStop();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        appendEvent("activity.onWindowFocusChanged focus=" + hasFocus);
        callNative("native.onWindowFocus", nativeLoaded ? nativeOnWindowFocusBridge(hasFocus) : -1);
        updateStatus(hasFocus ? "window-focused" : "window-unfocused");
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        appendEvent("surface.created valid=" + holder.getSurface().isValid());
        updateStatus("surface-created");
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        appendEvent("surface.changed format=" + format + " size=" + width + "x" + height);
        final long seq = nativeLoaded ? nativeOnSurfaceAvailableBridge(holder.getSurface(), width, height) : -1;
        final long token = nativeLoaded ? nativeCurrentWindowTokenBridge() : 0;
        final long epoch = nativeLoaded ? nativeCurrentSurfaceEpochBridge() : 0;
        callNativeWithSurfaceState("native.surfaceAvailable", seq, token, epoch);
        updateStatus("surface-changed");
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        appendEvent("surface.destroyed");
        final long seq = nativeLoaded ? nativeOnSurfaceDestroyedBridge() : -1;
        final long token = nativeLoaded ? nativeCurrentWindowTokenBridge() : 0;
        final long epoch = nativeLoaded ? nativeCurrentSurfaceEpochBridge() : 0;
        callNativeWithSurfaceState("native.surfaceDestroyed", seq, token, epoch);
        updateStatus("surface-destroyed");
    }

    @Override
    public void surfaceRedrawNeeded(SurfaceHolder holder) {
        appendEvent("surface.redrawNeeded valid=" + holder.getSurface().isValid());
        updateStatus("surface-redraw-needed");
    }

    private void callNative(String event, long seq) {
        appendEvent(event + " seq=" + seq);
    }

    private void callNativeWithSurfaceState(String event, long seq, long token, long epoch) {
        appendEvent(
            event + " seq=" + seq +
                " token=0x" + Long.toHexString(token) +
                " epoch=" + epoch
        );
    }

    private void updateStatus(String state) {
        final int surfaceWidth = surfaceView.getWidth();
        final int surfaceHeight = surfaceView.getHeight();
        final boolean surfaceValid = surfaceView.getHolder().getSurface().isValid();
        statusText.setText(
            "state=" + state +
                " nativeLoaded=" + nativeLoaded +
                " windowFocus=" + hasWindowFocus() +
                " surfaceValid=" + surfaceValid +
                " surfaceSize=" + surfaceWidth + "x" + surfaceHeight
        );
    }

    private void appendEvent(String message) {
        final String line = String.format("[%08d] %s", SystemClock.uptimeMillis(), message);
        Log.i(TAG, line);
        if (eventLog.length() > 0) {
            eventLog.append('\n');
        }
        eventLog.append(line);
        if (eventLog.length() > MAX_LOG_CHARS) {
            eventLog.delete(0, eventLog.length() - MAX_LOG_CHARS);
        }
        eventLogText.setText(eventLog.toString());
    }
}
