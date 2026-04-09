package dev.zide.androidbootstrap;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.SystemClock;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;

public final class ZideBootstrapActivity extends Activity implements SurfaceHolder.Callback2 {
    private static final String TAG = "ZideAndroidBootstrap";
    private static final int MAX_LOG_CHARS = 12000;
    private static final String EXTRA_DEBUG_RECREATE_SURFACE_ONCE = "debug_recreate_surface_once";
    private static final String EXTRA_DEBUG_RESIZE_SURFACE_ONCE = "debug_resize_surface_once";
    private static final String EXTRA_DEBUG_START_PTY_PROBE_ONCE = "debug_start_pty_probe_once";
    private static final String EXTRA_DEBUG_START_SERVICE_PTY_PROBE_ONCE = "debug_start_service_pty_probe_once";
    private static final String EXTRA_DEBUG_STOP_SERVICE_PTY_PROBE_ONCE = "debug_stop_service_pty_probe_once";
    private static final String PTY_PROBE_LOG_PATH = "/data/data/dev.zide.androidbootstrap/files/pty_probe.log";
    private static final long PTY_STATUS_REFRESH_MS = 1000L;

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
    private final Handler handler = new Handler(Looper.getMainLooper());
    private TextView progressSummaryText;
    private TextView statusText;
    private TextView eventLogText;
    private View productView;
    private View debugView;
    private FrameLayout productSurfaceContainer;
    private EditText imeProbeInput;
    private Button imeToggleButton;
    private SurfaceView surfaceView;
    private boolean debugViewEnabled = false;
    private boolean imeVisible = false;
    private boolean surfaceRecreationScheduled = false;
    private boolean surfaceResizeScheduled = false;
    private boolean ptyProbeScheduled = false;
    private boolean servicePtyProbeScheduled = false;
    private boolean servicePtyProbeStopScheduled = false;
    private boolean ptyStatusRefreshActive = false;
    private int surfaceHostGeneration = 0;
    private final Runnable ptyStatusRefreshRunnable = new Runnable() {
        @Override
        public void run() {
            refreshPtyProbeStatus(false);
            if (ptyStatusRefreshActive) {
                handler.postDelayed(this, PTY_STATUS_REFRESH_MS);
            }
        }
    };

    private static native long nativeOnCreateBridge();
    private static native long nativeOnStartBridge();
    private static native long nativeOnResumeBridge();
    private static native long nativeOnPauseBridge();
    private static native long nativeOnStopBridge();
    private static native long nativeOnWindowFocusBridge(boolean focused);
    private static native long nativeOnSurfaceAvailableBridge(Surface surface, int width, int height);
    private static native long nativeOnSurfaceDestroyedBridge();
    private static native long nativeOnSurfaceRedrawNeededBridge();
    private static native long nativeCurrentWindowTokenBridge();
    private static native long nativeCurrentSurfaceEpochBridge();
    private static native int nativeCurrentSurfaceTransitionBridge();
    private static native int nativeCurrentGlesProbeStatusBridge();
    private static native long nativeCurrentGlesProbeSwapCountBridge();
    private static native long nativeCurrentGlesProbeBoundEpochBridge();
    private static native long nativeCurrentGlesProbeContextCreateCountBridge();
    private static native long nativeCurrentGlesProbeSurfaceCreateCountBridge();
    private static native long nativeCurrentGlesProbeTextureCreateCountBridge();
    private static native boolean nativeCurrentGlesProbeTextureAliveBridge();
    private static native long nativeCurrentGlesProbeTextureUploadCountBridge();
    private static native long nativeCurrentGlesProbeTextureUpdateCountBridge();
    private static native long nativeCurrentGlesProbeTextureResizeCountBridge();
    private static native int nativeCurrentGlesProbeTextureWidthBridge();
    private static native int nativeCurrentGlesProbeTextureHeightBridge();
    private static native long nativeStartPtyProbeBridge();
    private static native void nativeStopPtyProbeBridge();
    private static native boolean nativeIsPtyProbeAliveBridge();
    private static native long nativePtyProbeChildPidBridge();
    private static native int nativePtyProbeStartStatusBridge();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        progressSummaryText = findViewById(R.id.progress_summary_text);
        statusText = findViewById(R.id.status_text);
        eventLogText = findViewById(R.id.event_log);
        productView = findViewById(R.id.product_view);
        debugView = findViewById(R.id.debug_view);
        productSurfaceContainer = findViewById(R.id.product_surface_container);
        imeProbeInput = findViewById(R.id.ime_probe_input);
        imeToggleButton = findViewById(R.id.ime_toggle_button);
        bindViewModeToggle();
        bindImeToggle();
        applyViewMode();
        installSurfaceView("activity-create");

