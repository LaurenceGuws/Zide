package dev.zide.terminal;

import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import android.view.ViewConfiguration;

final class ProductGestureController {
    interface Host {
        void onProductSingleTap();

        void onProductPinchBegin();

        void onProductPinchZoom(float scaleFactor);

        void onProductPinchEnd();
    }

    private final View target;
    private final Host host;
    private final ScaleGestureDetector scaleDetector;
    private final int touchSlop;
    private static final float MIN_PINCH_DISPATCH_DELTA = 0.01f;

    private float downX = 0.0f;
    private float downY = 0.0f;
    private float lastDispatchedScaleFactor = 1.0f;
    private boolean moved = false;
    private boolean pinchActive = false;

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
                        lastDispatchedScaleFactor = 1.0f;
                        host.onProductPinchBegin();
                        return true;
                    }

                    @Override
                    public boolean onScale(ScaleGestureDetector detector) {
                        final float scaleFactor = detector.getScaleFactor();
                        if (Math.abs(scaleFactor - lastDispatchedScaleFactor) < MIN_PINCH_DISPATCH_DELTA) {
                            return true;
                        }
                        lastDispatchedScaleFactor = scaleFactor;
                        host.onProductPinchZoom(scaleFactor);
                        return true;
                    }

                    @Override
                    public void onScaleEnd(ScaleGestureDetector detector) {
                        pinchActive = false;
                        lastDispatchedScaleFactor = 1.0f;
                        host.onProductPinchEnd();
                    }
                });
    }

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
                lastDispatchedScaleFactor = 1.0f;
                moved = false;
                break;
            default:
                break;
        }
        return true;
    }
}
