package uk.laurencegouws.terminal.gesture;

import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.VelocityTracker;

/**
 * Owns product-surface touch gesture policy for the Android terminal host.
 *
 * <p>This seam exists to keep raw Android gesture noise out of the shared native renderer. The
 * host normalizes touch/pinch behavior into a small product contract:
 *
 * <ul>
 *   <li>single-tap for product surface policy
 *   <li>resolved vertical drag for scrollback
 *   <li>long press for Android-native text interaction
 *   <li>pinch-begin / quantized pinch-step / pinch-end for terminal zoom
 * </ul>
 *
 * <p>Raw detector scale deltas are intentionally not forwarded one-for-one. They are accumulated
 * and quantized here so fast pinches do not explode into tiny renderer work bursts.
 */
public final class GestureController {
    /**
     * Host callbacks for product-surface gestures.
     *
     * <p>The host owns product actions; this controller owns gesture detection and quantization.
     */
    public interface Host {
        /**
         * Notifies that a new primary touch sequence started on the product surface ({@link
         * MotionEvent#ACTION_DOWN}).
         *
         * <p>Hosts use this to cancel momentum effects (for example scrollback fling) so a new
         * gesture cannot race inertial scrolling.
         */
        void onTouchDown();

        /** Applies the resolved single-tap product-surface policy at the tap location. */
        void onSingleTap(float x, float y);

        /** Marks the beginning of a resolved single-pointer vertical scrollback gesture. */
        void onProductScrollBegin();

        /** Applies one resolved vertical scroll delta for Android-owned scrollback. */
        void onScrollBy(float deltaY);

        /** Closes the active single-pointer vertical scrollback gesture. */
        void onScrollEnd();

        /** Starts Android-owned momentum scrolling after a resolved vertical drag release. */
        void onScrollFling(float velocityY);

        /** Starts Android-native text interaction from a resolved long press. */
        void onLongPress(float x, float y);

        /** Extends the active Android-native text selection drag. */
        void onSelectionDrag(float x, float y);

        /** Finishes the active Android-native text selection drag. */
        void onSelectionDragEnd(float x, float y);

        /** Marks the beginning of an interactive pinch session. */
        void onPinchBegin();

        /**
         * Applies one quantized pinch step.
         *
         * <p>{@code scaleFactor} is an accumulated multiplicative zoom step, not a raw detector
         * sample.
         */
        void onPinchZoom(float scaleFactor);

        /** Flushes any remaining pinch state and closes the active pinch session. */
        void onPinchEnd();
    }

    private final View target;
    private final Host host;
    private final ScaleGestureDetector scaleDetector;
    private final int touchSlop;
    private final int minimumFlingVelocity;
    private final int maximumFlingVelocity;

    /**
     * Raw detector deltas smaller than this are treated as touch noise and only accumulate
     * internally.
     */
    private static final float MIN_PINCH_DISPATCH_DELTA = 0.004f;
    /**
     * One quantized pinch step in natural-log scale space.
     *
     * <p>Using log space keeps zoom-in and zoom-out symmetric and prevents long fast pinches from
     * generating too many tiny multiplicative steps.
     */
    private static final float PINCH_LOG_STEP = 0.035f;

    private float downX = 0.0f;
    private float downY = 0.0f;
    private float lastY = 0.0f;
    private float accumulatedPinchScaleFactor = 1.0f;
    private boolean moved = false;
    private boolean pinchActive = false;
    private boolean scrollActive = false;
    private boolean longPressTriggered = false;
    private VelocityTracker velocityTracker = null;
    private final Runnable longPressRunnable = new Runnable() {
        @Override
        public void run() {
            if (scrollActive || pinchActive || moved || longPressTriggered) {
                return;
            }
            longPressTriggered = true;
            moved = true;
            host.onLongPress(downX, downY);
        }
    };

    /** Creates a gesture controller bound to the product interaction surface. */
    public GestureController(View target, Host host) {
        this.target = target;
        this.host = host;
        final ViewConfiguration viewConfig = ViewConfiguration.get(target.getContext());
        this.touchSlop = viewConfig.getScaledTouchSlop();
        this.minimumFlingVelocity = viewConfig.getScaledMinimumFlingVelocity();
        this.maximumFlingVelocity = viewConfig.getScaledMaximumFlingVelocity();
        this.scaleDetector = new ScaleGestureDetector(
                target.getContext(),
                new ScaleGestureDetector.SimpleOnScaleGestureListener() {
                    @Override
                    public boolean onScaleBegin(ScaleGestureDetector detector) {
                        cancelLongPress();
                        if (scrollActive) {
                            scrollActive = false;
                            host.onScrollEnd();
                        }
                        pinchActive = true;
                        accumulatedPinchScaleFactor = 1.0f;
                        host.onPinchBegin();
                        return true;
                    }

                    @Override
                    public boolean onScale(ScaleGestureDetector detector) {
                        final float scaleFactor = detector.getScaleFactor();
                        if (Math.abs(scaleFactor - 1.0f) < MIN_PINCH_DISPATCH_DELTA) {
                            return true;
                        }
                        accumulatedPinchScaleFactor *= scaleFactor;
                        dispatchQuantizedPinchSteps(false);
                        return true;
                    }

                    @Override
                    public void onScaleEnd(ScaleGestureDetector detector) {
                        pinchActive = false;
                        dispatchQuantizedPinchSteps(true);
                        accumulatedPinchScaleFactor = 1.0f;
                        host.onPinchEnd();
                    }
                });
    }

