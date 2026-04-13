package dev.zide.terminal;

import dev.zide.terminal.debug.AndroidDebugFormatter;
import dev.zide.terminal.gesture.ProductGestureController;
import dev.zide.terminal.input.ShellInputView;
import dev.zide.terminal.selection.TerminalSelectionController;
import dev.zide.terminal.session.ShellSessionController;
import dev.zide.terminal.scroll.TerminalScrollOverlayView;
import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandInstallState;
import dev.zide.terminal.userland.UserlandPolicy;
import dev.zide.terminal.userland.UserlandRelease;
import dev.zide.terminal.userland.UserlandBootstrapUiPolicy;
import dev.zide.terminal.userland.UserlandWorkflowController;
import dev.zide.terminal.userland.UserlandSessionCoordinator;
import dev.zide.terminal.userland.ProductFrameLoopController;
import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.host.TerminalSurfaceHostController;
import dev.zide.terminal.host.TerminalChromeController;
import dev.zide.terminal.host.TerminalRuntimeAssetsController;
import dev.zide.terminal.host.TerminalViewportController;
import dev.zide.terminal.debug.TerminalStatusController;
import android.app.Activity;
import android.content.Intent;
import android.widget.OverScroller;
import android.view.Surface;
import android.view.Gravity;
import android.os.Bundle;
import android.os.Handler;
import android.os.SystemClock;
import android.os.Looper;
import android.util.Log;
import android.view.Choreographer;
import android.view.InputDevice;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.KeyEvent;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;

