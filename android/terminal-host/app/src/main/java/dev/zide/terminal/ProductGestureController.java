package dev.zide.terminal;

import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import android.view.ViewConfiguration;

/**
 * Owns product-surface touch gesture policy for the Android terminal host.
 *
 * <p>This seam exists to keep raw Android gesture noise out of the shared native renderer. The
 * host normalizes touch/pinch behavior into a small product contract:
 *
 * <ul>
 *   <li>single-tap for IME focus
 *   <li>pinch-begin / quantized pinch-step / pinch-end for terminal zoom
 * </ul>
 *
 * <p>Raw detector scale deltas are intentionally not forwarded one-for-one. They are accumulated
 * and quantized here so fast pinches do not explode into tiny renderer work bursts.
 */
final class ProductGestureController {
    /**
     * Host callbacks for product-surface gestures.
     *
     * <p>The host owns product actions; this controller owns gesture detection and quantization.
     */
    interface Host {
        /** Opens or focuses the product IME target after a resolved single tap. */
        void onProductSingleTap();

        /** Marks the beginning of an interactive pinch session. */
        void onProductPinchBegin();

        /**
         * Applies one quantized pinch step.
         *
         * <p>{@code scaleFactor} is an accumulated multiplicative zoom step, not a raw detector
         * sample.
         */
        void onProductPinchZoom(float scaleFactor);

        /** Flushes any remaining pinch state and closes the active pinch session. */
        void onProductPinchEnd();
    }

    private final View target;
    private final Host host;
    private final ScaleGestureDetector scaleDetector;
    private final int touchSlop;

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
    private float accumulatedPinchScaleFactor = 1.0f;
    private boolean moved = false;
    private boolean pinchActive = false;

    /** Creates a gesture controller bound to the product interaction surface. */
    ProductGestureController(View target, Host host) {
        this.target = target;
        this.host = host;
        this.touchSlop = ViewConfiguration.get(target.getContext()).getScaledTouchSlop();
        this.scaleDetector = new ScaleGestureDetector(
                target.getContext(),
                new ScaleGestureDetector.SimpleOnScaleGestureListener() {
                    @Override
                    public boolean onScaleBegin(ScaleGestureDetector detector) {
                        pinchActive = true;
                        accumulatedPinchScaleFactor = 1.0f;
                        host.onProductPinchBegin();
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
                        host.onProductPinchEnd();
                    }
                });
    }

    /** Installs the gesture listener onto the bound target view. */
    void install() {
        target.setOnTouchListener(this::onTouch);
    }

    private boolean onTouch(View view, MotionEvent event) {
        scaleDetector.onTouchEvent(event);
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                downX = event.getX();
                downY = event.getY();
                moved = false;
                break;
            case MotionEvent.ACTION_MOVE:
                if (Math.abs(event.getX() - downX) > touchSlop ||
                        Math.abs(event.getY() - downY) > touchSlop) {
                    moved = true;
                }
                break;
            case MotionEvent.ACTION_POINTER_DOWN:
                pinchActive = true;
                moved = true;
                break;
            case MotionEvent.ACTION_UP:
                if (!pinchActive && !moved && event.getPointerCount() == 1) {
                    host.onProductSingleTap();
                }
                pinchActive = false;
                moved = false;
                break;
            case MotionEvent.ACTION_CANCEL:
                pinchActive = false;
                accumulatedPinchScaleFactor = 1.0f;
                moved = false;
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
            host.onProductPinchZoom(quantizedFactor);
            accumulatedPinchScaleFactor /= quantizedFactor;
        }

        if (flushRemainder && Math.abs(accumulatedPinchScaleFactor - 1.0f) >= MIN_PINCH_DISPATCH_DELTA) {
            host.onProductPinchZoom(accumulatedPinchScaleFactor);
            accumulatedPinchScaleFactor = 1.0f;
        }
    }
}