        appendEvent("activity.onCreate nativeLoaded=" + nativeLoaded);
        if (nativeLoadError != null) {
            appendEvent("native.load.error=" + nativeLoadError);
        }
        callNative("native.onCreate", nativeLoaded ? nativeOnCreateBridge() : -1);
        refreshPtyProbeStatus(false);
        updateStatus("created");
    }

    @Override
    protected void onStart() {
        super.onStart();
        appendEvent("activity.onStart");
        callNative("native.onStart", nativeLoaded ? nativeOnStartBridge() : -1);
        logPtyProbeSnapshot("activity.onStart.pty");
        updateStatus("started");
    }

    @Override
    protected void onResume() {
        super.onResume();
        appendEvent("activity.onResume");
        callNative("native.onResume", nativeLoaded ? nativeOnResumeBridge() : -1);
        maybeScheduleSurfaceRecreation();
        maybeScheduleSurfaceResize();
        maybeSchedulePtyProbe();
        maybeScheduleServicePtyProbe();
        maybeScheduleServicePtyProbeStop();
        startPtyStatusRefresh();
        logPtyProbeSnapshot("activity.onResume.pty");
        updateStatus("resumed");
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        appendEvent("activity.onNewIntent");
    }

    @Override
    protected void onPause() {
        appendEvent("activity.onPause");
        if (nativeLoaded && nativeIsPtyProbeAliveBridge()) {
            appendEvent("debug.ptyProbeAliveOnPause pid=" + nativePtyProbeChildPidBridge());
        }
        callNative("native.onPause", nativeLoaded ? nativeOnPauseBridge() : -1);
        stopPtyStatusRefresh();
        refreshPtyProbeStatus(false);
        logPtyProbeSnapshot("activity.onPause.pty");
        updateStatus("paused");
        super.onPause();
    }

    @Override
    protected void onStop() {
        appendEvent("activity.onStop");
        callNative("native.onStop", nativeLoaded ? nativeOnStopBridge() : -1);
        logPtyProbeSnapshot("activity.onStop.pty");
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
        appendEvent("surface.created generation=" + surfaceHostGeneration + " valid=" + holder.getSurface().isValid());
        updateStatus("surface-created");
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        appendEvent(
            "surface.changed generation=" + surfaceHostGeneration +
                " format=" + format +
                " size=" + width + "x" + height
        );
        final long seq = nativeLoaded ? nativeOnSurfaceAvailableBridge(holder.getSurface(), width, height) : -1;
        final long token = nativeLoaded ? nativeCurrentWindowTokenBridge() : 0;
        final long epoch = nativeLoaded ? nativeCurrentSurfaceEpochBridge() : 0;
        final int transition = nativeLoaded ? nativeCurrentSurfaceTransitionBridge() : 0;
        final int glesStatus = nativeLoaded ? nativeCurrentGlesProbeStatusBridge() : 0;
        final long glesSwapCount = nativeLoaded ? nativeCurrentGlesProbeSwapCountBridge() : 0;
        final long glesBoundEpoch = nativeLoaded ? nativeCurrentGlesProbeBoundEpochBridge() : 0;
        final long glesContextCreateCount = nativeLoaded ? nativeCurrentGlesProbeContextCreateCountBridge() : 0;
        final long glesSurfaceCreateCount = nativeLoaded ? nativeCurrentGlesProbeSurfaceCreateCountBridge() : 0;
        final long glesTextureCreateCount = nativeLoaded ? nativeCurrentGlesProbeTextureCreateCountBridge() : 0;
        final boolean glesTextureAlive = nativeLoaded && nativeCurrentGlesProbeTextureAliveBridge();
        final long glesTextureUploadCount = nativeLoaded ? nativeCurrentGlesProbeTextureUploadCountBridge() : 0;
        final long glesTextureUpdateCount = nativeLoaded ? nativeCurrentGlesProbeTextureUpdateCountBridge() : 0;
        final long glesTextureResizeCount = nativeLoaded ? nativeCurrentGlesProbeTextureResizeCountBridge() : 0;
        final int glesTextureWidth = nativeLoaded ? nativeCurrentGlesProbeTextureWidthBridge() : 0;
        final int glesTextureHeight = nativeLoaded ? nativeCurrentGlesProbeTextureHeightBridge() : 0;
        callNativeWithSurfaceState(
            "native.surfaceAvailable",
            seq,
            token,
            epoch,
            transition,
            glesStatus,
            glesSwapCount,
            glesBoundEpoch,
            glesContextCreateCount,
            glesSurfaceCreateCount,
            glesTextureCreateCount,
            glesTextureAlive,
            glesTextureUploadCount,
            glesTextureUpdateCount,
            glesTextureResizeCount,
            glesTextureWidth,
            glesTextureHeight
        );
        updateStatus("surface-changed");
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        appendEvent("surface.destroyed generation=" + surfaceHostGeneration);
        final long seq = nativeLoaded ? nativeOnSurfaceDestroyedBridge() : -1;
        final long token = nativeLoaded ? nativeCurrentWindowTokenBridge() : 0;
        final long epoch = nativeLoaded ? nativeCurrentSurfaceEpochBridge() : 0;
        final int transition = nativeLoaded ? nativeCurrentSurfaceTransitionBridge() : 0;
        final int glesStatus = nativeLoaded ? nativeCurrentGlesProbeStatusBridge() : 0;
        final long glesSwapCount = nativeLoaded ? nativeCurrentGlesProbeSwapCountBridge() : 0;
        final long glesBoundEpoch = nativeLoaded ? nativeCurrentGlesProbeBoundEpochBridge() : 0;
        final long glesContextCreateCount = nativeLoaded ? nativeCurrentGlesProbeContextCreateCountBridge() : 0;
        final long glesSurfaceCreateCount = nativeLoaded ? nativeCurrentGlesProbeSurfaceCreateCountBridge() : 0;
        final long glesTextureCreateCount = nativeLoaded ? nativeCurrentGlesProbeTextureCreateCountBridge() : 0;
        final boolean glesTextureAlive = nativeLoaded && nativeCurrentGlesProbeTextureAliveBridge();
        final long glesTextureUploadCount = nativeLoaded ? nativeCurrentGlesProbeTextureUploadCountBridge() : 0;
        final long glesTextureUpdateCount = nativeLoaded ? nativeCurrentGlesProbeTextureUpdateCountBridge() : 0;
        final long glesTextureResizeCount = nativeLoaded ? nativeCurrentGlesProbeTextureResizeCountBridge() : 0;
        final int glesTextureWidth = nativeLoaded ? nativeCurrentGlesProbeTextureWidthBridge() : 0;
        final int glesTextureHeight = nativeLoaded ? nativeCurrentGlesProbeTextureHeightBridge() : 0;
        callNativeWithSurfaceState(
            "native.surfaceDestroyed",
            seq,
            token,
            epoch,
            transition,
            glesStatus,
            glesSwapCount,
            glesBoundEpoch,
            glesContextCreateCount,
            glesSurfaceCreateCount,
            glesTextureCreateCount,
            glesTextureAlive,
            glesTextureUploadCount,
            glesTextureUpdateCount,
            glesTextureResizeCount,
            glesTextureWidth,
            glesTextureHeight
        );
        updateStatus("surface-destroyed");
    }

    @Override
    public void surfaceRedrawNeeded(SurfaceHolder holder) {
        appendEvent("surface.redrawNeeded generation=" + surfaceHostGeneration + " valid=" + holder.getSurface().isValid());
        final long seq = nativeLoaded ? nativeOnSurfaceRedrawNeededBridge() : -1;
        final int glesStatus = nativeLoaded ? nativeCurrentGlesProbeStatusBridge() : 0;
        final long glesSwapCount = nativeLoaded ? nativeCurrentGlesProbeSwapCountBridge() : 0;
        final long glesBoundEpoch = nativeLoaded ? nativeCurrentGlesProbeBoundEpochBridge() : 0;
        final long glesContextCreateCount = nativeLoaded ? nativeCurrentGlesProbeContextCreateCountBridge() : 0;
        final long glesSurfaceCreateCount = nativeLoaded ? nativeCurrentGlesProbeSurfaceCreateCountBridge() : 0;
        final long glesTextureCreateCount = nativeLoaded ? nativeCurrentGlesProbeTextureCreateCountBridge() : 0;
        final boolean glesTextureAlive = nativeLoaded && nativeCurrentGlesProbeTextureAliveBridge();
        final long glesTextureUploadCount = nativeLoaded ? nativeCurrentGlesProbeTextureUploadCountBridge() : 0;
        final long glesTextureUpdateCount = nativeLoaded ? nativeCurrentGlesProbeTextureUpdateCountBridge() : 0;
        final long glesTextureResizeCount = nativeLoaded ? nativeCurrentGlesProbeTextureResizeCountBridge() : 0;
        final int glesTextureWidth = nativeLoaded ? nativeCurrentGlesProbeTextureWidthBridge() : 0;
        final int glesTextureHeight = nativeLoaded ? nativeCurrentGlesProbeTextureHeightBridge() : 0;
        appendEvent(
            "native.surfaceRedrawNeeded seq=" + seq +
                " gles=" + glesProbeStatusLabel(glesStatus) +
                " glesSwaps=" + glesSwapCount +
                " glesBoundEpoch=" + glesBoundEpoch +
                " glesContextCreates=" + glesContextCreateCount +
                " glesSurfaceCreates=" + glesSurfaceCreateCount +
                " glesTextureCreates=" + glesTextureCreateCount +
                " glesTextureAlive=" + glesTextureAlive +
                " glesTextureUploads=" + glesTextureUploadCount +
                " glesTextureUpdates=" + glesTextureUpdateCount +
                " glesTextureResizes=" + glesTextureResizeCount +
                " glesTextureSize=" + glesTextureWidth + "x" + glesTextureHeight
        );
        updateStatus("surface-redraw-needed");
    }

    private void maybeScheduleSurfaceRecreation() {
        if (!getIntent().getBooleanExtra(EXTRA_DEBUG_RECREATE_SURFACE_ONCE, false)) {
            return;
        }
        if (surfaceRecreationScheduled) {
            return;
        }
        surfaceRecreationScheduled = true;
        productSurfaceContainer.postDelayed(() -> {
            appendEvent("debug.recreateSurfaceView");
            installSurfaceView("debug-recreate");
            updateStatus("debug-recreated-surface");
        }, 700);
    }

    private void maybeScheduleSurfaceResize() {
        final boolean resizeRequested = getIntent().getBooleanExtra(EXTRA_DEBUG_RESIZE_SURFACE_ONCE, false);
        appendEvent("debug.resizeSurface requested=" + resizeRequested + " scheduled=" + surfaceResizeScheduled);
        if (!resizeRequested) {
            return;
        }
        if (surfaceResizeScheduled) {
            return;
        }
        surfaceResizeScheduled = true;
        handler.postDelayed(() -> {
            final SurfaceHolder holder = surfaceView.getHolder();
            final int originalWidth = Math.max(2, surfaceView.getWidth());
            final int originalHeight = Math.max(2, surfaceView.getHeight());
            final int shrunkHeight = Math.max(200, originalHeight / 2);
            holder.setFixedSize(originalWidth, shrunkHeight);
            appendEvent(
                "debug.resizeSurface fixedSize=" + originalWidth + "x" + shrunkHeight +
                    " original=" + originalWidth + "x" + originalHeight +
                    " target=surfaceHolder"
            );
            updateStatus("debug-resized-surface-shrink");

            handler.postDelayed(() -> {
                holder.setFixedSize(originalWidth, originalHeight);
                appendEvent(
                    "debug.resizeSurface restoreSize=" + originalWidth + "x" + originalHeight +
                        " target=surfaceHolder"
                );
                updateStatus("debug-resized-surface-restore");
            }, 900);
        }, 900);
    }

    private void maybeSchedulePtyProbe() {
        if (!getIntent().getBooleanExtra(EXTRA_DEBUG_START_PTY_PROBE_ONCE, false)) {
            return;
        }
        if (ptyProbeScheduled) {
            return;
        }
        ptyProbeScheduled = true;
        productSurfaceContainer.postDelayed(() -> {
            startPtyProbe("debug.ptyProbeStart", "debug-pty-probe-started");
        }, 900);
    }

    private void maybeScheduleServicePtyProbe() {
        if (!getIntent().getBooleanExtra(EXTRA_DEBUG_START_SERVICE_PTY_PROBE_ONCE, false)) {
            return;
        }
        if (servicePtyProbeScheduled) {
            return;
        }
        servicePtyProbeScheduled = true;
        productSurfaceContainer.postDelayed(() -> {
            final Intent intent = new Intent(this, ZidePtyProbeService.class)
                .setAction(ZidePtyProbeService.ACTION_START_FOREGROUND_PTY_PROBE);
            startForegroundService(intent);
            appendEvent("debug.servicePtyProbeStartIssued");
            updateStatus("debug-service-pty-probe-started");
        }, 1100);
    }

    private void maybeScheduleServicePtyProbeStop() {
        if (!getIntent().getBooleanExtra(EXTRA_DEBUG_STOP_SERVICE_PTY_PROBE_ONCE, false)) {
            return;
        }
        if (servicePtyProbeStopScheduled) {
            return;
        }
        servicePtyProbeStopScheduled = true;
        productSurfaceContainer.postDelayed(() -> {
            final Intent intent = new Intent(this, ZidePtyProbeService.class)
                .setAction(ZidePtyProbeService.ACTION_STOP_FOREGROUND_PTY_PROBE);
            startService(intent);
            appendEvent("debug.servicePtyProbeStopIssued");
            updateStatus("debug-service-pty-probe-stopped");
        }, 1100);
    }

    private void bindImeToggle() {
        imeToggleButton.setOnClickListener(view -> toggleIme());
    }

    private void bindViewModeToggle() {
        final Button productViewModeButton = findViewById(R.id.view_mode_button);
        final Button debugViewModeButton = findViewById(R.id.debug_view_mode_button);
        final View.OnClickListener toggleListener = view -> {
            debugViewEnabled = !debugViewEnabled;
            appendEvent("view.mode debug=" + debugViewEnabled);
            applyViewMode();
            updateStatus(debugViewEnabled ? "debug-view" : "product-view");
        };
        productViewModeButton.setOnClickListener(toggleListener);
        debugViewModeButton.setOnClickListener(toggleListener);
    }

    private void applyViewMode() {
        productView.setVisibility(debugViewEnabled ? View.GONE : View.VISIBLE);
        debugView.setVisibility(debugViewEnabled ? View.VISIBLE : View.GONE);
    }

    private void toggleIme() {
        final InputMethodManager imm = getSystemService(InputMethodManager.class);
        if (imm == null) {
            appendEvent("manual.imeToggle unavailable=true");
            return;
        }

        if (imeVisible) {
            imm.hideSoftInputFromWindow(imeProbeInput.getWindowToken(), 0);
            imeProbeInput.clearFocus();
            imeVisible = false;
            appendEvent("manual.imeToggle visible=false");
            updateImeToggleLabel();
            updateStatus("ime-hidden");
            return;
        }

        imeProbeInput.requestFocus();
        imeProbeInput.setSelection(imeProbeInput.getText().length());
        final boolean shown = imm.showSoftInput(imeProbeInput, InputMethodManager.SHOW_IMPLICIT);
        imeVisible = shown || imeProbeInput.hasFocus();
        appendEvent("manual.imeToggle visible=true shown=" + shown);
        updateImeToggleLabel();
        updateStatus("ime-shown");
    }

    private void updateImeToggleLabel() {
        imeToggleButton.setText(imeVisible ? R.string.hide_ime : R.string.show_ime);
    }

    private void startPtyProbe(String eventPrefix, String stateLabel) {
        final long pid = nativeLoaded ? nativeStartPtyProbeBridge() : -1;
        final boolean alive = nativeLoaded && nativeIsPtyProbeAliveBridge();
        final int status = nativeLoaded ? nativePtyProbeStartStatusBridge() : 0;
        appendEvent(
            eventPrefix + " pid=" + pid +
                " alive=" + alive +
                " status=" + ptyProbeStartStatusLabel(status) +
                " log=" + PTY_PROBE_LOG_PATH
        );
        refreshPtyProbeStatus(false);
        updateStatus(stateLabel);
    }

    private void startPtyStatusRefresh() {
        if (ptyStatusRefreshActive) {
            return;
        }
        ptyStatusRefreshActive = true;
        handler.post(ptyStatusRefreshRunnable);
    }

    private void stopPtyStatusRefresh() {
        if (!ptyStatusRefreshActive) {
            return;
        }
        ptyStatusRefreshActive = false;
        handler.removeCallbacks(ptyStatusRefreshRunnable);
    }

    private void refreshPtyProbeStatus(boolean logEvent) {
        final boolean alive = nativeLoaded && nativeIsPtyProbeAliveBridge();
        final long pid = nativeLoaded ? nativePtyProbeChildPidBridge() : -1;
        final int status = nativeLoaded ? nativePtyProbeStartStatusBridge() : 0;
        final PtyProbeSnapshot snapshot = readPtyProbeSnapshot();
        if (logEvent) {
            appendEvent(
                "manual.ptyProbeRefresh alive=" + alive +
                    " pid=" + pid +
                    " status=" + ptyProbeStartStatusLabel(status) +
                    " beats=" + snapshot.heartbeatCount
            );
        }
    }

    private void logPtyProbeSnapshot(String prefix) {
        final boolean alive = nativeLoaded && nativeIsPtyProbeAliveBridge();
        final long pid = nativeLoaded ? nativePtyProbeChildPidBridge() : -1;
        final int status = nativeLoaded ? nativePtyProbeStartStatusBridge() : 0;
        final PtyProbeSnapshot snapshot = readPtyProbeSnapshot();
        appendEvent(
            prefix +
                " alive=" + alive +
                " pid=" + pid +
                " status=" + ptyProbeStartStatusLabel(status) +
                " beats=" + snapshot.heartbeatCount +
                " last=" + snapshot.lastLine
        );
    }

    private static PtyProbeSnapshot readPtyProbeSnapshot() {
        final File logFile = new File(PTY_PROBE_LOG_PATH);
        if (!logFile.exists()) {
            return new PtyProbeSnapshot(0L, "missing", 0L);
        }

        long heartbeatCount = 0L;
        String lastLine = "empty";
        try (BufferedReader reader = new BufferedReader(new FileReader(logFile))) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (!line.isEmpty()) {
                    lastLine = line;
                }
            }
            heartbeatCount = parseHeartbeatCount(lastLine);
        } catch (IOException err) {
            lastLine = "read-error:" + err.getClass().getSimpleName();
        }
        return new PtyProbeSnapshot(heartbeatCount, lastLine, logFile.length());
    }

    private static long parseHeartbeatCount(String line) {
        final String prefix = "heartbeat:";
        if (!line.startsWith(prefix)) {
            return 0L;
        }
        final int secondColon = line.indexOf(':', prefix.length());
        if (secondColon <= prefix.length()) {
            return 0L;
        }
        try {
            return Long.parseLong(line.substring(prefix.length(), secondColon));
        } catch (NumberFormatException err) {
            return 0L;
        }
    }

    private void installSurfaceView(String reason) {
        if (surfaceView != null) {
            surfaceView.getHolder().removeCallback(this);
            productSurfaceContainer.removeView(surfaceView);
            appendEvent("surface.hostRemoved reason=" + reason + " generation=" + surfaceHostGeneration);
        }

        surfaceHostGeneration += 1;
        final SurfaceView nextSurfaceView = new SurfaceView(this);
        nextSurfaceView.setBackgroundColor(0xff162028);
        final FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
            Gravity.CENTER
        );
        productSurfaceContainer.addView(nextSurfaceView, params);
        nextSurfaceView.getHolder().addCallback(this);
        surfaceView = nextSurfaceView;
        appendEvent("surface.hostInstalled reason=" + reason + " generation=" + surfaceHostGeneration);
    }

    private void callNative(String event, long seq) {
        appendEvent(event + " seq=" + seq);
    }

    private void callNativeWithSurfaceState(
        String event,
        long seq,
        long token,
        long epoch,
        int transition,
        int glesStatus,
        long glesSwapCount,
        long glesBoundEpoch,
        long glesContextCreateCount,
        long glesSurfaceCreateCount,
        long glesTextureCreateCount,
        boolean glesTextureAlive,
        long glesTextureUploadCount,
        long glesTextureUpdateCount,
        long glesTextureResizeCount,
        int glesTextureWidth,
        int glesTextureHeight
    ) {
        appendEvent(
            event + " seq=" + seq +
                " token=0x" + Long.toHexString(token) +
                " epoch=" + epoch +
                " transition=" + surfaceTransitionLabel(transition) +
                " gles=" + glesProbeStatusLabel(glesStatus) +
                " glesSwaps=" + glesSwapCount +
                " glesBoundEpoch=" + glesBoundEpoch +
                " glesContextCreates=" + glesContextCreateCount +
                " glesSurfaceCreates=" + glesSurfaceCreateCount +
                " glesTextureCreates=" + glesTextureCreateCount +
                " glesTextureAlive=" + glesTextureAlive +
                " glesTextureUploads=" + glesTextureUploadCount +
                " glesTextureUpdates=" + glesTextureUpdateCount +
                " glesTextureResizes=" + glesTextureResizeCount +
                " glesTextureSize=" + glesTextureWidth + "x" + glesTextureHeight
        );
    }

    private static String surfaceTransitionLabel(int transition) {
        return switch (transition) {
            case 1 -> "acquired";
            case 2 -> "replaced";
            case 3 -> "retired";
            default -> "unchanged";
        };
    }

    private static String ptyProbeStartStatusLabel(int status) {
        return switch (status) {
            case 1 -> "started";
            case 2 -> "unsupported";
            case 3 -> "delete-log-failed";
            case 4 -> "init-failed";
            case 5 -> "write-failed";
            case 6 -> "missing-pid";
            default -> "none";
        };
    }

    private static String glesProbeStatusLabel(int status) {
        return switch (status) {
            case 1 -> "ready";
            case 2 -> "drawn";
            case 3 -> "surface-destroyed";
            case 4 -> "init-failed";
            case 5 -> "surface-failed";
            case 6 -> "make-current-failed";
            case 7 -> "swap-failed";
            default -> "unavailable";
        };
    }

    private static final class PtyProbeSnapshot {
        final long heartbeatCount;
        final String lastLine;
        final long fileSizeBytes;

        PtyProbeSnapshot(long heartbeatCount, String lastLine, long fileSizeBytes) {
            this.heartbeatCount = heartbeatCount;
            this.lastLine = lastLine;
            this.fileSizeBytes = fileSizeBytes;
        }
    }

    private void updateStatus(String state) {
        final int surfaceWidth = surfaceView.getWidth();
        final int surfaceHeight = surfaceView.getHeight();
        final boolean surfaceValid = surfaceView.getHolder().getSurface().isValid();
        final String glesStatus = nativeLoaded ? glesProbeStatusLabel(nativeCurrentGlesProbeStatusBridge()) : "unavailable";
        progressSummaryText.setText(
            "state=" + state +
                " surface=" + surfaceWidth + "x" + surfaceHeight +
                " valid=" + surfaceValid +
                " gles=" + glesStatus +
                " imeVisible=" + imeVisible
        );
        statusText.setText(
            "state=" + state +
                " nativeLoaded=" + nativeLoaded +
                " windowFocus=" + hasWindowFocus() +
                " imeVisible=" + imeVisible +
                "\n" +
                "surfaceValid=" + surfaceValid +
                " surfaceSize=" + surfaceWidth + "x" + surfaceHeight +
                "\n" +
                "gles=" + glesStatus +
                " swaps=" + (nativeLoaded ? nativeCurrentGlesProbeSwapCountBridge() : 0) +
                " boundEpoch=" + (nativeLoaded ? nativeCurrentGlesProbeBoundEpochBridge() : 0) +
                "\n" +
                "contextCreates=" + (nativeLoaded ? nativeCurrentGlesProbeContextCreateCountBridge() : 0) +
                " surfaceCreates=" + (nativeLoaded ? nativeCurrentGlesProbeSurfaceCreateCountBridge() : 0) +
                "\n" +
                "textureCreates=" + (nativeLoaded ? nativeCurrentGlesProbeTextureCreateCountBridge() : 0) +
                " textureAlive=" + (nativeLoaded && nativeCurrentGlesProbeTextureAliveBridge()) +
                "\n" +
                "textureUploads=" + (nativeLoaded ? nativeCurrentGlesProbeTextureUploadCountBridge() : 0) +
                " textureUpdates=" + (nativeLoaded ? nativeCurrentGlesProbeTextureUpdateCountBridge() : 0) +
                " textureResizes=" + (nativeLoaded ? nativeCurrentGlesProbeTextureResizeCountBridge() : 0) +
                "\n" +
                "textureSize=" + (nativeLoaded ? nativeCurrentGlesProbeTextureWidthBridge() : 0) +
                "x" + (nativeLoaded ? nativeCurrentGlesProbeTextureHeightBridge() : 0)
        );
        updateImeToggleLabel();
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
