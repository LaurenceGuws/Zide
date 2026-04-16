package uk.laurencegouws.terminal.gesture;

import android.os.Handler;
import android.os.SystemClock;
import android.widget.OverScroller;

/**
 * Owns gesture-driven scrollback and pinch budget state for the Android terminal host.
 *
 * <p>This controller keeps the activity free of gesture bookkeeping. It applies resolved scroll
 * and pinch policy to the native terminal bridge, while the raw gesture detector remains a
 * separate concern.
 */
public final class GestureStateController {
    /** Host callbacks needed to apply gesture policy without duplicating activity state. */
    public interface Host {
        boolean nativeLoaded();

        int visibleRows();

        int viewportHeightPx();

        int scrollbackCount();

        int scrollbackOffset();

        int setScrollbackOffset(int offsetRows);

        int followLiveBottom();

        int applyPinchZoom(float scaleFactor);

        int setPinchActive(boolean active);

        void refreshScrollOverlay();

        void reevaluateFrameLoop();
    }

    private static final float MIN_PENDING_PINCH_APPLY_DELTA = 0.008f;
    private static final long MIN_PINCH_APPLY_INTERVAL_MS = 24L;

    private final Handler handler;
    private final Host host;
    private final Runnable pinchZoomRetryRunnable;
    private final Runnable scrollbackFlingRunnable;

    private OverScroller scrollbackFlingScroller;
    private boolean pinchZoomActive = false;
    private boolean pinchZoomFrameScheduled = false;
    private boolean pinchZoomRetryScheduled = false;
    private float pendingPinchScaleFactor = 1.0f;
    private long lastPinchApplyUptimeMs = 0L;
    private int activeGestureVisibleRows = 0;
    private int activeGestureScrollbackCount = 0;
    private int activeGestureScrollbackOffset = 0;
    private float activeGestureScrollRemainderRows = 0.0f;
    private int flingLastScrollY = 0;
    private boolean flingScrollScheduled = false;

    public GestureStateController(Handler handler, Host host) {
        this.handler = handler;
        this.host = host;
        this.pinchZoomRetryRunnable = () -> {
            pinchZoomRetryScheduled = false;
            if (!pinchZoomActive) {
                return;
            }
            if (Math.abs(pendingPinchScaleFactor - 1.0f) < MIN_PENDING_PINCH_APPLY_DELTA) {
                return;
            }
            schedulePinchZoomFrame();
        };
        this.scrollbackFlingRunnable = () -> {
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
            applyScrollDelta(deltaY, host.viewportHeightPx());
            if (!scrollbackFlingScroller.isFinished()) {
                scheduleScrollbackFlingFrame();
            }
        };
    }

    public void setScrollbackFlingScroller(OverScroller scrollbackFlingScroller) {
        this.scrollbackFlingScroller = scrollbackFlingScroller;
    }

    public void onProductScrollBegin() {
        if (!host.nativeLoaded()) {
            return;
        }
        stopScrollbackFlingInternal();
        activeGestureVisibleRows = host.visibleRows();
        activeGestureScrollbackCount = host.scrollbackCount();
        activeGestureScrollbackOffset = host.scrollbackOffset();
        activeGestureScrollRemainderRows = 0.0f;
    }

    public void onScrollBy(float deltaY) {
        applyScrollDelta(deltaY, host.viewportHeightPx());
    }

    public void onScrollEnd() {
        activeGestureVisibleRows = 0;
        activeGestureScrollbackCount = 0;
        activeGestureScrollbackOffset = 0;
        activeGestureScrollRemainderRows = 0.0f;
    }

    public void onScrollFling(float velocityY, int viewportHeightPx) {
        if (!host.nativeLoaded() || scrollbackFlingScroller == null || viewportHeightPx <= 0) {
            return;
        }
        stopScrollbackFlingInternal();
        activeGestureVisibleRows = host.visibleRows();
        activeGestureScrollbackCount = host.scrollbackCount();
        activeGestureScrollbackOffset = host.scrollbackOffset();
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

    public void onPinchBegin() {
        if (!host.nativeLoaded()) {
            return;
        }
        stopScrollbackFlingInternal();
        pinchZoomActive = true;
        pinchZoomRetryScheduled = false;
        pendingPinchScaleFactor = 1.0f;
        host.setPinchActive(true);
    }

    public void onPinchZoom(float scaleFactor) {
        if (!host.nativeLoaded() || scaleFactor <= 0.0f) {
            return;
        }
        if (Math.abs(scaleFactor - 1.0f) < MIN_PENDING_PINCH_APPLY_DELTA) {
            return;
        }
        pendingPinchScaleFactor *= scaleFactor;
        schedulePinchZoomFrame();
    }

    public void onPinchEnd() {
        if (!host.nativeLoaded()) {
            return;
        }
        final float finalScaleFactor = pendingPinchScaleFactor;
        if (Math.abs(finalScaleFactor - 1.0f) >= MIN_PENDING_PINCH_APPLY_DELTA) {
            host.applyPinchZoom(finalScaleFactor);
            lastPinchApplyUptimeMs = SystemClock.uptimeMillis();
        }
        pinchZoomActive = false;
        pinchZoomRetryScheduled = false;
        handler.removeCallbacks(pinchZoomRetryRunnable);
        pendingPinchScaleFactor = 1.0f;
        host.setPinchActive(false);
    }

    public void reevaluate() {
        if (host.nativeLoaded() && !pinchZoomActive && !flingScrollScheduled) {
            host.reevaluateFrameLoop();
        }
    }

    public void refreshScrollOverlay() {
        host.refreshScrollOverlay();
    }

    public void stopScrollbackFling() {
        stopScrollbackFlingInternal();
    }

    private void schedulePinchZoomFrame() {
        if (pinchZoomFrameScheduled) {
            return;
        }
        pinchZoomFrameScheduled = true;
        android.view.Choreographer.getInstance().postFrameCallback(frameTimeNanos -> {
            pinchZoomFrameScheduled = false;
            if (!host.nativeLoaded() || !pinchZoomActive) {
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
            host.applyPinchZoom(scaleFactor);
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

    private void applyScrollDelta(float deltaY, int viewportHeightPx) {
        if (!host.nativeLoaded() || activeGestureVisibleRows <= 0 || viewportHeightPx <= 0) {
            return;
        }
        final float rowHeightPx = (float) viewportHeightPx / (float) activeGestureVisibleRows;
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
            host.followLiveBottom();
        } else {
            host.setScrollbackOffset(nextOffset);
        }
        activeGestureScrollbackOffset = nextOffset;
        host.refreshScrollOverlay();
        host.reevaluateFrameLoop();
    }

    private void scheduleScrollbackFlingFrame() {
        if (flingScrollScheduled) {
            return;
        }
        flingScrollScheduled = true;
        android.view.Choreographer.getInstance().postFrameCallback(frameTimeNanos -> scrollbackFlingRunnable.run());
    }

    private void stopScrollbackFlingInternal() {
        if (scrollbackFlingScroller != null && !scrollbackFlingScroller.isFinished()) {
            scrollbackFlingScroller.forceFinished(true);
        }
        flingScrollScheduled = false;
        flingLastScrollY = 0;
    }
}
