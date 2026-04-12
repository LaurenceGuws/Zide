package dev.zide.terminal;

import android.app.Activity;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.graphics.Insets;
import android.os.Bundle;
import android.os.Handler;
import android.os.SystemClock;
import android.os.Looper;
import android.util.Log;
import android.view.Choreographer;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.view.KeyEvent;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;
import java.io.File;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Map;

public final class ZideTerminalActivity extends Activity
        implements SurfaceHolder.Callback2, ShellInputView.Host, ProductGestureController.Host {
    private static final String TAG = "ZideAndroidTerminal";
    private static final int MAX_LOG_CHARS = 12000;
    private static final String EXTRA_DEBUG_RECREATE_SURFACE_ONCE = "debug_recreate_surface_once";
    private static final String EXTRA_DEBUG_RESIZE_SURFACE_ONCE = "debug_resize_surface_once";
    private static final String EXTRA_DEBUG_START_SHELL_ONCE = "debug_start_shell_once";
    private static final float MIN_PENDING_PINCH_APPLY_DELTA = 0.008f;
    /**
     * Product pinch budget for native zoom work.
     *
     * <p>Pinch is much more sensitive than shortcut zoom. The host therefore coalesces pinch intent
     * and applies at most one native zoom update per interval instead of trying to honor every raw
     * detector burst synchronously.
     */
    private static final long MIN_PINCH_APPLY_INTERVAL_MS = 24L;
    private static final String[] RUNTIME_FONT_ASSETS = {
            "IosevkaTermNerdFont-Regular.ttf",
            "JetBrainsMonoNerdFont-Regular.ttf",
            "NotoColorEmoji.ttf",
            "NotoEmoji-Regular.ttf",
            "NotoSans-Regular.ttf",
            "NotoSansMono-Regular.ttf",
            "NotoSansSymbols-Regular.ttf",
            "NotoSansSymbols2-Regular.ttf",
            "SymbolsNerdFontMono-Regular.ttf",
    };

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
    private TextView packageStatusText;
    private TextView eventLogText;
    private TextView productBootstrapTitle;
    private TextView productBootstrapDetail;
    private Button productBootstrapRetryButton;
    private Button productBootstrapDebugButton;
    private View rootView;
    private View productView;
    private View debugView;
    private View productBootstrapBlocker;
    private View drawerScrim;
    private View drawerEdgeHotspot;
    private View leftSidebar;
    private FrameLayout productContentFrame;
    private FrameLayout productSurfaceContainer;
    private Button assistCtrlButton;
    private Button assistAltButton;
    private ShellInputView shellInputView;
    private ProductGestureController productGestureController;
    private boolean pinchZoomActive = false;
    private boolean pinchZoomFrameScheduled = false;
    private boolean pinchZoomRetryScheduled = false;
    private float pendingPinchScaleFactor = 1.0f;
    private long lastPinchApplyUptimeMs = 0L;
    private ShellSessionController shellSessionController;
    private SurfaceView surfaceView;
    private boolean debugViewEnabled = false;
    private boolean imeVisible = false;
    private boolean surfaceRecreationScheduled = false;
    private boolean surfaceResizeScheduled = false;
    private boolean shellStartScheduled = false;
    private boolean productFrameLoopActive = false;
    private boolean sidebarOpen = false;
    private String lastAutoStartBlockedState = "";
    private UserlandRelease userlandRelease;
    private UserlandInstallState currentInstallState = UserlandInstallState.idle();
    private UserlandBootstrapState currentBootstrapState;
    private int surfaceHostGeneration = 0;
    private int productViewBasePaddingLeft = 0;
    private int productViewBasePaddingTop = 0;
    private int productViewBasePaddingRight = 0;
    private int productViewBasePaddingBottom = 0;
    private int visibleViewportWidth = 0;
    private int visibleViewportHeight = 0;
    private int notifiedViewportWidth = 0;
    private int notifiedViewportHeight = 0;
    private boolean notifiedViewportImeVisible = false;
    private final Runnable productFrameRunnable = new Runnable() {
        @Override
        public void run() {
            if (!productFrameLoopActive) {
                return;
            }
            final int tick = nativeLoaded ? nativeTickProductShellFrameBridge() : 0;
            if (!shouldRunProductFrameLoop() || tick == 0) {
                stopProductFrameLoop();
                return;
            }
            handler.postDelayed(this, tick == 2 ? 16L : 33L);
        }
    };
    private final Runnable pinchZoomRetryRunnable = new Runnable() {
        @Override
        public void run() {
            pinchZoomRetryScheduled = false;
            if (!pinchZoomActive) {
                return;
            }
            if (Math.abs(pendingPinchScaleFactor - 1.0f) < MIN_PENDING_PINCH_APPLY_DELTA) {
                return;
            }
            schedulePinchZoomFrame();
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        statusText = findViewById(R.id.status_text);
        packageStatusText = findViewById(R.id.package_status_text);
        eventLogText = findViewById(R.id.event_log);
        productBootstrapTitle = findViewById(R.id.product_bootstrap_title);
        productBootstrapDetail = findViewById(R.id.product_bootstrap_detail);
        productBootstrapRetryButton = findViewById(R.id.product_bootstrap_retry_button);
        productBootstrapDebugButton = findViewById(R.id.product_bootstrap_debug_button);
        rootView = findViewById(R.id.root_view);
        productView = findViewById(R.id.product_view);
        debugView = findViewById(R.id.debug_view);
        productBootstrapBlocker = findViewById(R.id.product_bootstrap_blocker);
        drawerScrim = findViewById(R.id.drawer_scrim);
        drawerEdgeHotspot = findViewById(R.id.left_edge_swipe_hotspot);
        leftSidebar = findViewById(R.id.left_sidebar);
        productContentFrame = findViewById(R.id.product_content_frame);
        productSurfaceContainer = findViewById(R.id.product_surface_container);
        assistCtrlButton = findViewById(R.id.assist_ctrl_button);
        assistAltButton = findViewById(R.id.assist_alt_button);
        userlandRelease = loadUserlandRelease();
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
                UserlandPolicy.bootstrapStampPath(this),
                UserlandPolicy.shellPath(this),
                userlandRelease,
                nativeLoaded);
        currentBootstrapState = shellSessionController.loadBootstrapState();
        installShellInputView();
        installInsetsHandling();
        installViewportTracking();
        bindSidebarControls();
        bindViewModeToggle();
        bindProductBootstrapBlocker();
        bindAssistBar();
        prepareRuntimeAssets();
        applyViewMode();
        installSurfaceView("activity-create");
        updateProductShellVisibility();
        reevaluateProductFrameLoop();
        leftSidebar.post(() -> {
            leftSidebar.setTranslationX(-leftSidebar.getWidth());
            updateSidebarVisibility(false);
        });

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
            productSurfaceContainer.post(() -> notifyVisibleViewport("insets"));
            return windowInsets;
        });
        productView.requestApplyInsets();
    }

    private void installViewportTracking() {
        productSurfaceContainer.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {
            if (left == oldLeft && top == oldTop && right == oldRight && bottom == oldBottom) {
                return;
            }
            notifyVisibleViewport("layout");
        });
    }

    private void prepareRuntimeAssets() {
        final File runtimeRoot = getFilesDir();
        final File fontsDir = new File(new File(runtimeRoot, "assets"), "fonts");
        if (!fontsDir.isDirectory() && !fontsDir.mkdirs()) {
            appendEvent("runtime.assets mkdirFailed path=" + fontsDir.getAbsolutePath());
            return;
        }

        final long assetStamp = currentPackageAssetStamp();
        final File stampFile = new File(fontsDir, ".stamp");
        final String expectedStamp = Long.toString(assetStamp);
        final String currentStamp = readTextFile(stampFile);
        if (!expectedStamp.equals(currentStamp)) {
            for (String assetName : RUNTIME_FONT_ASSETS) {
                try {
                    copyAssetToFile(assetName, new File(fontsDir, assetName));
                } catch (IOException err) {
                    appendEvent("runtime.assets copyFailed asset=" + assetName + " err=" + err.getClass().getSimpleName());
                    return;
                }
            }
            writeTextFile(stampFile, expectedStamp);
            appendEvent("runtime.assets refreshed stamp=" + expectedStamp);
        } else {
            appendEvent("runtime.assets reused stamp=" + expectedStamp);
        }

        appendEvent("runtime.assets ready path=" + fontsDir.getAbsolutePath());
    }

    private UserlandRelease loadUserlandRelease() {
        try {
            return UserlandRelease.load(this);
        } catch (IOException err) {
            appendEvent("userland.release loadFailed err=" + err.getClass().getSimpleName());
            return new UserlandRelease("", "", "", "");
        }
    }

    private long currentPackageAssetStamp() {
        try {
            return getPackageManager().getPackageInfo(getPackageName(), 0).lastUpdateTime;
        } catch (Exception err) {
            return 0L;
        }
    }

    private static String readTextFile(File file) {
        if (!file.isFile()) {
            return "";
        }
        try (FileInputStream in = new FileInputStream(file)) {
            final ByteArrayOutputStream out = new ByteArrayOutputStream();
            final byte[] buffer = new byte[256];
            while (true) {
                final int read = in.read(buffer);
                if (read < 0) {
                    break;
                }
                out.write(buffer, 0, read);
            }
            return out.toString().trim();
        } catch (IOException err) {
            return "";
        }
    }

    private void writeTextFile(File file, String text) {
        try (FileOutputStream out = new FileOutputStream(file, false)) {
            out.write(text.getBytes());
            out.getFD().sync();
        } catch (IOException err) {
            appendEvent("runtime.assets stampWriteFailed err=" + err.getClass().getSimpleName());
        }
    }

    private void copyAssetToFile(String assetName, File destination) throws IOException {
        try (InputStream in = getAssets().open(assetName);
                FileOutputStream out = new FileOutputStream(destination, false)) {
            final byte[] buffer = new byte[8192];
            while (true) {
                final int read = in.read(buffer);
                if (read < 0) {
                    break;
                }
                out.write(buffer, 0, read);
            }
            out.getFD().sync();
        }
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
        handler.post(() -> refreshDebugShellState(false));
        reevaluateProductFrameLoop();
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
        stopProductFrameLoop();
        refreshDebugShellState(false);
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
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (shouldHandleHardwareKeyboardEvent(event)) {
            shellInputView.requestFocus();
            if (imeVisible) {
                final InputMethodManager imm = getSystemService(InputMethodManager.class);
                if (imm != null) {
                    imm.hideSoftInputFromWindow(shellInputView.getWindowToken(), 0);
                }
                imeVisible = false;
                updateStatus("hardware-keyboard");
            }
            if (shellInputView.handleHardwareKeyEvent(event)) {
                return true;
            }
        }
        return super.dispatchKeyEvent(event);
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
        productSurfaceContainer.post(() -> notifyVisibleViewport("surface-changed"));
        handler.post(() -> refreshDebugShellState(false));
        updateStatus("surface-changed");
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        appendEvent("surface.destroyed generation=" + surfaceHostGeneration);
        stopProductFrameLoop();
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
        final AndroidDebugFormatter.SurfaceEventSnapshot state = currentSurfaceStateSnapshot();
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
            refreshDebugShellState(false);
            updateStatus("debug-shell-started");
        }, 900);
    }

    private void bindViewModeToggle() {
        final Button debugViewModeButton = findViewById(R.id.debug_view_mode_button);
        debugViewModeButton.setOnClickListener(view -> {
            debugViewEnabled = false;
            appendEvent("view.mode debug=false");
            applyViewMode();
            updateStatus("product-view");
        });
    }

    private void bindSidebarControls() {
        final Button restartButton = findViewById(R.id.sidebar_restart_button);
        final Button debugButton = findViewById(R.id.sidebar_debug_button);
        final Button packagesButton = findViewById(R.id.sidebar_packages_button);

        restartButton.setOnClickListener(view -> {
            final int status = nativeLoaded ? nativeRestartShellSessionBridge() : 0;
            appendEvent("manual.shellRestart status=" + shellStartStatusLabel(status));
            refreshDebugShellState(false);
            updateStatus("shell-restarted");
            closeSidebar();
        });

        debugButton.setOnClickListener(view -> {
            debugViewEnabled = true;
            appendEvent("view.mode debug=true");
            applyViewMode();
            refreshDebugShellState(false);
            updateStatus("debug-view");
            closeSidebar();
        });

        packagesButton.setOnClickListener(view -> {
            closeSidebar();
            runPackageDoctor();
        });

        drawerScrim.setOnClickListener(view -> closeSidebar());
        drawerEdgeHotspot.setOnTouchListener(new EdgeSwipeListener(true));
        leftSidebar.setOnTouchListener(new EdgeSwipeListener(false));
    }

    private void bindAssistBar() {
        bindAssistButton(R.id.assist_esc_button, "\u001b", "assist.esc");
        bindAssistButton(R.id.assist_tab_button, "\t", "assist.tab");
        bindModifierAssistButton(assistCtrlButton, ShellInputView.ModifierLatch.CTRL, "assist.ctrl");
        bindModifierAssistButton(assistAltButton, ShellInputView.ModifierLatch.ALT, "assist.alt");
        bindAssistButton(R.id.assist_pipe_button, "|", "assist.pipe");
        bindAssistButton(R.id.assist_slash_button, "/", "assist.slash");
        bindAssistButton(R.id.assist_up_button, "\u001b[A", "assist.up");
        bindAssistButton(R.id.assist_down_button, "\u001b[B", "assist.down");
        bindAssistButton(R.id.assist_left_button, "\u001b[D", "assist.left");
        bindAssistButton(R.id.assist_right_button, "\u001b[C", "assist.right");
        applyModifierLatchState(shellInputView.modifierLatchState());
    }

    private void bindProductBootstrapBlocker() {
        productBootstrapRetryButton.setOnClickListener(view -> {
            if (currentInstallState.isInstalling()) {
                appendEvent("product.install ignored=already-installing");
                return;
            }
            if (shouldStartInstall(currentBootstrapState)) {
                startUserlandInstall();
                return;
            }
            appendEvent("product.bootstrap retry");
            refreshDebugShellState(true);
            updateStatus("product-bootstrap-retry");
        });
        productBootstrapDebugButton.setOnClickListener(view -> {
            debugViewEnabled = true;
            appendEvent("product.bootstrap debug");
            applyViewMode();
            refreshDebugShellState(false);
            updateStatus("debug-view");
        });
    }

    private void bindAssistButton(int id, String text, String eventName) {
        final Button button = findViewById(id);
        button.setOnClickListener(view -> {
            sendDirectText(text);
            appendEvent(eventName);
        });
    }

    private void bindModifierAssistButton(Button button, ShellInputView.ModifierLatch modifier, String eventName) {
        button.setOnClickListener(view -> {
            shellInputView.toggleModifierLatch(modifier);
            appendEvent(eventName + " toggled");
            openIme();
        });
    }

    private void installShellInputView() {
        shellInputView = new ShellInputView(this, this);
        final FrameLayout root = (FrameLayout) rootView;
        final FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(1, 1);
        lp.gravity = Gravity.BOTTOM | Gravity.START;
        root.addView(shellInputView, lp);
    }

    @Override
    public void onProductSingleTap() {
        openIme();
    }

    @Override
    public void onProductPinchBegin() {
        if (!nativeLoaded) {
            return;
        }
        pinchZoomActive = true;
        pinchZoomRetryScheduled = false;
        pendingPinchScaleFactor = 1.0f;
        nativeSetTerminalPinchActiveBridge(true);
    }

    @Override
    public void onProductPinchZoom(float scaleFactor) {
        if (!nativeLoaded || scaleFactor <= 0.0f) {
            return;
        }
        if (Math.abs(scaleFactor - 1.0f) < MIN_PENDING_PINCH_APPLY_DELTA) {
            return;
        }
        pendingPinchScaleFactor *= scaleFactor;
        schedulePinchZoomFrame();
    }

    @Override
    public void onProductPinchEnd() {
        if (!nativeLoaded) {
            return;
        }
        final float finalScaleFactor = pendingPinchScaleFactor;
        if (Math.abs(finalScaleFactor - 1.0f) >= MIN_PENDING_PINCH_APPLY_DELTA) {
            nativeApplyTerminalPinchZoomBridge(finalScaleFactor);
            lastPinchApplyUptimeMs = SystemClock.uptimeMillis();
        }
        pinchZoomActive = false;
        pinchZoomRetryScheduled = false;
        handler.removeCallbacks(pinchZoomRetryRunnable);
        pendingPinchScaleFactor = 1.0f;
        nativeSetTerminalPinchActiveBridge(false);
    }

    private void schedulePinchZoomFrame() {
        if (pinchZoomFrameScheduled) {
            return;
        }
        pinchZoomFrameScheduled = true;
        Choreographer.getInstance().postFrameCallback(frameTimeNanos -> {
            pinchZoomFrameScheduled = false;
            if (!nativeLoaded || !pinchZoomActive) {
                return;
            }
            final float scaleFactor = pendingPinchScaleFactor;
            pendingPinchScaleFactor = 1.0f;
            if (Math.abs(scaleFactor - 1.0f) < MIN_PENDING_PINCH_APPLY_DELTA) {
                return;
            }
            final long now = SystemClock.uptimeMillis();
            final long elapsedSinceLastApply = now - lastPinchApplyUptimeMs;
            if (lastPinchApplyUptimeMs != 0L && elapsedSinceLastApply < MIN_PINCH_APPLY_INTERVAL_MS) {
                final long delayMs = MIN_PINCH_APPLY_INTERVAL_MS - elapsedSinceLastApply;
                pendingPinchScaleFactor *= scaleFactor;
                schedulePinchZoomRetry(delayMs);
                return;
            }
            nativeApplyTerminalPinchZoomBridge(scaleFactor);
            lastPinchApplyUptimeMs = now;
            if (pinchZoomActive && Math.abs(pendingPinchScaleFactor - 1.0f) >= MIN_PENDING_PINCH_APPLY_DELTA) {
                schedulePinchZoomFrame();
            }
        });
    }

    private void schedulePinchZoomRetry(long delayMs) {
        if (pinchZoomRetryScheduled) {
            return;
        }
        pinchZoomRetryScheduled = true;
        handler.postDelayed(pinchZoomRetryRunnable, Math.max(1L, delayMs));
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

    @Override
    public void onInputFocusChanged(boolean hasFocus) {
        if (hasFocus || !imeVisible) {
            return;
        }
        shellInputView.post(() -> {
            appendEvent("input.focus recoverAttempt");
            shellInputView.requestFocusFromTouch();
            if (!shellInputView.hasFocus()) {
                shellInputView.requestFocus();
            }
            final InputMethodManager imm = getSystemService(InputMethodManager.class);
            if (imm != null) {
                imm.restartInput(shellInputView);
                final boolean shown = imm.showSoftInput(shellInputView, InputMethodManager.SHOW_IMPLICIT);
                appendEvent("input.focus recoverShown=" + shown + " focus=" + shellInputView.hasFocus());
            }
        });
    }

    @Override
    public void onModifierLatchChanged(ShellInputView.Host.ModifierLatchState state) {
        applyModifierLatchState(state);
    }

    private void applyModifierLatchState(ShellInputView.Host.ModifierLatchState state) {
        applyModifierButtonState(
                assistCtrlButton,
                state.ctrlLatched,
                R.string.assist_ctrl,
                R.string.assist_ctrl_latched);
        applyModifierButtonState(
                assistAltButton,
                state.altLatched,
                R.string.assist_alt,
                R.string.assist_alt_latched);
    }

    private void applyModifierButtonState(Button button, boolean latched, int idleLabelResId, int activeLabelResId) {
        if (button == null) {
            return;
        }
        button.setText(latched ? activeLabelResId : idleLabelResId);
        button.setAlpha(latched ? 1.0f : 0.72f);
        button.setActivated(latched);
        button.setSelected(latched);
    }

    private void applyViewMode() {
        productView.setVisibility(debugViewEnabled ? View.GONE : View.VISIBLE);
        debugView.setVisibility(debugViewEnabled ? View.VISIBLE : View.GONE);
        if (debugViewEnabled) {
            closeSidebar();
        } else {
            productSurfaceContainer.post(() -> notifyVisibleViewport("product-view"));
        }
    }

    private void openIme() {
        final InputMethodManager imm = getSystemService(InputMethodManager.class);
        if (imm == null) {
            appendEvent("manual.ime unavailable=true");
            return;
        }

        appendEvent("manual.imeOpen begin focus=" + shellInputView.hasFocus());
        shellInputView.requestFocusFromTouch();
        if (!shellInputView.hasFocus()) {
            shellInputView.requestFocus();
        }
        appendEvent("manual.imeOpen focusAfterRequest=" + shellInputView.hasFocus());
        imm.restartInput(shellInputView);
        final boolean shown = imm.showSoftInput(shellInputView, InputMethodManager.SHOW_IMPLICIT);
        imeVisible = shown || shellInputView.hasFocus();
        appendEvent("manual.imeOpen shown=" + shown + " focus=" + shellInputView.hasFocus());
        updateStatus("ime-shown");
    }

    private void openSidebar() {
        if (sidebarOpen || debugViewEnabled)
            return;
        sidebarOpen = true;
        leftSidebar.animate().translationX(0).setDuration(180).start();
        updateSidebarVisibility(true);
    }

    private void closeSidebar() {
        if (!sidebarOpen)
            return;
        sidebarOpen = false;
        leftSidebar.animate().translationX(-leftSidebar.getWidth()).setDuration(180).start();
        updateSidebarVisibility(false);
    }

    private void updateSidebarVisibility(boolean visible) {
        drawerScrim.setVisibility(visible ? View.VISIBLE : View.GONE);
        drawerEdgeHotspot.setVisibility(visible ? View.GONE : View.VISIBLE);
    }

    private boolean shouldUpdateDebugStatus() {
        return debugViewEnabled;
    }

    private boolean shouldRunProductFrameLoop() {
        return !debugViewEnabled
                && nativeLoaded
                && !currentInstallState.isInstalling()
                && !currentInstallState.isFailed()
                && currentBootstrapState.launchReady
                && currentBootstrapState.expectedCurrent
                && surfaceView != null
                && surfaceView.getHolder().getSurface().isValid();
    }

    private void startProductFrameLoop() {
        if (productFrameLoopActive) {
            return;
        }
        if (!shouldRunProductFrameLoop()) {
            return;
        }
        productFrameLoopActive = true;
        handler.post(productFrameRunnable);
    }

    private void stopProductFrameLoop() {
        if (!productFrameLoopActive) {
            return;
        }
        productFrameLoopActive = false;
        handler.removeCallbacks(productFrameRunnable);
    }

    private void reevaluateProductFrameLoop() {
        if (shouldRunProductFrameLoop()) {
            startProductFrameLoop();
        } else {
            stopProductFrameLoop();
        }
    }

    private void reloadBootstrapState() {
        currentBootstrapState = shellSessionController.loadBootstrapState();
    }

    private ShellSessionController.PollResult pollShellSession() {
        return shellSessionController.poll(currentBootstrapState);
    }

    private void applyShellPollTelemetry(ShellSessionController.PollResult pollResult, boolean logEvent) {
        if (pollResult.autoStarted) {
            appendEvent("auto.shellStart status=" + shellStartStatusLabel(pollResult.autoStartStatus));
        }
        if (pollResult.autoStartBlocked) {
            if (!currentBootstrapState.state.equals(lastAutoStartBlockedState)) {
                appendEvent(
                        "auto.shellStart blocked=" + currentBootstrapState.state +
                                " artifact=" + currentBootstrapState.artifact +
                                " version=" + currentBootstrapState.version);
                lastAutoStartBlockedState = currentBootstrapState.state;
            }
        } else {
            lastAutoStartBlockedState = "";
        }
        if (logEvent) {
            appendEvent("manual.shellRefresh alive=" + pollResult.alive + " status="
                    + shellStartStatusLabel(pollResult.status));
        }
    }

    private void refreshProductShellState() {
        updateProductShellVisibility();
        reevaluateProductFrameLoop();
    }

    private void refreshDebugStatusSurface() {
        if (!shouldUpdateDebugStatus()) {
            return;
        }
        updateStatus("shell-state", currentBootstrapState);
    }

    private void refreshDebugShellState(boolean logEvent) {
        reloadBootstrapState();
        final ShellSessionController.PollResult pollResult = pollShellSession();
        applyShellPollTelemetry(pollResult, logEvent);
        refreshProductShellState();
        refreshDebugStatusSurface();
    }

    private void installSurfaceView(String reason) {
        if (surfaceView != null) {
            surfaceView.getHolder().removeCallback(this);
            productSurfaceContainer.removeView(surfaceView);
            appendEvent("surface.hostRemoved reason=" + reason + " generation=" + surfaceHostGeneration);
        }

        surfaceHostGeneration += 1;
        final SurfaceView nextSurfaceView = new SurfaceView(this);
        final SurfaceHolder holder = nextSurfaceView.getHolder();
        holder.setFormat(PixelFormat.RGBA_8888);
        productGestureController = new ProductGestureController(nextSurfaceView, this);
        productGestureController.install();
        final FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER);
        productSurfaceContainer.addView(nextSurfaceView, params);
        holder.addCallback(this);
        surfaceView = nextSurfaceView;
        appendEvent("surface.hostInstalled reason=" + reason + " generation=" + surfaceHostGeneration);
        productSurfaceContainer.post(() -> notifyVisibleViewport("surface-install"));
    }

    private void notifyVisibleViewport(String reason) {
        if (debugViewEnabled || productView.getVisibility() != View.VISIBLE) {
            return;
        }
        final boolean viewportImeVisible = currentImeVisible();
        imeVisible = viewportImeVisible;
        final int width = Math.max(productContentFrame.getWidth(), 1);
        final int height = Math.max(productContentFrame.getHeight(), 1);
        visibleViewportWidth = width;
        visibleViewportHeight = height;
        if (width == notifiedViewportWidth &&
                height == notifiedViewportHeight &&
                viewportImeVisible == notifiedViewportImeVisible) {
            return;
        }
        notifiedViewportWidth = width;
        notifiedViewportHeight = height;
        notifiedViewportImeVisible = viewportImeVisible;
        appendEvent("viewport.changed reason=" + reason + " size=" + width + "x" + height + " imeVisible=" + viewportImeVisible);
        final long seq = nativeLoaded ? nativeOnVisibleViewportBridge(width, height, viewportImeVisible) : -1;
        callNativeWithSurfaceState("native.viewportChanged", seq, currentSurfaceStateSnapshot());
        updateStatus("viewport-updated");
    }

    private boolean currentImeVisible() {
        final WindowInsets insets = productView.getRootWindowInsets();
        if (insets == null) {
            return imeVisible;
        }
        final Insets navInsets = insets.getInsets(WindowInsets.Type.navigationBars());
        final Insets imeInsets = insets.getInsets(WindowInsets.Type.ime());
        return imeInsets.bottom > navInsets.bottom;
    }

    private void updateProductShellVisibility() {
        final boolean launchReady = currentBootstrapState.launchReady;
        final boolean sharedShellActive = launchReady && nativeLoaded && nativeSharedShellRendererActiveBridge();
        final boolean surfaceReady = surfaceView != null && surfaceView.getHolder().getSurface().isValid();
        final boolean rendererMissing = launchReady && currentBootstrapState.expectedCurrent && surfaceReady && !sharedShellActive;
        final boolean showBlocker = currentInstallState.isInstalling()
                || currentInstallState.isFailed()
                || !launchReady
                || !currentBootstrapState.expectedCurrent
                || rendererMissing;
        productBootstrapBlocker.setVisibility(showBlocker ? View.VISIBLE : View.GONE);
        if (showBlocker) {
            productBootstrapTitle.setText(productBootstrapTitle(currentBootstrapState, currentInstallState, rendererMissing));
            productBootstrapDetail.setText(productBootstrapDetail(currentBootstrapState, currentInstallState, rendererMissing));
            productBootstrapRetryButton.setEnabled(!currentInstallState.isInstalling());
            productBootstrapRetryButton.setText(productBootstrapActionLabel(currentBootstrapState, currentInstallState));
        }
    }

    private int productBootstrapTitle(UserlandBootstrapState state, UserlandInstallState installState, boolean rendererMissing) {
        if (installState.isInstalling()) {
            return R.string.product_bootstrap_title_installing;
        }
        if (installState.isFailed()) {
            return R.string.product_bootstrap_title_install_failed;
        }
        if (rendererMissing) {
            return R.string.product_bootstrap_title_renderer_missing;
        }
        switch (state.state) {
            case UserlandBootstrapState.STATE_INVALID_STAMP:
                return R.string.product_bootstrap_title_invalid;
            case UserlandBootstrapState.STATE_READY_UPGRADE_NEEDED:
                return R.string.product_bootstrap_title_upgrade;
            case UserlandBootstrapState.STATE_MISSING_SHELL:
            case UserlandBootstrapState.STATE_STAMP_NO_BASH:
                return R.string.product_bootstrap_title_shell_missing;
            case UserlandBootstrapState.STATE_MISSING_STAMP:
            default:
                return R.string.product_bootstrap_title_missing;
        }
    }

    private CharSequence productBootstrapDetail(UserlandBootstrapState state, UserlandInstallState installState, boolean rendererMissing) {
        if (installState.isInstalling()) {
            return installState.detail;
        }
        if (installState.isFailed()) {
            return getString(R.string.product_bootstrap_detail_install_failed, installState.detail);
        }
        if (rendererMissing) {
            return getText(R.string.product_bootstrap_detail_renderer_missing);
        }
        switch (state.state) {
            case UserlandBootstrapState.STATE_INVALID_STAMP:
                return getText(R.string.product_bootstrap_detail_invalid);
            case UserlandBootstrapState.STATE_READY_UPGRADE_NEEDED:
                return getText(R.string.product_bootstrap_detail_upgrade);
            case UserlandBootstrapState.STATE_MISSING_SHELL:
            case UserlandBootstrapState.STATE_STAMP_NO_BASH:
                return getText(R.string.product_bootstrap_detail_shell_missing);
            case UserlandBootstrapState.STATE_MISSING_STAMP:
            default:
                return getText(R.string.product_bootstrap_detail_missing);
        }
    }

    private int productBootstrapActionLabel(UserlandBootstrapState state, UserlandInstallState installState) {
        if (installState.isInstalling()) {
            return R.string.product_bootstrap_installing;
        }
        if (shouldStartInstall(state)) {
            return UserlandBootstrapState.STATE_READY_UPGRADE_NEEDED.equals(state.state)
                    ? R.string.product_bootstrap_update
                    : R.string.product_bootstrap_install;
        }
        return R.string.product_bootstrap_retry;
    }

    private boolean shouldStartInstall(UserlandBootstrapState state) {
        return UserlandBootstrapState.STATE_MISSING_STAMP.equals(state.state)
                || UserlandBootstrapState.STATE_INVALID_STAMP.equals(state.state)
                || UserlandBootstrapState.STATE_MISSING_SHELL.equals(state.state)
                || UserlandBootstrapState.STATE_STAMP_NO_BASH.equals(state.state)
                || UserlandBootstrapState.STATE_READY_UPGRADE_NEEDED.equals(state.state);
    }

    private void startUserlandInstall() {
        currentInstallState = UserlandInstallState.installing("Fetching and staging " + userlandRelease.artifactName + "...");
        updateProductShellVisibility();
        reevaluateProductFrameLoop();
        updateStatus("userland-install-started");
        appendEvent("userland.install begin expected=" + userlandRelease.artifactVersion);
        new Thread(() -> {
            try {
                final UserlandInstaller.Result result = UserlandInstaller.install(this, userlandRelease);
                handler.post(() -> {
                    currentInstallState = UserlandInstallState.idle();
                    currentBootstrapState = result.bootstrapState;
                    appendEvent("userland.install success " + result.detail);
                    final int restartStatus = nativeLoaded ? nativeRestartShellSessionBridge() : 0;
                    appendEvent("userland.install shellRestart status=" + shellStartStatusLabel(restartStatus));
                    refreshDebugShellState(true);
                    updateStatus("userland-install-succeeded-restarted", result.bootstrapState);
                });
            } catch (IOException err) {
                handler.post(() -> {
                    currentInstallState = UserlandInstallState.failed(err.getMessage() == null ? "unknown install failure" : err.getMessage());
                    appendEvent("userland.install failed err=" + err.getClass().getSimpleName() + " detail=" + currentInstallState.detail);
                    updateProductShellVisibility();
                    reevaluateProductFrameLoop();
                    updateStatus("userland-install-failed");
                });
            }
        }, "userland-install").start();
    }

    private void runPackageDoctor() {
        packageStatusText.setText("Running zide-pm...");
        appendEvent("packages.doctor begin");
        debugViewEnabled = true;
        applyViewMode();
        refreshDebugShellState(false);
        updateStatus("packages-doctor");
        new Thread(() -> {
            try {
                final String doctor = runUserlandCommand("zide-pm-doctor", "doctor", "--prefix", UserlandPolicy.prefixPath(this));
                final String available = runUserlandCommand("zide-pm-list", "list-available", "--prefix", UserlandPolicy.prefixPath(this));
                final String combined = doctor.trim() + "\n---\n" + available.trim();
                handler.post(() -> {
                    packageStatusText.setText(combined);
                    appendEvent("packages.doctor success");
                    updateStatus("packages-doctor");
                });
            } catch (IOException err) {
                handler.post(() -> {
                    final String detail = err.getMessage() == null ? err.getClass().getSimpleName() : err.getMessage();
                    packageStatusText.setText("zide-pm failed: " + detail);
                    appendEvent("packages.doctor failed err=" + err.getClass().getSimpleName());
                    updateStatus("packages-doctor-failed");
                });
            }
        }, "packages-doctor").start();
    }

    private String runUserlandCommand(String processName, String... args) throws IOException {
        final String binaryPath = UserlandPolicy.prefixPath(this) + "/bin/zide-pm";
        final ProcessBuilder builder = new ProcessBuilder();
        final java.util.ArrayList<String> command = new java.util.ArrayList<>();
        command.add(binaryPath);
        for (String arg : args) {
            command.add(arg);
        }
        builder.command(command);
        builder.directory(getFilesDir());
        builder.redirectErrorStream(true);
        final Map<String, String> env = builder.environment();
        env.put("PREFIX", UserlandPolicy.prefixPath(this));
        env.put("HOME", new File(getFilesDir(), "home").getAbsolutePath());
        env.put("TMPDIR", new File(getFilesDir().getParentFile(), "tmp").getAbsolutePath());
        env.put("PATH", UserlandPolicy.prefixPath(this) + "/bin:/system/bin");
        env.put("SHELL", UserlandPolicy.shellPath(this));
        env.put("LD_LIBRARY_PATH", UserlandPolicy.prefixPath(this) + "/lib");
        final Process process = builder.start();
        final String output;
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
            final StringBuilder out = new StringBuilder();
            String line;
            boolean first = true;
            while ((line = reader.readLine()) != null) {
                if (!first) {
                    out.append('\n');
                }
                out.append(line);
                first = false;
            }
            output = out.toString();
        }
        final int exitCode;
        try {
            exitCode = process.waitFor();
        } catch (InterruptedException err) {
            Thread.currentThread().interrupt();
            throw new IOException("interrupted while running " + processName, err);
        }
        if (exitCode != 0) {
            throw new IOException(processName + " exit=" + exitCode + " output=" + output);
        }
        return output;
    }

    private void callNative(String event, long seq) {
        appendEvent(event + " seq=" + seq);
    }

    private void callNativeWithSurfaceState(
            String event,
            long seq,
            AndroidDebugFormatter.SurfaceEventSnapshot state) {
        appendEvent(AndroidDebugFormatter.formatSurfaceEvent(
                event,
                new AndroidDebugFormatter.SurfaceEventSnapshot(
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

    private AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
        return new AndroidDebugFormatter.SurfaceEventSnapshot(
                0,
                nativeLoaded ? nativeCurrentWindowTokenBridge() : 0,
                nativeLoaded ? nativeCurrentSurfaceEpochBridge() : 0,
                surfaceTransitionLabel(nativeLoaded ? nativeCurrentSurfaceTransitionBridge() : 0),
                glesRendererStatusLabel(nativeLoaded ? nativeCurrentRendererStatusBridge() : 0),
                nativeLoaded ? nativeCurrentRendererSwapCountBridge() : 0,
                nativeLoaded ? nativeCurrentRendererBoundEpochBridge() : 0,
                nativeLoaded ? nativeCurrentRendererContextCreateCountBridge() : 0,
                nativeLoaded ? nativeCurrentRendererSurfaceCreateCountBridge() : 0,
                nativeLoaded ? nativeCurrentRendererTextureCreateCountBridge() : 0,
                nativeLoaded && nativeCurrentRendererTextureAliveBridge(),
                nativeLoaded ? nativeCurrentRendererTextureUploadCountBridge() : 0,
                nativeLoaded ? nativeCurrentRendererTextureUpdateCountBridge() : 0,
                nativeLoaded ? nativeCurrentRendererTextureResizeCountBridge() : 0,
                nativeLoaded ? nativeCurrentRendererTextureWidthBridge() : 0,
                nativeLoaded ? nativeCurrentRendererTextureHeightBridge() : 0);
    }

    private void updateStatus(String state) {
        updateStatus(state, currentBootstrapState);
    }

    private void updateStatus(String state, UserlandBootstrapState bootstrapState) {
        if (!shouldUpdateDebugStatus()) {
            return;
        }
        final AndroidDebugFormatter.SurfaceEventSnapshot surfaceState = currentSurfaceStateSnapshot();
        statusText.setText(AndroidDebugFormatter.formatStatus(
                new AndroidDebugFormatter.StatusSnapshot(
                        state,
                        nativeLoaded,
                        hasWindowFocus(),
                        imeVisible,
                        surfaceView.getHolder().getSurface().isValid(),
                        surfaceView.getWidth(),
                        surfaceView.getHeight(),
                        visibleViewportWidth,
                        visibleViewportHeight,
                        currentInstallState.status,
                        currentInstallState.detail,
                        bootstrapState.state,
                        bootstrapState.format,
                        bootstrapState.artifact,
                        bootstrapState.version,
                        bootstrapState.provider,
                        bootstrapState.launchReady,
                        bootstrapState.expectedCurrent,
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
    }

    private static String surfaceTransitionLabel(int transition) {
        switch (transition) {
            case 1:
                return "acquired";
            case 2:
                return "replaced";
            case 3:
                return "retired";
            default:
                return "unchanged";
        }
    }

    private static String shellStartStatusLabel(int status) {
        switch (status) {
            case 1:
                return "started";
            case 2:
                return "unsupported";
            case 3:
                return "create-failed";
            case 4:
                return "resize-failed";
            case 5:
                return "start-failed";
            case 6:
                return "send-failed";
            case 7:
                return "poll-failed";
            case 8:
                return "snapshot-failed";
            default:
                return "none";
        }
    }

    private static String glesRendererStatusLabel(int status) {
        switch (status) {
            case 1:
                return "ready";
            case 2:
                return "drawn";
            case 3:
                return "surface-destroyed";
            case 4:
                return "init-failed";
            case 5:
                return "surface-failed";
            case 6:
                return "make-current-failed";
            case 7:
                return "swap-failed";
            default:
                return "unavailable";
        }
    }

    private final class EdgeSwipeListener implements View.OnTouchListener {
        private static final float OPEN_THRESHOLD_PX = 48f;
        private final boolean openListener;
        private float downX;

        EdgeSwipeListener(boolean openListener) {
            this.openListener = openListener;
        }

        @Override
        public boolean onTouch(View view, MotionEvent event) {
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    downX = event.getRawX();
                    return true;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    final float delta = event.getRawX() - downX;
                    if (openListener) {
                        if (delta > OPEN_THRESHOLD_PX) {
                            openSidebar();
                            return true;
                        }
                    } else if (delta < -OPEN_THRESHOLD_PX) {
                        closeSidebar();
                        return true;
                    }
                    return openListener;
                default:
                    return openListener;
            }
        }
    }

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

    private static boolean shouldHandleHardwareKeyboardEvent(KeyEvent event) {
        if ((event.getSource() & InputDevice.SOURCE_KEYBOARD) == 0) {
            return false;
        }
        switch (event.getKeyCode()) {
            case KeyEvent.KEYCODE_VOLUME_DOWN:
            case KeyEvent.KEYCODE_VOLUME_UP:
            case KeyEvent.KEYCODE_VOLUME_MUTE:
            case KeyEvent.KEYCODE_BACK:
            case KeyEvent.KEYCODE_HOME:
            case KeyEvent.KEYCODE_APP_SWITCH:
            case KeyEvent.KEYCODE_POWER:
                return false;
            default:
                return true;
        }
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

    private static native long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible);

    private static native int nativeApplyTerminalPinchZoomBridge(float scaleFactor);

    private static native int nativeSetTerminalPinchActiveBridge(boolean active);

    private static native long nativeCurrentWindowTokenBridge();

    private static native long nativeCurrentSurfaceEpochBridge();

    private static native int nativeCurrentSurfaceTransitionBridge();

    private static native int nativeCurrentRendererStatusBridge();

    private static native long nativeCurrentRendererSwapCountBridge();

    private static native long nativeCurrentRendererBoundEpochBridge();

    private static native long nativeCurrentRendererContextCreateCountBridge();

    private static native long nativeCurrentRendererSurfaceCreateCountBridge();

    private static native long nativeCurrentRendererTextureCreateCountBridge();

    private static native boolean nativeCurrentRendererTextureAliveBridge();

    private static native long nativeCurrentRendererTextureUploadCountBridge();

    private static native long nativeCurrentRendererTextureUpdateCountBridge();

    private static native long nativeCurrentRendererTextureResizeCountBridge();

    private static native int nativeCurrentRendererTextureWidthBridge();

    private static native int nativeCurrentRendererTextureHeightBridge();

    private static native int nativeRestartShellSessionBridge();

    private static native int nativePollShellSessionBridge();

    private static native boolean nativeIsShellSessionAliveBridge();

    private static native int nativeTickProductShellFrameBridge();

    private static native int nativeSendShellCodepointBridge(int codepoint);

    private static native boolean nativeSharedShellRendererActiveBridge();
}
