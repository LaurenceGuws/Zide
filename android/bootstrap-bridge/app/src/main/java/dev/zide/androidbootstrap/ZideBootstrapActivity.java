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
import android.view.MotionEvent;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.view.KeyEvent;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.ExtractedText;
import android.view.inputmethod.ExtractedTextRequest;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ScrollView;
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
    private View shellInputView;
    private ScrollView shellOutputScroll;
    private SurfaceView surfaceView;
    private boolean debugViewEnabled = false;
    private boolean imeVisible = false;
    private boolean surfaceRecreationScheduled = false;
    private boolean surfaceResizeScheduled = false;
    private boolean shellStartScheduled = false;
    private boolean shellRefreshActive = false;
    private boolean shellAutoStartAttempted = false;
    private boolean shellAutoFollowEnabled = true;
    private String lastShellTranscript = "";
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
        installShellInputView();
        installInsetsHandling();
        installShellScrollHandling();
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

    private void installShellScrollHandling() {
        shellOutputScroll.setOnTouchListener((view, event) -> {
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    shellOutputScroll.post(() -> shellAutoFollowEnabled = isShellOutputNearBottom());
                    break;
                default:
                    shellAutoFollowEnabled = false;
                    break;
            }
            return false;
        });
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
                glesTextureHeight);
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
                glesTextureHeight);
        updateStatus("surface-destroyed");
    }

    @Override
    public void surfaceRedrawNeeded(SurfaceHolder holder) {
        appendEvent(
                "surface.redrawNeeded generation=" + surfaceHostGeneration + " valid=" + holder.getSurface().isValid());
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
                        " glesTextureSize=" + glesTextureWidth + "x" + glesTextureHeight);
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

    // Minimal editor model: the IME needs a coherent buffer + cursor to trust us
    // with navigation. We maintain a multi-line buffer with sentinel lines above
    // and below so the IME always sees content in all four directions.
    //
    // Layout: "<sentinel>\n<current line content>\n<sentinel>"
    // The sentinel lines are fixed padding; the middle line tracks typed content.
    // setSelection movement across newlines → up/down terminal escapes.
    // setSelection movement within a line → left/right terminal escapes.
    private static final String SENTINEL = "........";
    private final StringBuilder editorBuffer = new StringBuilder();
    private int editorCursor = 0;
    private int editorComposingStart = -1;
    private int editorComposingEnd = -1;

    private void resetEditorState() {
        editorBuffer.setLength(0);
        editorBuffer.append(SENTINEL).append('\n').append(SENTINEL).append('\n').append(SENTINEL);
        editorCursor = SENTINEL.length() + 1; // start of middle line
        editorComposingStart = -1;
        editorComposingEnd = -1;
    }

    private int editorLineStart() {
        int i = editorCursor - 1;
        while (i >= 0 && editorBuffer.charAt(i) != '\n') i--;
        return i + 1;
    }

    private int editorLineEnd() {
        int i = editorCursor;
        while (i < editorBuffer.length() && editorBuffer.charAt(i) != '\n') i++;
        return i;
    }

    private void installShellInputView() {
        resetEditorState();
        final ZideBootstrapActivity activity = this;
        shellInputView = new View(this) {
            @Override
            public boolean onCheckIsTextEditor() {
                return true;
            }

            @Override
            public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
                outAttrs.inputType = EditorInfo.TYPE_CLASS_TEXT
                    | EditorInfo.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                    | EditorInfo.TYPE_TEXT_FLAG_MULTI_LINE;
                outAttrs.imeOptions = EditorInfo.IME_FLAG_NO_EXTRACT_UI
                    | EditorInfo.IME_FLAG_NO_FULLSCREEN
                    | EditorInfo.IME_ACTION_NONE;
                outAttrs.initialSelStart = editorCursor;
                outAttrs.initialSelEnd = editorCursor;
                return new BaseInputConnection(this, false) {

                    @Override
                    public ExtractedText getExtractedText(ExtractedTextRequest request, int flags) {
                        final ExtractedText et = new ExtractedText();
                        et.text = editorBuffer.toString();
                        et.startOffset = 0;
                        et.selectionStart = editorCursor;
                        et.selectionEnd = editorCursor;
                        return et;
                    }

                    @Override
                    public CharSequence getTextBeforeCursor(int n, int flags) {
                        final int start = Math.max(0, editorCursor - n);
                        return editorBuffer.substring(start, editorCursor);
                    }

                    @Override
                    public CharSequence getTextAfterCursor(int n, int flags) {
                        final int end = Math.min(editorBuffer.length(), editorCursor + n);
                        return editorBuffer.substring(editorCursor, end);
                    }

                    @Override
                    public boolean setSelection(int start, int end) {
                        final int oldCursor = editorCursor;
                        final int newCursor = Math.max(0, Math.min(start, editorBuffer.length()));
                        if (newCursor == oldCursor) return true;

                        final int from = Math.min(oldCursor, newCursor);
                        final int to = Math.max(oldCursor, newCursor);
                        int newlinesCrossed = 0;
                        for (int i = from; i < to; i++) {
                            if (editorBuffer.charAt(i) == '\n') newlinesCrossed++;
                        }

                        if (newlinesCrossed > 0) {
                            final String esc = (newCursor < oldCursor) ? "\u001b[A" : "\u001b[B";
                            for (int i = 0; i < newlinesCrossed; i++) {
                                activity.sendDirectText(esc);
                            }
                            activity.appendEvent("input.nav " + (newCursor < oldCursor ? "up" : "down") + " x" + newlinesCrossed);
                        } else {
                            final int delta = newCursor - oldCursor;
                            final String esc = (delta < 0) ? "\u001b[D" : "\u001b[C";
                            final int count = Math.abs(delta);
                            for (int i = 0; i < count; i++) {
                                activity.sendDirectText(esc);
                            }
                            activity.appendEvent("input.nav " + (delta < 0 ? "left" : "right") + " x" + count);
                        }

                        // Reset to neutral so IME always has room in all directions
                        resetEditorState();
                        activity.refreshShellState(false);
                        return true;
                    }

                    @Override
                    public boolean setComposingText(CharSequence text, int newCursorPosition) {
                        // Erase previous composing region from buffer
                        if (editorComposingStart >= 0 && editorComposingEnd > editorComposingStart) {
                            final int len = editorComposingEnd - editorComposingStart;
                            editorBuffer.delete(editorComposingStart, editorComposingEnd);
                            editorCursor = editorComposingStart;
                            for (int i = 0; i < len; i++) {
                                activity.sendDirectCodepoint('\u007f');
                            }
                        }
                        // Insert new composing text
                        final String s = text.toString();
                        if (s.length() > 0) {
                            editorBuffer.insert(editorCursor, s);
                            editorComposingStart = editorCursor;
                            editorCursor += s.length();
                            editorComposingEnd = editorCursor;
                            activity.sendDirectText(s);
                        } else {
                            editorComposingStart = -1;
                            editorComposingEnd = -1;
                        }
                        activity.appendEvent("input.compose len=" + s.length());
                        activity.refreshShellState(false);
                        return true;
                    }

                    @Override
                    public boolean finishComposingText() {
                        editorComposingStart = -1;
                        editorComposingEnd = -1;
                        return true;
                    }

                    @Override
                    public boolean commitText(CharSequence text, int newCursorPosition) {
                        // Erase composing region if active
                        if (editorComposingStart >= 0 && editorComposingEnd > editorComposingStart) {
                            final int len = editorComposingEnd - editorComposingStart;
                            editorBuffer.delete(editorComposingStart, editorComposingEnd);
                            editorCursor = editorComposingStart;
                            for (int i = 0; i < len; i++) {
                                activity.sendDirectCodepoint('\u007f');
                            }
                        }
                        editorComposingStart = -1;
                        editorComposingEnd = -1;
                        // Insert committed text
                        final String s = text.toString();
                        editorBuffer.insert(editorCursor, s);
                        editorCursor += s.length();
                        activity.sendDirectText(s);
                        activity.appendEvent("input.commit text=" + text);
                        activity.refreshShellState(false);
                        return true;
                    }

                    @Override
                    public boolean deleteSurroundingText(int beforeLength, int afterLength) {
                        if (beforeLength > 0) {
                            final int delStart = Math.max(0, editorCursor - beforeLength);
                            final int count = editorCursor - delStart;
                            editorBuffer.delete(delStart, editorCursor);
                            editorCursor = delStart;
                            for (int i = 0; i < count; i++) {
                                activity.sendDirectCodepoint('\u007f');
                            }
                            activity.appendEvent("input.delete before=" + count);
                        }
                        if (afterLength > 0) {
                            final int delEnd = Math.min(editorBuffer.length(), editorCursor + afterLength);
                            editorBuffer.delete(editorCursor, delEnd);
                            activity.appendEvent("input.delete after=" + (delEnd - editorCursor));
                        }
                        activity.refreshShellState(false);
                        return true;
                    }

                    @Override
                    public boolean sendKeyEvent(KeyEvent event) {
                        if (event.getAction() != KeyEvent.ACTION_DOWN) return super.sendKeyEvent(event);
                        activity.appendEvent("input.key code=" + event.getKeyCode()
                            + " name=" + KeyEvent.keyCodeToString(event.getKeyCode()));
                        final String esc = mapKeyToEscape(event.getKeyCode());
                        if (esc != null) {
                            activity.sendDirectText(esc);
                            activity.refreshShellState(false);
                            return true;
                        }
                        switch (event.getKeyCode()) {
                            case KeyEvent.KEYCODE_DEL:
                                activity.sendDirectCodepoint('\u007f');
                                if (editorCursor > editorLineStart()) {
                                    editorBuffer.deleteCharAt(editorCursor - 1);
                                    editorCursor--;
                                }
                                activity.refreshShellState(false);
                                return true;
                            case KeyEvent.KEYCODE_ENTER:
                                activity.sendDirectCodepoint('\n');
                                resetEditorState();
                                activity.refreshShellState(false);
                                return true;
                            case KeyEvent.KEYCODE_TAB:
                                activity.sendDirectCodepoint('\t');
                                activity.refreshShellState(false);
                                return true;
                            case KeyEvent.KEYCODE_ESCAPE:
                                activity.sendDirectCodepoint('\u001b');
                                activity.refreshShellState(false);
                                return true;
                        }
                        return super.sendKeyEvent(event);
                    }

                    private String mapKeyToEscape(int keyCode) {
                        return switch (keyCode) {
                            case KeyEvent.KEYCODE_DPAD_UP -> "\u001b[A";
                            case KeyEvent.KEYCODE_DPAD_DOWN -> "\u001b[B";
                            case KeyEvent.KEYCODE_DPAD_RIGHT -> "\u001b[C";
                            case KeyEvent.KEYCODE_DPAD_LEFT -> "\u001b[D";
                            case KeyEvent.KEYCODE_MOVE_HOME -> "\u001b[H";
                            case KeyEvent.KEYCODE_MOVE_END -> "\u001b[F";
                            case KeyEvent.KEYCODE_INSERT -> "\u001b[2~";
                            case KeyEvent.KEYCODE_FORWARD_DEL -> "\u001b[3~";
                            case KeyEvent.KEYCODE_PAGE_UP -> "\u001b[5~";
                            case KeyEvent.KEYCODE_PAGE_DOWN -> "\u001b[6~";
                            default -> null;
                        };
                    }
                };
            }
        };
        shellInputView.setFocusable(true);
        shellInputView.setFocusableInTouchMode(true);
        final FrameLayout root = (FrameLayout) productView.getParent();
        final FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(1, 1);
        lp.gravity = Gravity.BOTTOM | Gravity.START;
        root.addView(shellInputView, lp);

        shellOutputScroll.setOnClickListener(v -> toggleIme());
    }

    private void sendDirectCodepoint(int codepoint) {
        if (!nativeLoaded)
            return;
        nativeSendShellCodepointBridge(codepoint);
    }

    private void sendDirectText(String text) {
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

    private void refreshShellState(boolean logEvent) {
        int status = nativeLoaded ? nativePollShellSessionBridge() : 0;
        boolean alive = nativeLoaded && nativeIsShellSessionAliveBridge();
        String transcript = readTextFile(SHELL_TRANSCRIPT_PATH);
        final boolean shouldFollowOutput = shouldFollowShellOutput();

        if (nativeLoaded && !alive && !shellAutoStartAttempted) {
            shellAutoStartAttempted = true;
            status = nativeRestartShellSessionBridge();
            appendEvent("auto.shellStart status=" + shellStartStatusLabel(status));
            status = nativePollShellSessionBridge();
            alive = nativeIsShellSessionAliveBridge();
            transcript = readTextFile(SHELL_TRANSCRIPT_PATH);
        }

        if (!transcript.equals(lastShellTranscript)) {
            lastShellTranscript = transcript;
            shellOutputText.setText(transcript);
            if (shouldFollowOutput) {
                shellOutputScroll.post(() -> shellOutputScroll.fullScroll(View.FOCUS_DOWN));
            }
        }
        if (logEvent) {
            appendEvent("manual.shellRefresh alive=" + alive + " status=" + shellStartStatusLabel(status));
        }
    }

    private boolean shouldFollowShellOutput() {
        if (imeVisible)
            return true;
        return shellAutoFollowEnabled;
    }

    private boolean isShellOutputNearBottom() {
        final View content = shellOutputScroll.getChildCount() > 0 ? shellOutputScroll.getChildAt(0) : null;
        if (content == null)
            return true;
        final int remaining = content.getBottom() - (shellOutputScroll.getScrollY() + shellOutputScroll.getHeight());
        return remaining <= 32;
    }

    private String readTextFile(String path) {
        final File file = new File(path);
        if (!file.exists()) {
            return "";
        }

        final StringBuilder out = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new FileReader(file))) {
            String line;
            boolean first = true;
            while ((line = reader.readLine()) != null) {
                if (!first) {
                    out.append('\n');
                }
                out.append(line);
                first = false;
            }
        } catch (IOException err) {
            return "read-error:" + err.getClass().getSimpleName();
        }
        return out.toString();
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
            int glesTextureHeight) {
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
                        " glesTextureSize=" + glesTextureWidth + "x" + glesTextureHeight);
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

    private void updateStatus(String state) {
        final int surfaceWidth = surfaceView.getWidth();
        final int surfaceHeight = surfaceView.getHeight();
        final boolean surfaceValid = surfaceView.getHolder().getSurface().isValid();
        final String glesStatus = nativeLoaded ? glesProbeStatusLabel(nativeCurrentGlesProbeStatusBridge())
                : "unavailable";
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
                        "x" + (nativeLoaded ? nativeCurrentGlesProbeTextureHeightBridge() : 0));
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