public final class ZideTerminalActivity extends Activity
        implements SurfaceHolder.Callback2,
        ShellInputView.Host,
        ProductGestureController.Host,
        TerminalScrollOverlayView.Host {
    private static final String TAG = "ZideAndroidTerminal";
    private static final String EXTRA_DEBUG_RECREATE_SURFACE_ONCE = "debug_recreate_surface_once";
    private static final String EXTRA_DEBUG_RESIZE_SURFACE_ONCE = "debug_resize_surface_once";
    private static final String EXTRA_DEBUG_START_SHELL_ONCE = "debug_start_shell_once";
    private static final float MIN_PENDING_PINCH_APPLY_DELTA = 0.008f;
    /**
     * Product pinch budget for native zoom work.
     *
     * <p>
     * Pinch is much more sensitive than shortcut zoom. The host therefore coalesces
     * pinch intent
     * and applies at most one native zoom update per interval instead of trying to
     * honor every raw
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

    private final Handler handler = new Handler(Looper.getMainLooper());
    private TextView packageStatusText;
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
    private FrameLayout productSurfaceContainer;
    private TerminalScrollOverlayView terminalScrollOverlay;
    private Button assistCtrlButton;
    private Button assistAltButton;
    private ShellInputView shellInputView;
    private ProductGestureController productGestureController;
    private TerminalSelectionController selectionController;
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
    private boolean sidebarOpen = false;
    private UserlandRelease userlandRelease;
    private UserlandWorkflowController userlandWorkflowController;
    private UserlandSessionCoordinator userlandSessionCoordinator;
    private ProductFrameLoopController productFrameLoopController;
    private ProductShellStatePresenter productShellStatePresenter;
    private TerminalSurfaceHostController surfaceHostController;
    private TerminalChromeController terminalChromeController;
    private TerminalRuntimeAssetsController terminalRuntimeAssetsController;
    private TerminalViewportController terminalViewportController;
    private TerminalStatusController terminalStatusController;
    private UserlandInstallState currentInstallState = UserlandInstallState.idle();
    private UserlandBootstrapState currentBootstrapState;
    private int surfaceHostGeneration = 0;
    private int visibleViewportWidth = 0;
    private int visibleViewportHeight = 0;
    private int notifiedViewportWidth = 0;
    private int notifiedViewportHeight = 0;
    private boolean notifiedViewportImeVisible = false;
    private int activeGestureVisibleRows = 0;
    private int activeGestureVisibleCols = 0;
    private int activeGestureScrollbackCount = 0;
    private int activeGestureScrollbackOffset = 0;
    private float activeGestureScrollRemainderRows = 0.0f;
    private int flingLastScrollY = 0;
    private boolean flingScrollScheduled = false;
    private OverScroller scrollbackFlingScroller;
    private final Runnable productFrameRunnable = new Runnable() {
        @Override
        public void run() {
            if (productFrameLoopController == null || !productFrameLoopController.isActive()) {
                return;
            }
            final int tick = nativeLoaded ? nativeTickProductShellFrameBridge() : 0;
            refreshProductScrollOverlay();
            if (!shouldRunProductFrameLoop() || tick == 0) {
                productFrameLoopController.stop();
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
    private final Runnable scrollbackFlingRunnable = new Runnable() {
        @Override
        public void run() {
            flingScrollScheduled = false;
            if (scrollbackFlingScroller == null) {
                return;
            }
            if (!scrollbackFlingScroller.computeScrollOffset()) {
                return;
            }
            final int currentY = scrollbackFlingScroller.getCurrY();
            final float deltaY = currentY - flingLastScrollY;
            flingLastScrollY = currentY;
            applyProductScrollDelta(deltaY);
            if (!scrollbackFlingScroller.isFinished()) {
                scheduleScrollbackFlingFrame();
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        final TextView statusText = findViewById(R.id.status_text);
        packageStatusText = findViewById(R.id.package_status_text);
        final TextView eventLogText = findViewById(R.id.event_log);
        terminalStatusController = new TerminalStatusController(statusText, eventLogText, new TerminalStatusController.Host() {
            @Override
            public boolean debugViewEnabled() {
                return debugViewEnabled;
            }

            @Override
            public boolean nativeLoaded() {
                return nativeLoaded;
            }

            @Override
            public boolean hasWindowFocus() {
                return hasWindowFocus();
            }

            @Override
            public boolean imeVisible() {
                return imeVisible;
            }

            @Override
            public SurfaceView surfaceView() {
                return surfaceView;
            }

            @Override
            public int visibleViewportWidth() {
                return visibleViewportWidth;
            }

            @Override
            public int visibleViewportHeight() {
                return visibleViewportHeight;
            }

            @Override
            public UserlandInstallState installState() {
                return currentInstallState;
            }

            @Override
            public UserlandBootstrapState bootstrapState() {
                return currentBootstrapState;
            }

            @Override
            public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
                return ZideTerminalActivity.this.currentSurfaceStateSnapshot();
            }
        });
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
        productSurfaceContainer = findViewById(R.id.product_surface_container);
        terminalScrollOverlay = findViewById(R.id.terminal_scroll_overlay);
        terminalViewportController = new TerminalViewportController(new TerminalViewportController.Host() {
            @Override
            public View productView() {
                return productView;
            }

            @Override
            public FrameLayout productSurfaceContainer() {
                return productSurfaceContainer;
            }

            @Override
            public boolean imeVisible() {
                return imeVisible;
            }

            @Override
            public void setImeVisible(boolean imeVisible) {
                ZideTerminalActivity.this.imeVisible = imeVisible;
            }

            @Override
            public void notifyVisibleViewport(String reason) {
                ZideTerminalActivity.this.notifyVisibleViewport(reason);
            }
        });
        selectionController = new TerminalSelectionController(
                new TerminalSelectionController.Host() {
                    @Override
                    public android.content.Context context() {
                        return ZideTerminalActivity.this;
                    }

                    @Override
                    public FrameLayout productSurfaceContainer() {
                        return productSurfaceContainer;
                    }

                    @Override
                    public int productViewportWidthPx() {
                        return ZideTerminalActivity.this.productViewportWidthPx();
                    }

                    @Override
                    public int productViewportHeightPx() {
                        return ZideTerminalActivity.this.productViewportHeightPx();
                    }

                    @Override
                    public void stopScrollbackFling() {
                        ZideTerminalActivity.this.stopScrollbackFling();
                    }

                    @Override
                    public void refreshProductScrollOverlay() {
                        ZideTerminalActivity.this.refreshProductScrollOverlay();
                    }

                    @Override
                    public void reevaluateProductFrameLoop() {
                        if (productFrameLoopController != null) {
                            productFrameLoopController.reevaluate();
                        }
                    }

                    @Override
                    public void appendEvent(String event) {
                        ZideTerminalActivity.this.appendEvent(event);
                    }
                },
                new TerminalSelectionController.Bridge() {
                    @Override
                    public boolean nativeLoaded() {
                        return ZideTerminalActivity.nativeLoaded;
                    }

                    @Override
                    public int beginWordSelectionAtVisibleCell(int row, int col) {
                        return nativeBeginShellWordSelectionAtVisibleCellBridge(row, col);
                    }

                    @Override
                    public int extendSelectionGestureToVisibleCell(int row, int col) {
                        return nativeExtendShellSelectionGestureToVisibleCellBridge(row, col);
                    }

                    @Override
                    public int finishSelectionGesture() {
                        return nativeFinishShellSelectionGestureBridge();
                    }

                    @Override
                    public int clearSelection() {
                        return nativeClearShellSelectionBridge();
                    }

                    @Override
                    public int updateSelectionStartAtVisibleCell(int row, int col) {
                        return nativeUpdateShellSelectionStartAtVisibleCellBridge(row, col);
                    }

                    @Override
                    public int updateSelectionEndAtVisibleCell(int row, int col) {
                        return nativeUpdateShellSelectionEndAtVisibleCellBridge(row, col);
                    }

                    @Override
                    public boolean currentSelectionActive() {
                        return nativeCurrentShellSelectionActiveBridge();
                    }

                    @Override
                    public int currentSelectionRectLeft() {
                        return nativeCurrentShellSelectionRectLeftBridge();
                    }

                    @Override
                    public int currentSelectionRectTop() {
                        return nativeCurrentShellSelectionRectTopBridge();
                    }

                    @Override
                    public int currentSelectionRectRight() {
                        return nativeCurrentShellSelectionRectRightBridge();
                    }

                    @Override
                    public int currentSelectionRectBottom() {
                        return nativeCurrentShellSelectionRectBottomBridge();
                    }

                    @Override
                    public int currentSelectionStartRectLeft() {
                        return nativeCurrentShellSelectionStartRectLeftBridge();
                    }

                    @Override
                    public int currentSelectionStartRectTop() {
                        return nativeCurrentShellSelectionStartRectTopBridge();
                    }

                    @Override
                    public int currentSelectionStartRectRight() {
                        return nativeCurrentShellSelectionStartRectRightBridge();
                    }

                    @Override
                    public int currentSelectionStartRectBottom() {
                        return nativeCurrentShellSelectionStartRectBottomBridge();
                    }

                    @Override
                    public int currentSelectionEndRectLeft() {
                        return nativeCurrentShellSelectionEndRectLeftBridge();
                    }

                    @Override
                    public int currentSelectionEndRectTop() {
                        return nativeCurrentShellSelectionEndRectTopBridge();
                    }

                    @Override
                    public int currentSelectionEndRectRight() {
                        return nativeCurrentShellSelectionEndRectRightBridge();
                    }

                    @Override
                    public int currentSelectionEndRectBottom() {
                        return nativeCurrentShellSelectionEndRectBottomBridge();
                    }

                    @Override
                    public byte[] currentSelectionTextBytes() {
                        return nativeCurrentShellSelectionTextBytesBridge();
                    }

                    @Override
                    public int currentVisibleRows() {
                        return nativeCurrentShellVisibleRowsBridge();
                    }

                    @Override
                    public int currentVisibleCols() {
                        return nativeCurrentShellVisibleColsBridge();
                    }

                    @Override
                    public int currentScrollbackCount() {
                        return nativeCurrentShellScrollbackCountBridge();
                    }

                    @Override
                    public int currentScrollbackOffset() {
                        return nativeCurrentShellScrollbackOffsetBridge();
                    }

                    @Override
                    public int setShellScrollbackOffset(int offsetRows) {
                        return nativeSetShellScrollbackOffsetBridge(offsetRows);
                    }

                    @Override
                    public int followShellLiveBottom() {
                        return nativeFollowShellLiveBottomBridge();
                    }
                });
        selectionController.install();
        assistCtrlButton = findViewById(R.id.assist_ctrl_button);
        assistAltButton = findViewById(R.id.assist_alt_button);
        terminalScrollOverlay.setHost(this);
        scrollbackFlingScroller = new OverScroller(this);
        terminalRuntimeAssetsController = new TerminalRuntimeAssetsController(
                new TerminalRuntimeAssetsController.Host() {
                    @Override
                    public android.content.Context context() {
                        return ZideTerminalActivity.this;
                    }

                    @Override
                    public void appendEvent(String event) {
                        ZideTerminalActivity.this.appendEvent(event);
                    }
                });
        userlandRelease = terminalRuntimeAssetsController.loadUserlandRelease();
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
        userlandSessionCoordinator = new UserlandSessionCoordinator(
                shellSessionController,
                new UserlandSessionCoordinator.Host() {
                    @Override
                    public void appendEvent(String event) {
                        ZideTerminalActivity.this.appendEvent(event);
                    }

                    @Override
                    public String shellStartStatusLabel(int status) {
                        return ZideTerminalActivity.shellStartStatusLabel(status);
                    }

                    @Override
                    public void applyBootstrapState(UserlandBootstrapState bootstrapState) {
                        currentBootstrapState = bootstrapState;
                    }

                    @Override
                    public void refreshProductShellState() {
                        ZideTerminalActivity.this.refreshProductShellState();
                    }

                    @Override
                    public void refreshDebugStatusSurface() {
                        ZideTerminalActivity.this.refreshDebugStatusSurface();
                    }

                    @Override
                    public void updateStatus(String statusLabel) {
                        ZideTerminalActivity.this.updateStatus(statusLabel);
                    }
                });
        productFrameLoopController = new ProductFrameLoopController(
                handler,
                productFrameRunnable,
                new ProductFrameLoopController.Host() {
                    @Override
                    public boolean shouldRunProductFrameLoop() {
                        return ZideTerminalActivity.this.shouldRunProductFrameLoop();
                    }

                    @Override
                    public void refreshProductScrollOverlay() {
                        ZideTerminalActivity.this.refreshProductScrollOverlay();
                    }
                });
        userlandWorkflowController = new UserlandWorkflowController(
                new UserlandWorkflowController.Host() {
                    @Override
                    public android.content.Context context() {
                        return ZideTerminalActivity.this;
                    }

                    @Override
                    public Handler handler() {
                        return ZideTerminalActivity.this.handler;
                    }

                    @Override
                    public UserlandRelease release() {
                        return userlandRelease;
                    }

                    @Override
                    public void appendEvent(String event) {
                        ZideTerminalActivity.this.appendEvent(event);
                    }

                    @Override
                    public void applyInstallState(UserlandInstallState installState, String statusLabel) {
                        ZideTerminalActivity.this.applyInstallState(installState, statusLabel);
                    }

                    @Override
                    public void setInstallState(UserlandInstallState installState) {
                        currentInstallState = installState;
                    }

                    @Override
                    public void setBootstrapState(UserlandBootstrapState bootstrapState) {
                        currentBootstrapState = bootstrapState;
                    }

                    @Override
                    public void restartShellSession(String eventName, String statusLabel, boolean logRefresh) {
                        ZideTerminalActivity.this.restartShellSession(eventName, statusLabel, logRefresh);
                    }

                    @Override
                    public void showDebugView(String eventName, String statusLabel) {
                        ZideTerminalActivity.this.showDebugView(eventName, statusLabel);
                    }

                    @Override
                    public void setPackageStatusText(String text) {
                        packageStatusText.setText(text);
                    }

                    @Override
                    public void updateStatus(String statusLabel) {
                        ZideTerminalActivity.this.updateStatus(statusLabel);
                    }
                });
        productShellStatePresenter = new ProductShellStatePresenter(
                new ProductShellStatePresenter.Host() {
                    @Override
                    public boolean nativeLoaded() {
                        return nativeLoaded;
                    }

                    @Override
                    public boolean sharedShellRendererActive() {
                        return nativeSharedShellRendererActiveBridge();
                    }

                    @Override
                    public boolean installInstalling() {
                        return currentInstallState.isInstalling();
                    }

                    @Override
                    public boolean installFailed() {
                        return currentInstallState.isFailed();
                    }

                    @Override
                    public UserlandBootstrapState bootstrapState() {
                        return currentBootstrapState;
                    }

                    @Override
                    public UserlandInstallState installState() {
                        return currentInstallState;
                    }

                    @Override
                    public SurfaceView surfaceView() {
                        return surfaceView;
                    }

                    @Override
                    public View productBootstrapBlocker() {
                        return productBootstrapBlocker;
                    }

                    @Override
                    public TextView productBootstrapTitle() {
                        return productBootstrapTitle;
                    }

                    @Override
                    public TextView productBootstrapDetail() {
                        return productBootstrapDetail;
                    }

                    @Override
                    public Button productBootstrapRetryButton() {
                        return productBootstrapRetryButton;
                    }

                    @Override
                    public void showScrollOverlay(boolean visible) {
                        terminalScrollOverlay.setVisibility(visible ? View.VISIBLE : View.GONE);
                    }
                });
        terminalChromeController = new TerminalChromeController(
                new TerminalChromeController.Host() {
                    @Override
                    public View debugViewModeButton() {
                        return findViewById(R.id.debug_view_mode_button);
                    }

                    @Override
                    public View drawerScrim() {
                        return drawerScrim;
                    }

                    @Override
                    public View drawerEdgeHotspot() {
                        return drawerEdgeHotspot;
                    }

                    @Override
                    public View leftSidebar() {
                        return leftSidebar;
                    }

                    @Override
                    public boolean sidebarOpen() {
                        return sidebarOpen;
                    }

                    @Override
                    public void setSidebarOpen(boolean open) {
                        sidebarOpen = open;
                    }

                    @Override
                    public boolean debugViewEnabled() {
                        return debugViewEnabled;
                    }

                    @Override
                    public void showProductView(String eventName, String statusLabel) {
                        ZideTerminalActivity.this.showProductView(eventName, statusLabel);
                    }

                    @Override
                    public void showDebugView(String eventName, String statusLabel) {
                        ZideTerminalActivity.this.showDebugView(eventName, statusLabel);
                    }

                    @Override
                    public void closeSidebar() {
                        ZideTerminalActivity.this.closeSidebar();
                    }

                    @Override
                    public void updateSidebarVisibility(boolean visible) {
                        ZideTerminalActivity.this.updateSidebarVisibility(visible);
                    }

                    @Override
                    public void runPackageDoctor() {
                        ZideTerminalActivity.this.runPackageDoctor();
                    }

                    @Override
                    public void appendEvent(String event) {
                        ZideTerminalActivity.this.appendEvent(event);
                    }

                    @Override
                    public void toggleIme() {
                        ZideTerminalActivity.this.toggleIme();
                    }

                    @Override
                    public void applyModifierLatchState(ShellInputView.Host.ModifierLatchState state) {
                        ZideTerminalActivity.this.applyModifierLatchState(state);
                    }

                    @Override
                    public ShellInputView shellInputView() {
                        return shellInputView;
                    }

                    @Override
                    public Button assistCtrlButton() {
                        return assistCtrlButton;
                    }

                    @Override
                    public Button assistAltButton() {
                        return assistAltButton;
                    }

                    @Override
                    public void sendDirectText(String text) {
                        ZideTerminalActivity.this.sendDirectText(text);
                    }

                    @Override
                    public void bindAssistButton(int id, String text, String eventName) {
                        ZideTerminalActivity.this.bindAssistButton(id, text, eventName);
                    }

                    @Override
                    public void bindModifierAssistButton(Button button, ShellInputView.ModifierLatch modifier, String eventName) {
                        ZideTerminalActivity.this.bindModifierAssistButton(button, modifier, eventName);
                    }

                    @Override
                    public void updateStatus(String statusLabel) {
                        ZideTerminalActivity.this.updateStatus(statusLabel);
                    }
                });
        surfaceHostController = new TerminalSurfaceHostController(
                new TerminalSurfaceHostController.Host() {
                    @Override
                    public Handler handler() {
                        return ZideTerminalActivity.this.handler;
                    }

                    @Override
                    public boolean nativeLoaded() {
                        return nativeLoaded;
                    }

                    @Override
                    public boolean debugViewEnabled() {
                        return debugViewEnabled;
                    }

                    @Override
                    public FrameLayout productSurfaceContainer() {
                        return productSurfaceContainer;
                    }

                    @Override
                    public SurfaceView surfaceView() {
                        return surfaceView;
                    }

                    @Override
                    public void setSurfaceView(SurfaceView surfaceView) {
                        ZideTerminalActivity.this.surfaceView = surfaceView;
                    }

                    @Override
                    public int surfaceHostGeneration() {
                        return surfaceHostGeneration;
                    }

                    @Override
                    public void setSurfaceHostGeneration(int generation) {
                        surfaceHostGeneration = generation;
                    }

                    @Override
                    public boolean surfaceRecreationScheduled() {
                        return surfaceRecreationScheduled;
                    }

                    @Override
                    public void setSurfaceRecreationScheduled(boolean scheduled) {
                        surfaceRecreationScheduled = scheduled;
                    }

                    @Override
                    public boolean surfaceResizeScheduled() {
                        return surfaceResizeScheduled;
                    }

                    @Override
                    public void setSurfaceResizeScheduled(boolean scheduled) {
                        surfaceResizeScheduled = scheduled;
                    }

                    @Override
                    public boolean shellStartScheduled() {
                        return shellStartScheduled;
                    }

                    @Override
                    public void setShellStartScheduled(boolean scheduled) {
                        shellStartScheduled = scheduled;
                    }

                    @Override
                    public int visibleViewportWidth() {
                        return visibleViewportWidth;
                    }

                    @Override
                    public int visibleViewportHeight() {
                        return visibleViewportHeight;
                    }

                    @Override
                    public void setVisibleViewportSize(int width, int height) {
                        visibleViewportWidth = width;
                        visibleViewportHeight = height;
                    }

                    @Override
                    public int notifiedViewportWidth() {
                        return notifiedViewportWidth;
                    }

                    @Override
                    public int notifiedViewportHeight() {
                        return notifiedViewportHeight;
                    }

                    @Override
                    public boolean notifiedViewportImeVisible() {
                        return notifiedViewportImeVisible;
                    }

                    @Override
                    public void setNotifiedViewportSize(int width, int height, boolean imeVisible) {
                        notifiedViewportWidth = width;
                        notifiedViewportHeight = height;
                        notifiedViewportImeVisible = imeVisible;
                    }

                    @Override
                    public boolean currentImeVisible() {
                        return ZideTerminalActivity.this.currentImeVisible();
                    }

                    @Override
                    public boolean shouldRunProductFrameLoop() {
                        return ZideTerminalActivity.this.shouldRunProductFrameLoop();
                    }

                    @Override
                    public void refreshProductScrollOverlay() {
                        ZideTerminalActivity.this.refreshProductScrollOverlay();
                    }

                    @Override
                    public void appendEvent(String event) {
                        ZideTerminalActivity.this.appendEvent(event);
                    }

                    @Override
                    public void updateStatus(String statusLabel) {
                        ZideTerminalActivity.this.updateStatus(statusLabel);
                    }

                    @Override
                    public void callNative(String event, long seq) {
                        ZideTerminalActivity.this.callNative(event, seq);
                    }

                    @Override
                    public void callNativeWithSurfaceState(String event, long seq,
                            AndroidDebugFormatter.SurfaceEventSnapshot state) {
                        ZideTerminalActivity.this.callNativeWithSurfaceState(event, seq, state);
                    }

                    @Override
                    public long nativeOnSurfaceAvailableBridge(SurfaceHolder holder, int width, int height) {
                        return ZideTerminalActivity.nativeOnSurfaceAvailableBridge(holder.getSurface(), width, height);
                    }

                    @Override
                    public long nativeOnSurfaceDestroyedBridge() {
                        return ZideTerminalActivity.nativeOnSurfaceDestroyedBridge();
                    }

                    @Override
                    public long nativeOnSurfaceRedrawNeededBridge() {
                        return ZideTerminalActivity.nativeOnSurfaceRedrawNeededBridge();
                    }

                    @Override
                    public long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible) {
                        return ZideTerminalActivity.nativeOnVisibleViewportBridge(width, height, imeVisible);
                    }

                    @Override
                    public AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot() {
                        return ZideTerminalActivity.this.currentSurfaceStateSnapshot();
                    }

                    @Override
                    public void handleProductShellStateEvent(String statusLabel) {
                        ZideTerminalActivity.this.handleProductShellStateEvent(statusLabel);
                    }

                    @Override
                    public void installSurfaceGestureHost(SurfaceView nextSurfaceView) {
                        productGestureController = new ProductGestureController(nextSurfaceView,
                                ZideTerminalActivity.this);
                        productGestureController.install();
                    }

                    @Override
                    public void reinstallSurfaceCallback(SurfaceView nextSurfaceView,
                            SurfaceHolder.Callback2 callback) {
                        if (callback != null) {
                            nextSurfaceView.getHolder().addCallback(callback);
                        }
                    }

                    @Override
                    public SurfaceHolder.Callback2 surfaceCallback() {
                        return ZideTerminalActivity.this;
                    }
                });
        currentBootstrapState = userlandSessionCoordinator.loadBootstrapState();
        installShellInputView();
        installInsetsHandling();
        installViewportTracking();
        terminalChromeController.bindSidebarControls();
        terminalChromeController.bindViewModeToggle();
        bindProductBootstrapBlocker();
        terminalChromeController.bindAssistBar();
        terminalRuntimeAssetsController.prepareRuntimeAssets();
        terminalChromeController.applyViewMode(debugViewEnabled, productView, debugView, terminalScrollOverlay, productSurfaceContainer);
        surfaceHostController.installSurfaceView("activity-create", this);
        productShellStatePresenter.refresh();
        productFrameLoopController.reevaluate();
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
        terminalViewportController.installInsetsHandling();
    }

    private void installViewportTracking() {
        terminalViewportController.installViewportTracking();
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
        surfaceHostController.onResume(
                getIntent().getBooleanExtra(EXTRA_DEBUG_RECREATE_SURFACE_ONCE, false),
                getIntent().getBooleanExtra(EXTRA_DEBUG_RESIZE_SURFACE_ONCE, false),
                getIntent().getBooleanExtra(EXTRA_DEBUG_START_SHELL_ONCE, false));
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
        productFrameLoopController.stop();
        userlandSessionCoordinator.refreshAndApply(false);
        surfaceHostController.onPause();
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
                if (nativeLoaded) {
                    nativeFollowShellLiveBottomBridge();
                    refreshProductScrollOverlay();
                }
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
        surfaceHostController.onSurfaceCreated(holder);
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        surfaceHostController.onSurfaceChanged(holder, format, width, height);
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        surfaceHostController.onSurfaceDestroyed(holder);
    }

    @Override
    public void surfaceRedrawNeeded(SurfaceHolder holder) {
        surfaceHostController.onSurfaceRedrawNeeded(holder);
    }

    private void maybeScheduleSurfaceRecreation() {
        if (!getIntent().getBooleanExtra(EXTRA_DEBUG_RECREATE_SURFACE_ONCE, false)) {
            return;
        }
        surfaceHostController.installSurfaceView("debug-recreate", this);
    }

    private void maybeScheduleSurfaceResize() {
        final boolean resizeRequested = getIntent().getBooleanExtra(EXTRA_DEBUG_RESIZE_SURFACE_ONCE, false);
        appendEvent("debug.resizeSurface requested=" + resizeRequested + " scheduled=" + surfaceResizeScheduled);
        if (!resizeRequested) {
            return;
        }
        surfaceHostController.onResume(false, true, false);
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
            restartShellSession("debug.shellStart", "debug-shell-started", false);
            sendDirectText("printf 'android-shell-ok\\n'\n");
        }, 900);
    }

    private void bindViewModeToggle() {
        final Button debugViewModeButton = findViewById(R.id.debug_view_mode_button);
        debugViewModeButton.setOnClickListener(view -> showProductView("view.mode debug=false", "product-view"));
    }

    private void bindSidebarControls() {
        final Button restartButton = findViewById(R.id.sidebar_restart_button);
        final Button debugButton = findViewById(R.id.sidebar_debug_button);
        final Button packagesButton = findViewById(R.id.sidebar_packages_button);

        restartButton.setOnClickListener(view -> {
            restartShellSession("manual.shellRestart", "shell-restarted", false);
            closeSidebar();
        });

        debugButton.setOnClickListener(view -> {
            showDebugView("view.mode debug=true", "debug-view");
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
        final int imeButtonId = getResources().getIdentifier("assist_ime_button", "id", getPackageName());
        final Button imeButton = imeButtonId != 0 ? findViewById(imeButtonId) : null;
        if (imeButton != null) {
            imeButton.setOnClickListener(view -> {
                toggleIme();
                appendEvent("assist.ime");
            });
        }
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
            if (UserlandBootstrapUiPolicy.shouldStartInstall(currentBootstrapState)) {
                userlandWorkflowController.startInstall();
                return;
            }
            appendEvent("product.bootstrap retry");
            userlandSessionCoordinator.refreshAndApply(true);
            updateStatus("product-bootstrap-retry");
        });
        productBootstrapDebugButton.setOnClickListener(view -> showDebugView("product.bootstrap debug", "debug-view"));
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
    public void onProductSingleTap(float x, float y) {
        selectionController.onProductSingleTap(x, y);
    }

    @Override
    public void onProductScrollBegin() {
        if (!nativeLoaded) {
            return;
        }
        stopScrollbackFling();
        activeGestureVisibleRows = nativeCurrentShellVisibleRowsBridge();
        activeGestureVisibleCols = nativeCurrentShellVisibleColsBridge();
        activeGestureScrollbackCount = nativeCurrentShellScrollbackCountBridge();
        activeGestureScrollbackOffset = nativeCurrentShellScrollbackOffsetBridge();
        activeGestureScrollRemainderRows = 0.0f;
    }

    @Override
    public void onProductScrollBy(float deltaY) {
        applyProductScrollDelta(deltaY);
    }

    @Override
    public void onProductScrollEnd() {
        activeGestureVisibleRows = 0;
        activeGestureVisibleCols = 0;
        activeGestureScrollbackCount = 0;
        activeGestureScrollbackOffset = 0;
        activeGestureScrollRemainderRows = 0.0f;
    }

    @Override
    public void onProductScrollFling(float velocityY) {
        if (!nativeLoaded || scrollbackFlingScroller == null || productViewportHeightPx() <= 0) {
            return;
        }
        stopScrollbackFling();
        activeGestureVisibleRows = nativeCurrentShellVisibleRowsBridge();
        activeGestureVisibleCols = nativeCurrentShellVisibleColsBridge();
        activeGestureScrollbackCount = nativeCurrentShellScrollbackCountBridge();
        activeGestureScrollbackOffset = nativeCurrentShellScrollbackOffsetBridge();
        activeGestureScrollRemainderRows = 0.0f;
        flingLastScrollY = 0;
        scrollbackFlingScroller.fling(
                0,
                0,
                0,
                Math.round(velocityY),
                0,
                0,
                Integer.MIN_VALUE / 4,
                Integer.MAX_VALUE / 4);
        scheduleScrollbackFlingFrame();
    }

    @Override
    public void onProductLongPress(float x, float y) {
        selectionController.onProductLongPress(x, y);
    }

    @Override
    public void onProductSelectionDrag(float x, float y) {
        selectionController.onProductSelectionDrag(x, y);
    }

    @Override
    public void onProductSelectionDragEnd(float x, float y) {
        selectionController.onProductSelectionDragEnd(x, y);
    }

    @Override
    public void onScrollbackOffsetRequested(int offsetRows) {
        if (!nativeLoaded) {
            return;
        }
        final int status = nativeSetShellScrollbackOffsetBridge(offsetRows);
        appendEvent("product.scrollback offset=" + offsetRows + " status=" + status);
        refreshProductScrollOverlay();
        productFrameLoopController.reevaluate();
    }

    @Override
    public void onFollowLiveBottomRequested() {
        if (!nativeLoaded) {
            return;
        }
        final int status = nativeFollowShellLiveBottomBridge();
        appendEvent("product.scrollback followBottom status=" + status);
        refreshProductScrollOverlay();
        productFrameLoopController.reevaluate();
    }

    @Override
    public void onProductPinchBegin() {
        if (!nativeLoaded) {
            return;
        }
        stopScrollbackFling();
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

    private void applyProductScrollDelta(float deltaY) {
        final int viewportHeight = productViewportHeightPx();
        if (!nativeLoaded || activeGestureVisibleRows <= 0 || viewportHeight <= 0) {
            return;
        }
        final float rowHeightPx = (float) viewportHeight / (float) activeGestureVisibleRows;
        if (!(rowHeightPx > 0.0f)) {
            return;
        }
        activeGestureScrollRemainderRows += (deltaY / rowHeightPx);
        final int wholeRows = (int) activeGestureScrollRemainderRows;
        if (wholeRows == 0) {
            return;
        }
        activeGestureScrollRemainderRows -= wholeRows;
        final int nextOffset = Math.max(0,
                Math.min(activeGestureScrollbackOffset + wholeRows, activeGestureScrollbackCount));
        if (nextOffset == activeGestureScrollbackOffset) {
            return;
        }
        if (nextOffset == 0) {
            nativeFollowShellLiveBottomBridge();
        } else {
            nativeSetShellScrollbackOffsetBridge(nextOffset);
        }
        activeGestureScrollbackOffset = nextOffset;
        refreshProductScrollOverlay();
        if (productFrameLoopController != null) {
            productFrameLoopController.reevaluate();
        }
    }

    /**
     * Product terminal viewport authority.
     *
     * <p>
     * The SurfaceView, scroll overlay, gesture math, and native grid-fit path must
     * all describe
     * the same Android-owned rectangle. Do not use the broader content frame here;
     * it can acquire
     * non-terminal children and should not become the terminal size contract by
     * accident.
     */
    private int productViewportWidthPx() {
        return terminalViewportController.productViewportWidthPx();
    }

    private int productViewportHeightPx() {
        return terminalViewportController.productViewportHeightPx();
    }

    private void scheduleScrollbackFlingFrame() {
        if (flingScrollScheduled) {
            return;
        }
        flingScrollScheduled = true;
        Choreographer.getInstance().postFrameCallback(frameTimeNanos -> scrollbackFlingRunnable.run());
    }

    private void stopScrollbackFling() {
        if (scrollbackFlingScroller != null && !scrollbackFlingScroller.isFinished()) {
            scrollbackFlingScroller.forceFinished(true);
        }
        flingScrollScheduled = false;
        flingLastScrollY = 0;
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
            terminalScrollOverlay.setVisibility(View.GONE);
        } else {
            productSurfaceContainer.post(() -> surfaceHostController.notifyVisibleViewport("product-view"));
            productSurfaceContainer.post(this::refreshProductScrollOverlay);
        }
    }

    private void showProductView(String eventName, String statusLabel) {
        debugViewEnabled = false;
        appendEvent(eventName);
        applyViewMode();
        updateStatus(statusLabel);
    }

    private void showDebugView(String eventName, String statusLabel) {
        debugViewEnabled = true;
        appendEvent(eventName);
        applyViewMode();
            userlandSessionCoordinator.refreshAndApply(false);
        updateStatus(statusLabel);
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

    private void closeIme() {
        final InputMethodManager imm = getSystemService(InputMethodManager.class);
        if (imm == null) {
            appendEvent("manual.ime unavailable=true");
            return;
        }
        final boolean hidden = imm.hideSoftInputFromWindow(shellInputView.getWindowToken(), 0);
        imeVisible = false;
        appendEvent("manual.imeClose hidden=" + hidden);
        updateStatus("ime-hidden");
    }

    private void toggleIme() {
        if (currentImeVisible()) {
            closeIme();
            return;
        }
        openIme();
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

    private void refreshProductShellState() {
        productShellStatePresenter.refresh();
        refreshProductScrollOverlay();
        productFrameLoopController.reevaluate();
    }

    private void refreshDebugStatusSurface() {
        terminalStatusController.refreshDebugStatusSurface();
    }

    private void handleProductShellStateEvent(String statusLabel) {
        handler.post(() -> userlandSessionCoordinator.refreshAndApply(false));
        productFrameLoopController.reevaluate();
        updateStatus(statusLabel);
    }

    private void installSurfaceView(String reason) {
        surfaceHostController.installSurfaceView(reason, this);
    }

    private void notifyVisibleViewport(String reason) {
        surfaceHostController.notifyVisibleViewport(reason);
    }

    private boolean currentImeVisible() {
        return terminalViewportController.currentImeVisible();
    }

    private void refreshProductScrollOverlay() {
        if (terminalScrollOverlay == null) {
            return;
        }
        if (debugViewEnabled
                || !nativeLoaded
                || currentInstallState.isInstalling()
                || currentInstallState.isFailed()
                || !currentBootstrapState.launchReady
                || !currentBootstrapState.expectedCurrent
                || productBootstrapBlocker.getVisibility() == View.VISIBLE) {
            terminalScrollOverlay.updateScrollMetrics(0, 0, 0);
            return;
        }
        terminalScrollOverlay.updateScrollMetrics(
                nativeCurrentShellVisibleRowsBridge(),
                nativeCurrentShellScrollbackCountBridge(),
                nativeCurrentShellScrollbackOffsetBridge());
        if (selectionController != null) {
            selectionController.syncChrome();
        }
    }

    private void applyInstallState(UserlandInstallState installState, String statusLabel) {
        currentInstallState = installState;
        refreshProductShellState();
        updateStatus(statusLabel);
    }

    private void restartShellSession(String eventName, String statusLabel, boolean logRefresh) {
        final int status = nativeLoaded ? nativeRestartShellSessionBridge() : 0;
        appendEvent(eventName + " status=" + shellStartStatusLabel(status));
        userlandSessionCoordinator.refreshAndApply(logRefresh);
        updateStatus(statusLabel);
    }

    private void runPackageDoctor() {
        userlandWorkflowController.runPackageDoctor();
    }

    private void callNative(String event, long seq) {
        terminalStatusController.callNative(event, seq);
    }

    private void callNativeWithSurfaceState(
            String event,
            long seq,
            AndroidDebugFormatter.SurfaceEventSnapshot state) {
        terminalStatusController.callNativeWithSurfaceState(event, seq, state);
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
        terminalStatusController.updateStatus(state);
    }

    private void updateStatus(String state, UserlandBootstrapState bootstrapState) {
        terminalStatusController.updateStatus(state, bootstrapState);
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
        terminalStatusController.appendEvent(message);
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

    private static native int nativeCurrentShellVisibleRowsBridge();

    private static native int nativeCurrentShellVisibleColsBridge();

    private static native int nativeCurrentShellScrollbackCountBridge();

    private static native int nativeCurrentShellScrollbackOffsetBridge();

    private static native int nativeSetShellScrollbackOffsetBridge(int offsetRows);

    private static native int nativeFollowShellLiveBottomBridge();

    private static native int nativeBeginShellWordSelectionAtVisibleCellBridge(int row, int col);

    private static native int nativeExtendShellSelectionGestureToVisibleCellBridge(int row, int col);

    private static native int nativeFinishShellSelectionGestureBridge();

    private static native int nativeClearShellSelectionBridge();

    private static native int nativeUpdateShellSelectionStartAtVisibleCellBridge(int row, int col);

    private static native int nativeUpdateShellSelectionEndAtVisibleCellBridge(int row, int col);

    private static native boolean nativeCurrentShellSelectionActiveBridge();

    private static native int nativeCurrentShellSelectionRectLeftBridge();

    private static native int nativeCurrentShellSelectionRectTopBridge();

    private static native int nativeCurrentShellSelectionRectRightBridge();

    private static native int nativeCurrentShellSelectionRectBottomBridge();

    private static native int nativeCurrentShellSelectionStartRectLeftBridge();

    private static native int nativeCurrentShellSelectionStartRectTopBridge();

    private static native int nativeCurrentShellSelectionStartRectRightBridge();

    private static native int nativeCurrentShellSelectionStartRectBottomBridge();

    private static native int nativeCurrentShellSelectionEndRectLeftBridge();

    private static native int nativeCurrentShellSelectionEndRectTopBridge();

    private static native int nativeCurrentShellSelectionEndRectRightBridge();

    private static native int nativeCurrentShellSelectionEndRectBottomBridge();

    private static native byte[] nativeCurrentShellSelectionTextBytesBridge();

    private static native boolean nativeSharedShellRendererActiveBridge();
}
