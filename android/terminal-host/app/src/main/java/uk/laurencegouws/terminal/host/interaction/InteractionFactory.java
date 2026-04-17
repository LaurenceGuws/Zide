package uk.laurencegouws.terminal.host.interaction;

import android.content.Context;
import android.widget.FrameLayout;

import java.util.function.Consumer;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.gesture.GestureStateController;
import uk.laurencegouws.terminal.gesture.GestureStateControllerFactory;
import uk.laurencegouws.terminal.selection.SelectionController;
import uk.laurencegouws.terminal.selection.SelectionControllerFactory;

/**
 * Selection and gesture interaction assembly helpers.
 *
 * <p>Owns interaction-specific controller construction so generic host assembly
 * remains focused on lifecycle/runtime/surface wiring.
 */
public final class InteractionFactory {
    private InteractionFactory() {
    }

    public static SelectionController createSelectionController(
            Context context,
            FrameLayout productSurfaceContainer,
            IntSupplier productViewportWidthPx,
            IntSupplier productViewportHeightPx,
            Runnable stopScrollbackFling,
            Runnable refreshScrollOverlay,
            Runnable reevaluateFrameLoop,
            Consumer<String> appendEvent) {
        return SelectionControllerFactory.create(
                new SelectionCallbacks(
                        context,
                        productSurfaceContainer,
                        productViewportWidthPx,
                        productViewportHeightPx,
                        stopScrollbackFling,
                        refreshScrollOverlay,
                        reevaluateFrameLoop,
                        appendEvent));
    }

    public static GestureStateController createGestureStateController(
            Context context,
            android.os.Handler handler,
            IntSupplier viewportHeightPx,
            Runnable refreshScrollOverlay,
            Runnable reevaluateFrameLoop) {
        return GestureStateControllerFactory.create(
                context,
                handler,
                new GestureStateControllerFactory.Host() {
                    @Override
                    public boolean nativeLoaded() {
                        return NativeBridge.nativeLoaded();
                    }

                    @Override
                    public int visibleRows() {
                        return NativeBridge.nativeCurrentSessionVisibleRowsBridge();
                    }

                    @Override
                    public int viewportHeightPx() {
                        return viewportHeightPx.getAsInt();
                    }

                    @Override
                    public int scrollbackCount() {
                        return NativeBridge.nativeCurrentSessionScrollbackCountBridge();
                    }

                    @Override
                    public int scrollbackOffset() {
                        return NativeBridge.nativeCurrentSessionScrollbackOffsetBridge();
                    }

                    @Override
                    public int setScrollbackOffset(int offsetRows) {
                        return NativeBridge.nativeSetSessionScrollbackOffsetBridge(offsetRows);
                    }

                    @Override
                    public int followLiveBottom() {
                        return NativeBridge.nativeFollowSessionLiveBottomBridge();
                    }

                    @Override
                    public int applyPinchZoom(float scaleFactor) {
                        return NativeBridge.nativeApplyPinchZoomBridge(scaleFactor);
                    }

                    @Override
                    public int setPinchActive(boolean active) {
                        return NativeBridge.nativeSetPinchActiveBridge(active);
                    }

                    @Override
                    public void refreshScrollOverlay() {
                        refreshScrollOverlay.run();
                    }

                    @Override
                    public void reevaluateFrameLoop() {
                        reevaluateFrameLoop.run();
                    }
                });
    }
}
