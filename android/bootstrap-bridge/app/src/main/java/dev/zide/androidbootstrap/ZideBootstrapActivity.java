package dev.zide.androidbootstrap;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Insets;
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
import android.view.WindowInsets;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ScrollView;
import android.widget.TextView;

public final class ZideBootstrapActivity extends Activity implements SurfaceHolder.Callback2, ShellInputView.Host {
    private static final String TAG = "ZideAndroidBootstrap";
    private static final int MAX_LOG_CHARS = 12000;
    private static final String EXTRA_DEBUG_RECREATE_SURFACE_ONCE = "debug_recreate_surface_once";
    private static final String EXTRA_DEBUG_RESIZE_SURFACE_ONCE = "debug_resize_surface_once";
    private static final String EXTRA_DEBUG_START_SHELL_ONCE = "debug_start_shell_once";
    private static final String SHELL_TRANSCRIPT_PATH = "/data/data/dev.zide.androidbootstrap/files/bootstrap_shell.log";
    private static final long SHELL_REFRESH_MS = 150L;

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
    private TextView statusText;
    private TextView shellOutputText;
    private TextView eventLogText;
    private View productView;
    private View debugView;
    private FrameLayout productSurfaceContainer;
    private Button imeToggleButton;
    private ShellInputView shellInputView;
    private ScrollView shellOutputScroll;
    private ShellTranscriptController shellTranscriptController;
    private ShellSessionController shellSessionController;
    private SurfaceView surfaceView;
    private boolean debugViewEnabled = false;
    private boolean imeVisible = false;
    private boolean surfaceRecreationScheduled = false;
    private boolean surfaceResizeScheduled = false;
    private boolean shellStartScheduled = false;
    private boolean shellRefreshActive = false;
    private int surfaceHostGeneration = 0;
    private int productViewBasePaddingLeft = 0;
    private int productViewBasePaddingTop = 0;
    private int productViewBasePaddingRight = 0;
    private int productViewBasePaddingBottom = 0;
    private final Runnable shellRefreshRunnable = new Runnable() {
        @Override
        public void run() {
            refreshShellState(false);
            if (shellRefreshActive) {
                handler.postDelayed(this, SHELL_REFRESH_MS);
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        statusText = findViewById(R.id.status_text);
        shellOutputText = findViewById(R.id.shell_output_text);
        eventLogText = findViewById(R.id.event_log);
        productView = findViewById(R.id.product_view);
        debugView = findViewById(R.id.debug_view);
        productSurfaceContainer = findViewById(R.id.product_surface_container);
        imeToggleButton = findViewById(R.id.ime_toggle_button);
        shellOutputScroll = findViewById(R.id.shell_output_scroll);
        shellTranscriptController = new ShellTranscriptController(shellOutputScroll, shellOutputText);
        shellSessionController = new ShellSessionController(
                new ShellSessionController.Bridge() {
                    @Override
                    public int restart() {
                        return nativeRestartShellSessionBridge();
                    }

                    @Override
                    public int poll() {
                        return nativePollShellSessionBridge();
                    }

                    @Override
                    public boolean isAlive() {
                        return nativeIsShellSessionAliveBridge();
                    }
                },
                SHELL_TRANSCRIPT_PATH,
                nativeLoaded);
        installShellInputView();
        installInsetsHandling();
        shellTranscriptController.installScrollHandling();
        bindViewModeToggle();
        bindImeToggle();
        bindShellControls();
        applyViewMode();
        installSurfaceView("activity-create");

        appendEvent("activity.onCreate nativeLoaded=" + nativeLoaded);
        if (nativeLoadError != null) {
            appendEvent("native.load.error=" + nativeLoadError);
        }
        callNative("native.onCreate", nativeLoaded ? nativeOnCreateBridge() : -1);
        updateStatus("created");
    }

    private void installInsetsHandling() {
        productViewBasePaddingLeft = productView.getPaddingLeft();
        productViewBasePaddingTop = productView.getPaddingTop();
        productViewBasePaddingRight = productView.getPaddingRight();
        productViewBasePaddingBottom = productView.getPaddingBottom();
        productView.setOnApplyWindowInsetsListener((view, windowInsets) -> {
            final Insets navInsets = windowInsets.getInsets(WindowInsets.Type.navigationBars());
            final Insets imeInsets = windowInsets.getInsets(WindowInsets.Type.ime());
            final int bottomInset = Math.max(navInsets.bottom, imeInsets.bottom);
            imeVisible = imeInsets.bottom > navInsets.bottom;
            shellTranscriptController.setImeVisible(imeVisible);
            view.setPadding(
                    productViewBasePaddingLeft,
                    productViewBasePaddingTop,
                    productViewBasePaddingRight,
                    productViewBasePaddingBottom + bottomInset);
            updateImeToggleLabel();
            shellOutputScroll.post(() -> shellOutputScroll.fullScroll(View.FOCUS_DOWN));
            return windowInsets;
        });
        productView.requestApplyInsets();
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
        maybeScheduleSurfaceRecreation();
        maybeScheduleSurfaceResize();
        maybeScheduleShellStart();
        startShellRefresh();
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
        callNative("native.onPause", nativeLoaded ? nativeOnPauseBridge() : -1);
        stopShellRefresh();
        refreshShellState(false);
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
        appendEvent("surface.created generation=" + surfaceHostGeneration + " valid=" + holder.getSurface().isValid());
        updateStatus("surface-created");
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        appendEvent(
                "surface.changed generation=" + surfaceHostGeneration +
                        " format=" + format +
                        " size=" + width + "x" + height);
        final long seq = nativeLoaded ? nativeOnSurfaceAvailableBridge(holder.getSurface(), width, height) : -1;
        callNativeWithSurfaceState(
                "native.surfaceAvailable",
                seq,
                currentSurfaceStateSnapshot());
        updateStatus("surface-changed");
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        appendEvent("surface.destroyed generation=" + surfaceHostGeneration);
        final long seq = nativeLoaded ? nativeOnSurfaceDestroyedBridge() : -1;
        callNativeWithSurfaceState(
                "native.surfaceDestroyed",
                seq,
                currentSurfaceStateSnapshot());
        updateStatus("surface-destroyed");
    }

    @Override
    public void surfaceRedrawNeeded(SurfaceHolder holder) {
        appendEvent(
                "surface.redrawNeeded generation=" + surfaceHostGeneration + " valid=" + holder.getSurface().isValid());
        final long seq = nativeLoaded ? nativeOnSurfaceRedrawNeededBridge() : -1;
        final BootstrapDebugFormatter.SurfaceEventSnapshot state = currentSurfaceStateSnapshot();
        appendEvent(
                "native.surfaceRedrawNeeded seq=" + seq +
                        " gles=" + state.glesStatus +
                        " glesSwaps=" + state.glesSwapCount +
                        " glesBoundEpoch=" + state.glesBoundEpoch +
                        " glesContextCreates=" + state.glesContextCreateCount +
                        " glesSurfaceCreates=" + state.glesSurfaceCreateCount +
                        " glesTextureCreates=" + state.glesTextureCreateCount +
                        " glesTextureAlive=" + state.glesTextureAlive +
                        " glesTextureUploads=" + state.glesTextureUploadCount +
                        " glesTextureUpdates=" + state.glesTextureUpdateCount +
                        " glesTextureResizes=" + state.glesTextureResizeCount +
                        " glesTextureSize=" + state.glesTextureWidth + "x" + state.glesTextureHeight);
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
                            " target=surfaceHolder");
            updateStatus("debug-resized-surface-shrink");

            handler.postDelayed(() -> {
                holder.setFixedSize(originalWidth, originalHeight);
                appendEvent(
                        "debug.resizeSurface restoreSize=" + originalWidth + "x" + originalHeight +
                                " target=surfaceHolder");
                updateStatus("debug-resized-surface-restore");
            }, 900);
        }, 900);
    }

    private void maybeScheduleShellStart() {
        final boolean startRequested = getIntent().getBooleanExtra(EXTRA_DEBUG_START_SHELL_ONCE, false);
        appendEvent("debug.shellStart requested=" + startRequested + " scheduled=" + shellStartScheduled);
        if (!startRequested) {
            return;
        }
        if (shellStartScheduled) {
            return;
        }
        shellStartScheduled = true;
        handler.postDelayed(() -> {
            final int status = nativeLoaded ? nativeRestartShellSessionBridge() : 0;
            appendEvent("debug.shellStart status=" + shellStartStatusLabel(status));
            sendDirectText("printf 'android-shell-ok\\n'\n");
            refreshShellState(false);
            updateStatus("debug-shell-started");
        }, 900);
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

    private void bindShellControls() {
        final Button restartButton = findViewById(R.id.shell_restart_button);

        restartButton.setOnClickListener(view -> {
            final int status = nativeLoaded ? nativeRestartShellSessionBridge() : 0;
            appendEvent("manual.shellRestart status=" + shellStartStatusLabel(status));
            refreshShellState(false);
            updateStatus("shell-restarted");
        });
    }

    private void installShellInputView() {
        shellInputView = new ShellInputView(this, this);
        final FrameLayout root = (FrameLayout) productView.getParent();
        final FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(1, 1);
        lp.gravity = Gravity.BOTTOM | Gravity.START;
        root.addView(shellInputView, lp);

        shellOutputScroll.setOnClickListener(v -> toggleIme());
    }

    @Override
    public void sendDirectCodepoint(int codepoint) {
        if (!nativeLoaded)
            return;
        nativeSendShellCodepointBridge(codepoint);
    }

    @Override
    public void sendDirectText(String text) {
        if (!nativeLoaded)
            return;
        for (int i = 0; i < text.length();) {
            final int cp = text.codePointAt(i);
            nativeSendShellCodepointBridge(cp);
            i += Character.charCount(cp);
        }
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
            imm.hideSoftInputFromWindow(shellInputView.getWindowToken(), 0);
            shellInputView.clearFocus();
            imeVisible = false;
            appendEvent("manual.imeToggle visible=false");
            updateImeToggleLabel();
            updateStatus("ime-hidden");
            return;
        }

        shellInputView.post(() -> {
            shellInputView.requestFocus();
            imm.restartInput(shellInputView);
            final boolean shown = imm.showSoftInput(shellInputView, InputMethodManager.SHOW_FORCED);
            imeVisible = shown || shellInputView.hasFocus();
            shellTranscriptController.setImeVisible(imeVisible);
            appendEvent("manual.imeToggle visible=true shown=" + shown);
            updateImeToggleLabel();
            updateStatus("ime-shown");
        });
    }

    private void updateImeToggleLabel() {
        imeToggleButton.setText(imeVisible ? R.string.hide_ime : R.string.show_ime);
    }

    private void startShellRefresh() {
        if (shellRefreshActive) {
            return;
        }
        shellRefreshActive = true;
        handler.post(shellRefreshRunnable);
    }

    private void stopShellRefresh() {
        if (!shellRefreshActive) {
            return;
        }
        shellRefreshActive = false;
        handler.removeCallbacks(shellRefreshRunnable);
    }

    @Override
    public void refreshShellState() {
        refreshShellState(false);
    }

    private void refreshShellState(boolean logEvent) {
        final ShellSessionController.PollResult pollResult = shellSessionController.poll();
        if (pollResult.autoStarted) {
            appendEvent("auto.shellStart status=" + shellStartStatusLabel(pollResult.autoStartStatus));
        }

        shellTranscriptController.applyTranscript(pollResult.transcript);
        if (logEvent) {
            appendEvent("manual.shellRefresh alive=" + pollResult.alive + " status=" + shellStartStatusLabel(pollResult.status));
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
                Gravity.CENTER);
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
            BootstrapDebugFormatter.SurfaceEventSnapshot state) {
        appendEvent(BootstrapDebugFormatter.formatSurfaceEvent(
                event,
                new BootstrapDebugFormatter.SurfaceEventSnapshot(
                        seq,
                        state.token,
                        state.epoch,
                        state.transition,
                        state.glesStatus,
                        state.glesSwapCount,
                        state.glesBoundEpoch,
                        state.glesContextCreateCount,
                        state.glesSurfaceCreateCount,
                        state.glesTextureCreateCount,
                        state.glesTextureAlive,
                        state.glesTextureUploadCount,
                        state.glesTextureUpdateCount,
                        state.glesTextureResizeCount,
                        state.glesTextureWidth,
                        state.glesTextureHeight)));
    }

    private BootstrapDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return new BootstrapDebugFormatter.SurfaceEventSnapshot(
                0,
                nativeLoaded ? nativeCurrentWindowTokenBridge() : 0,
                nativeLoaded ? nativeCurrentSurfaceEpochBridge() : 0,
                surfaceTransitionLabel(nativeLoaded ? nativeCurrentSurfaceTransitionBridge() : 0),
                glesProbeStatusLabel(nativeLoaded ? nativeCurrentGlesProbeStatusBridge() : 0),
                nativeLoaded ? nativeCurrentGlesProbeSwapCountBridge() : 0,
                nativeLoaded ? nativeCurrentGlesProbeBoundEpochBridge() : 0,
                nativeLoaded ? nativeCurrentGlesProbeContextCreateCountBridge() : 0,
                nativeLoaded ? nativeCurrentGlesProbeSurfaceCreateCountBridge() : 0,
                nativeLoaded ? nativeCurrentGlesProbeTextureCreateCountBridge() : 0,
                nativeLoaded && nativeCurrentGlesProbeTextureAliveBridge(),
                nativeLoaded ? nativeCurrentGlesProbeTextureUploadCountBridge() : 0,
                nativeLoaded ? nativeCurrentGlesProbeTextureUpdateCountBridge() : 0,
                nativeLoaded ? nativeCurrentGlesProbeTextureResizeCountBridge() : 0,
                nativeLoaded ? nativeCurrentGlesProbeTextureWidthBridge() : 0,
                nativeLoaded ? nativeCurrentGlesProbeTextureHeightBridge() : 0);
    }

    private void updateStatus(String state) {
        final BootstrapDebugFormatter.SurfaceEventSnapshot surfaceState = currentSurfaceStateSnapshot();
        statusText.setText(BootstrapDebugFormatter.formatStatus(
                new BootstrapDebugFormatter.StatusSnapshot(
                        state,
                        nativeLoaded,
                        hasWindowFocus(),
                        imeVisible,
                        surfaceView.getHolder().getSurface().isValid(),
                        surfaceView.getWidth(),
                        surfaceView.getHeight(),
                        surfaceState.glesStatus,
                        surfaceState.glesSwapCount,
                        surfaceState.glesBoundEpoch,
                        surfaceState.glesContextCreateCount,
                        surfaceState.glesSurfaceCreateCount,
                        surfaceState.glesTextureCreateCount,
                        surfaceState.glesTextureAlive,
                        surfaceState.glesTextureUploadCount,
                        surfaceState.glesTextureUpdateCount,
                        surfaceState.glesTextureResizeCount,
                        surfaceState.glesTextureWidth,
                        surfaceState.glesTextureHeight)));
        updateImeToggleLabel();
    }

    private static String surfaceTransitionLabel(int transition) {
        return switch (transition) {
            case 1 -> "acquired";
            case 2 -> "replaced";
            case 3 -> "retired";
            default -> "unchanged";
        };
    }

    private static String shellStartStatusLabel(int status) {
        return switch (status) {
            case 1 -> "started";
            case 2 -> "unsupported";
            case 3 -> "create-failed";
            case 4 -> "resize-failed";
            case 5 -> "start-failed";
            case 6 -> "send-failed";
            case 7 -> "poll-failed";
            case 8 -> "snapshot-failed";
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

    @Override
    public void appendEvent(String message) {
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

    private static native int nativeRestartShellSessionBridge();

    private static native int nativePollShellSessionBridge();

    private static native boolean nativeIsShellSessionAliveBridge();

    private static native int nativeSendShellCodepointBridge(int codepoint);
}
