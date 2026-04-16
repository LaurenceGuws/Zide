package uk.laurencegouws.terminal.host.surface;

import android.view.SurfaceHolder;

import uk.laurencegouws.terminal.gesture.GestureController;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.scroll.ScrollOverlayView;
import uk.laurencegouws.terminal.selection.SelectionController;

/**
 * Owns terminal-surface widget interactions for one Android terminal instance.
 *
 * <p>This controller is the widget boundary that can be reused for future tabbed
 * hosting: surface callbacks, product gestures, and scroll-overlay callbacks all
 * terminate here instead of on the activity.
 */
public final class SurfaceWidgetController
        implements SurfaceHolder.Callback2, GestureController.Host, ScrollOverlayView.Host {
    /** Host callbacks for native bridge access and frame-loop side effects. */
    public interface Host {
        boolean nativeLoaded();

        int setShellScrollbackOffset(int offsetRows);

        int followShellLiveBottom();

        int productViewportHeightPx();

        void appendEvent(String event);

        void refreshScrollOverlay();

        void reevaluateFrameLoop();
    }

    private final SurfaceController surfaceHostController;
    private final SelectionController selectionController;
    private final GestureStateController GestureStateController;
    private final Host host;

    public SurfaceWidgetController(
            SurfaceController surfaceHostController,
            SelectionController selectionController,
            GestureStateController GestureStateController,
            Host host) {
        this.surfaceHostController = surfaceHostController;
        this.selectionController = selectionController;
        this.GestureStateController = GestureStateController;
        this.host = host;
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

    @Override
    public void onTouchDown() {
        GestureStateController.stopScrollbackFling();
    }

    @Override
    public void onSingleTap(float x, float y) {
        selectionController.onSingleTap(x, y);
    }

    @Override
    public void onScrollBegin() {
        GestureStateController.onScrollBegin();
    }

    @Override
    public void onScrollBy(float deltaY) {
        GestureStateController.onScrollBy(deltaY);
    }

    @Override
    public void onScrollEnd() {
        GestureStateController.onScrollEnd();
    }

    @Override
    public void onScrollFling(float velocityY) {
        GestureStateController.onScrollFling(velocityY, host.productViewportHeightPx());
    }

    @Override
    public void onLongPress(float x, float y) {
        selectionController.onLongPress(x, y);
    }

    @Override
    public void onSelectionDrag(float x, float y) {
        selectionController.onSelectionDrag(x, y);
    }

    @Override
    public void onSelectionDragEnd(float x, float y) {
        selectionController.onSelectionDragEnd(x, y);
    }

    @Override
    public void onScrollbackOffsetRequested(int offsetRows) {
        GestureStateController.stopScrollbackFling();
        if (!host.nativeLoaded()) {
            return;
        }
        final int status = host.setShellScrollbackOffset(offsetRows);
        host.appendEvent("product.scrollback.offset rows=" + offsetRows + " status=" + status);
        host.refreshScrollOverlay();
        host.reevaluateFrameLoop();
    }

    @Override
    public void onFollowLiveBottomRequested() {
        GestureStateController.stopScrollbackFling();
        if (!host.nativeLoaded()) {
            return;
        }
        final int status = host.followShellLiveBottom();
        host.appendEvent("product.scrollback.follow_bottom status=" + status);
        host.refreshScrollOverlay();
        host.reevaluateFrameLoop();
    }

    @Override
    public void onPinchBegin() {
        GestureStateController.onPinchBegin();
    }

    @Override
    public void onPinchZoom(float scaleFactor) {
        GestureStateController.onPinchZoom(scaleFactor);
    }

    @Override
    public void onPinchEnd() {
        GestureStateController.onPinchEnd();
    }
}
