package uk.laurencegouws.terminal.host.surface;

import android.view.SurfaceHolder;

import uk.laurencegouws.terminal.gesture.ProductGestureController;
import uk.laurencegouws.terminal.gesture.TerminalGestureStateController;
import uk.laurencegouws.terminal.scroll.TerminalScrollOverlayView;
import uk.laurencegouws.terminal.selection.TerminalSelectionController;

/**
 * Owns terminal-surface widget interactions for one Android terminal instance.
 *
 * <p>This controller is the widget boundary that can be reused for future tabbed
 * hosting: surface callbacks, product gestures, and scroll-overlay callbacks all
 * terminate here instead of on the activity.
 */
public final class SurfaceWidgetController
        implements SurfaceHolder.Callback2, ProductGestureController.Host, TerminalScrollOverlayView.Host {
    /** Host callbacks for native bridge access and frame-loop side effects. */
    public interface Host {
        boolean nativeLoaded();

        int setShellScrollbackOffset(int offsetRows);

        int followShellLiveBottom();

        int productViewportHeightPx();

        void appendEvent(String event);

        void refreshProductScrollOverlay();

        void reevaluateProductFrameLoop();
    }

    private final SurfaceController surfaceHostController;
    private final TerminalSelectionController selectionController;
    private final TerminalGestureStateController terminalGestureStateController;
    private final Host host;

    public SurfaceWidgetController(
            SurfaceController surfaceHostController,
            TerminalSelectionController selectionController,
            TerminalGestureStateController terminalGestureStateController,
            Host host) {
        this.surfaceHostController = surfaceHostController;
        this.selectionController = selectionController;
        this.terminalGestureStateController = terminalGestureStateController;
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
    public void onProductSingleTap(float x, float y) {
        selectionController.onProductSingleTap(x, y);
    }

    @Override
    public void onProductScrollBegin() {
        terminalGestureStateController.onProductScrollBegin();
    }

    @Override
    public void onProductScrollBy(float deltaY) {
        terminalGestureStateController.onProductScrollBy(deltaY);
    }

    @Override
    public void onProductScrollEnd() {
        terminalGestureStateController.onProductScrollEnd();
    }

    @Override
    public void onProductScrollFling(float velocityY) {
        terminalGestureStateController.onProductScrollFling(velocityY, host.productViewportHeightPx());
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
        if (!host.nativeLoaded()) {
            return;
        }
        final int status = host.setShellScrollbackOffset(offsetRows);
        host.appendEvent("product.scrollback.offset rows=" + offsetRows + " status=" + status);
        host.refreshProductScrollOverlay();
        host.reevaluateProductFrameLoop();
    }

    @Override
    public void onFollowLiveBottomRequested() {
        if (!host.nativeLoaded()) {
            return;
        }
        final int status = host.followShellLiveBottom();
        host.appendEvent("product.scrollback.follow_bottom status=" + status);
        host.refreshProductScrollOverlay();
        host.reevaluateProductFrameLoop();
    }

    @Override
    public void onProductPinchBegin() {
        terminalGestureStateController.onProductPinchBegin();
    }

    @Override
    public void onProductPinchZoom(float scaleFactor) {
        terminalGestureStateController.onProductPinchZoom(scaleFactor);
    }

    @Override
    public void onProductPinchEnd() {
        terminalGestureStateController.onProductPinchEnd();
    }
}
