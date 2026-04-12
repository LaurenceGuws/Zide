package dev.zide.terminal;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.util.TypedValue;
import android.util.AttributeSet;
import android.util.DisplayMetrics;
import android.view.MotionEvent;
import android.view.View;

/**
 * Android-owned terminal scrollback overlay.
 *
 * <p>This view exists so product scrollback affordances are rendered and interacted with as native
 * Android UI, not as part of the terminal texture.
 */
public final class TerminalScrollOverlayView extends View {
    /** Host callbacks for scrollback control. */
    interface Host {
        void onScrollbackOffsetRequested(int offsetRows);

        void onFollowLiveBottomRequested();
    }

    private Host host;
    private final Paint trackPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint thumbPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final float density;
    private final float minThumbHeightPx;
    private final float idleTrackWidthPx;
    private final float activeTrackWidthPx;
    private final float idleThumbWidthPx;
    private final float activeThumbWidthPx;
    private final float activeHorizontalInsetPx;
    private final ValueAnimator interactionAnimator;

    private int visibleRows = 0;
    private int scrollbackCount = 0;
    private int scrollbackOffset = 0;
    private boolean dragActive = false;
    private float dragGrabOffsetPx = 0.0f;
    private float interactionProgress = 0.0f;

    public TerminalScrollOverlayView(Context context, Host host) {
        super(context);
        this.host = host;
        this.density = density(context);
        this.minThumbHeightPx = 36.0f * density;
        this.idleTrackWidthPx = 1.5f * density;
        this.activeTrackWidthPx = 3.0f * density;
        this.idleThumbWidthPx = 2.5f * density;
        this.activeThumbWidthPx = 5.0f * density;
        this.activeHorizontalInsetPx = 6.0f * density;
        this.interactionAnimator = new ValueAnimator();
        configureAnimator();
        initPaints();
        setClickable(true);
    }

    /** Sets or replaces the current host callback owner. */
    public void setHost(Host host) {
        this.host = host;
    }

    public TerminalScrollOverlayView(Context context, AttributeSet attrs) {
        super(context, attrs);
        this.host = null;
        this.density = density(context);
        this.minThumbHeightPx = 36.0f * density;
        this.idleTrackWidthPx = 1.5f * density;
        this.activeTrackWidthPx = 3.0f * density;
        this.idleThumbWidthPx = 2.5f * density;
        this.activeThumbWidthPx = 5.0f * density;
        this.activeHorizontalInsetPx = 6.0f * density;
        this.interactionAnimator = new ValueAnimator();
        configureAnimator();
        initPaints();
        setClickable(true);
    }