    /** Installs the gesture listener onto the bound target view. */
    public void install() {
        target.setOnTouchListener(this::onTouch);
    }

    private boolean onTouch(View view, MotionEvent event) {
        ensureVelocityTracker();
        velocityTracker.addMovement(event);
        scaleDetector.onTouchEvent(event);
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                host.onTouchDown();
                downX = event.getX();
                downY = event.getY();
                lastY = downY;
                moved = false;
                scrollActive = false;
                longPressTriggered = false;
                scheduleLongPress();
                break;
            case MotionEvent.ACTION_MOVE:
                final float deltaX = event.getX() - downX;
                final float deltaY = event.getY() - downY;
                if (!scrollActive &&
                        !longPressTriggered &&
                        Math.abs(deltaY) > touchSlop &&
                        Math.abs(deltaY) > Math.abs(deltaX)) {
                    cancelLongPress();
                    scrollActive = true;
                    moved = true;
                    lastY = event.getY();
                    host.onProductScrollBegin();
                }
                if (longPressTriggered) {
                    host.onSelectionDrag(event.getX(), event.getY());
                } else if (scrollActive) {
                    final float stepY = event.getY() - lastY;
                    lastY = event.getY();
                    if (stepY != 0.0f) {
                        host.onScrollBy(stepY);
                    }
                } else if (Math.abs(deltaX) > touchSlop || Math.abs(deltaY) > touchSlop) {
                    cancelLongPress();
                    moved = true;
                }
                break;
            case MotionEvent.ACTION_POINTER_DOWN:
                cancelLongPress();
                if (longPressTriggered) {
                    host.onSelectionDragEnd(event.getX(), event.getY());
                    longPressTriggered = false;
                }
                if (scrollActive) {
                    scrollActive = false;
                    host.onScrollEnd();
                }
                pinchActive = true;
                moved = true;
                break;
            case MotionEvent.ACTION_UP:
                cancelLongPress();
                if (scrollActive) {
                    velocityTracker.computeCurrentVelocity(1000, maximumFlingVelocity);
                    final float velocityY = velocityTracker.getYVelocity(event.getPointerId(0));
                    scrollActive = false;
                    host.onScrollEnd();
                    if (Math.abs(velocityY) >= minimumFlingVelocity) {
                        host.onScrollFling(velocityY);
                    }
                } else if (longPressTriggered) {
                    host.onSelectionDragEnd(event.getX(), event.getY());
                } else if (!pinchActive && !moved && event.getPointerCount() == 1) {
                    host.onSingleTap(event.getX(), event.getY());
                }
                pinchActive = false;
                moved = false;
                longPressTriggered = false;
                releaseVelocityTracker();
                break;
            case MotionEvent.ACTION_CANCEL:
                cancelLongPress();
                if (longPressTriggered) {
                    host.onSelectionDragEnd(downX, downY);
                }
                if (scrollActive) {
                    scrollActive = false;
                    host.onScrollEnd();
                }
                pinchActive = false;
                accumulatedPinchScaleFactor = 1.0f;
                moved = false;
                longPressTriggered = false;
                releaseVelocityTracker();
                break;
            default:
                break;
        }
        return true;
    }

    private void dispatchQuantizedPinchSteps(boolean flushRemainder) {
        if (!(accumulatedPinchScaleFactor > 0.0f)) {
            accumulatedPinchScaleFactor = 1.0f;
            return;
        }

        final double accumulatedLog = Math.log(accumulatedPinchScaleFactor);
        final int wholeSteps = (int) (accumulatedLog / PINCH_LOG_STEP);
        if (wholeSteps != 0) {
            final float quantizedFactor = (float) Math.exp(wholeSteps * PINCH_LOG_STEP);
            host.onPinchZoom(quantizedFactor);
            accumulatedPinchScaleFactor /= quantizedFactor;
        }

        if (flushRemainder && Math.abs(accumulatedPinchScaleFactor - 1.0f) >= MIN_PINCH_DISPATCH_DELTA) {
            host.onPinchZoom(accumulatedPinchScaleFactor);
            accumulatedPinchScaleFactor = 1.0f;
        }
    }

    private void ensureVelocityTracker() {
        if (velocityTracker == null) {
            velocityTracker = VelocityTracker.obtain();
        }
    }

    private void scheduleLongPress() {
        target.removeCallbacks(longPressRunnable);
        target.postDelayed(longPressRunnable, ViewConfiguration.getLongPressTimeout());
    }

    private void cancelLongPress() {
        target.removeCallbacks(longPressRunnable);
    }

    private void releaseVelocityTracker() {
        if (velocityTracker == null) {
            return;
        }
        velocityTracker.recycle();
        velocityTracker = null;
    }
}