    public TerminalScrollOverlayView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        this.host = null;
        this.density = density(context);
        this.minThumbHeightPx = 36.0f * density;
        this.idleTrackWidthPx = 1.5f * density;
        this.activeTrackWidthPx = 3.0f * density;
        this.idleThumbWidthPx = 2.5f * density;
        this.activeThumbWidthPx = 5.0f * density;
        this.activeHorizontalInsetPx = 6.0f * density;
        this.interactionAnimator = new ValueAnimator();
        configureAnimator();
        initPaints();
        setClickable(true);
    }

    /** Updates the visible terminal rows and current scrollback state. */
    public void updateScrollMetrics(int nextVisibleRows, int nextScrollbackCount, int nextScrollbackOffset) {
        final int clampedRows = Math.max(nextVisibleRows, 0);
        final int clampedCount = Math.max(nextScrollbackCount, 0);
        final int clampedOffset = Math.max(0, Math.min(nextScrollbackOffset, clampedCount));
        final int targetVisibility = (clampedCount > 0 && clampedRows > 0) ? VISIBLE : GONE;
        if (visibleRows == clampedRows &&
                scrollbackCount == clampedCount &&
                scrollbackOffset == clampedOffset &&
                getVisibility() == targetVisibility) {
            return;
        }
        visibleRows = clampedRows;
        scrollbackCount = clampedCount;
        scrollbackOffset = clampedOffset;
        setVisibility(targetVisibility);
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        final ThumbGeometry geometry = thumbGeometry();
        if (!geometry.visible) {
            return;
        }
        if (interactionProgress > 0.01f) {
            canvas.drawRoundRect(
                    geometry.trackLeft,
                    geometry.trackTop,
                    geometry.trackRight,
                    geometry.trackBottom,
                    geometry.trackWidth * 0.5f,
                    geometry.trackWidth * 0.5f,
                    trackPaint);
        }
        canvas.drawRoundRect(
                geometry.thumbLeft,
                geometry.thumbTop,
                geometry.thumbRight,
                geometry.thumbBottom,
                geometry.thumbWidth * 0.5f,
                geometry.thumbWidth * 0.5f,
                thumbPaint);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        final ThumbGeometry geometry = thumbGeometry();
        if (!geometry.visible || host == null) {
            return false;
        }
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                setInteractionActive(true);
                dragActive = true;
                dragGrabOffsetPx = ifWithinThumb(event.getY(), geometry)
                        ? event.getY() - geometry.thumbTop
                        : geometry.thumbHeight * 0.5f;
                requestOffsetFromTouch(event.getY(), geometry, true);
                return true;
            case MotionEvent.ACTION_MOVE:
                if (!dragActive) {
                    return false;
                }
                requestOffsetFromTouch(event.getY(), geometry, false);
                return true;
            case MotionEvent.ACTION_UP:
                if (!dragActive) {
                    return false;
                }
                requestOffsetFromTouch(event.getY(), geometry, false);
                dragActive = false;
                dragGrabOffsetPx = 0.0f;
                setInteractionActive(false);
                return true;
            case MotionEvent.ACTION_CANCEL:
                dragActive = false;
                dragGrabOffsetPx = 0.0f;
                setInteractionActive(false);
                return true;
            default:
                return super.onTouchEvent(event);
        }
    }

    private void requestOffsetFromTouch(float y, ThumbGeometry geometry, boolean tapJump) {
        final float available = geometry.trackHeight - geometry.thumbHeight;
        if (available <= 0.0f || scrollbackCount <= 0) {
            host.onFollowLiveBottomRequested();
            return;
        }
        final float rawTop = tapJump
                ? y - geometry.thumbHeight * 0.5f
                : y - dragGrabOffsetPx;
        final float clampedTop = Math.max(geometry.trackTop, Math.min(rawTop, geometry.trackBottom - geometry.thumbHeight));
        final float progress = (clampedTop - geometry.trackTop) / available;
        final int offset = Math.round((1.0f - progress) * scrollbackCount);
        if (offset <= 0) {
            host.onFollowLiveBottomRequested();
        } else {
            host.onScrollbackOffsetRequested(offset);
        }
    }

    private boolean ifWithinThumb(float y, ThumbGeometry geometry) {
        return y >= geometry.thumbTop && y <= geometry.thumbBottom;
    }

    private ThumbGeometry thumbGeometry() {
        final ThumbGeometry geometry = new ThumbGeometry();
        if (visibleRows <= 0 || scrollbackCount <= 0 || getHeight() <= 0 || getWidth() <= 0) {
            return geometry;
        }
        final int totalRows = visibleRows + scrollbackCount;
        if (totalRows <= 0) {
            return geometry;
        }
        geometry.visible = true;
        geometry.trackTop = 0.0f;
        geometry.trackBottom = getHeight();
        geometry.trackHeight = geometry.trackBottom - geometry.trackTop;
        final float horizontalInset = lerp(0.0f, activeHorizontalInsetPx, interactionProgress);
        geometry.trackWidth = lerp(idleTrackWidthPx, activeTrackWidthPx, interactionProgress);
        geometry.trackRight = getWidth() - horizontalInset;
        geometry.trackLeft = geometry.trackRight - geometry.trackWidth;
        geometry.thumbWidth = lerp(idleThumbWidthPx, activeThumbWidthPx, interactionProgress);
        final float rawThumbHeight = geometry.trackHeight * ((float) visibleRows / (float) totalRows);
        geometry.thumbHeight = Math.max(minThumbHeightPx, Math.min(rawThumbHeight, geometry.trackHeight));
        final float available = Math.max(geometry.trackHeight - geometry.thumbHeight, 0.0f);
        final float progress = 1.0f - ((float) scrollbackOffset / (float) scrollbackCount);
        geometry.thumbTop = geometry.trackTop + available * progress;
        geometry.thumbBottom = geometry.thumbTop + geometry.thumbHeight;
        geometry.thumbRight = getWidth() - horizontalInset;
        geometry.thumbLeft = geometry.thumbRight - geometry.thumbWidth;
        return geometry;
    }

    private void initPaints() {
        syncPaints();
    }

    private static float density(Context context) {
        final DisplayMetrics metrics = context.getResources().getDisplayMetrics();
        return metrics.density > 0.0f ? metrics.density : 1.0f;
    }

    private void configureAnimator() {
        interactionAnimator.setFloatValues(0.0f, 1.0f);
        interactionAnimator.addUpdateListener(animation -> {
            interactionProgress = (float) animation.getAnimatedValue();
            syncPaints();
            invalidate();
        });
    }

    private void setInteractionActive(boolean active) {
        interactionAnimator.cancel();
        interactionAnimator.setFloatValues(interactionProgress, active ? 1.0f : 0.0f);
        interactionAnimator.setDuration(active ? 110L : 180L);
        interactionAnimator.start();
    }

    private void syncPaints() {
        trackPaint.setColor(colorWithAlpha(0x273643, lerp(0.0f, 0.16f, interactionProgress)));
        thumbPaint.setColor(colorWithAlpha(0x98abc2, lerp(0.30f, 0.72f, interactionProgress)));
    }

    private static int colorWithAlpha(int rgb, float alpha) {
        final int alphaByte = Math.max(0, Math.min(255, Math.round(alpha * 255.0f)));
        return (alphaByte << 24) | (rgb & 0x00ffffff);
    }

    private static float lerp(float start, float end, float progress) {
        return start + ((end - start) * progress);
    }

    private static final class ThumbGeometry {
        boolean visible = false;
        float trackLeft = 0.0f;
        float trackTop = 0.0f;
        float trackRight = 0.0f;
        float trackBottom = 0.0f;
        float trackWidth = 0.0f;
        float trackHeight = 0.0f;
        float thumbLeft = 0.0f;
        float thumbTop = 0.0f;
        float thumbRight = 0.0f;
        float thumbBottom = 0.0f;
        float thumbWidth = 0.0f;
        float thumbHeight = 0.0f;
    }
}
