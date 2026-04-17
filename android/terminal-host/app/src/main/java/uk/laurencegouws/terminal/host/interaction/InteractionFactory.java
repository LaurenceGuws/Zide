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
        return SelectionControllerFactory.create(new SelectionControllerFactory.Host() {
            @Override
            public Context context() {
                return context;
            }

            @Override
            public FrameLayout productSurfaceContainer() {
                return productSurfaceContainer;
            }

            @Override
            public int productViewportWidthPx() {
                return productViewportWidthPx.getAsInt();
            }

            @Override
            public int productViewportHeightPx() {
                return productViewportHeightPx.getAsInt();
            }

            @Override
            public void stopScrollbackFling() {
                stopScrollbackFling.run();
            }

            @Override
            public void refreshScrollOverlay() {
                refreshScrollOverlay.run();
            }

            @Override
            public void reevaluateFrameLoop() {
                reevaluateFrameLoop.run();
            }

            @Override
            public void appendEvent(String event) {
                appendEvent.accept(event);
            }

            @Override
            public boolean nativeLoaded() {
                return NativeBridge.nativeLoaded();
            }

            @Override
            public int beginWordSelectionAtVisibleCell(int row, int col) {
                return NativeBridge.nativeBeginSelectionWordAtVisibleCellBridge(row, col);
            }

            @Override
            public int extendSelectionGestureToVisibleCell(int row, int col) {
                return NativeBridge.nativeExtendSelectionGestureToVisibleCellBridge(row, col);
            }

            @Override
            public int finishSelectionGesture() {
                return NativeBridge.nativeFinishSelectionGestureBridge();
            }

            @Override
            public int clearSelection() {
                return NativeBridge.nativeClearSelectionBridge();
            }

            @Override
            public int updateSelectionStartAtVisibleCell(int row, int col) {
                return NativeBridge.nativeUpdateSelectionStartAtVisibleCellBridge(row, col);
            }

            @Override
            public int updateSelectionEndAtVisibleCell(int row, int col) {
                return NativeBridge.nativeUpdateSelectionEndAtVisibleCellBridge(row, col);
            }

            @Override
            public boolean currentSelectionActive() {
                return NativeBridge.nativeCurrentSelectionActiveBridge();
            }

            @Override
            public int currentSelectionRectLeft() {
                return NativeBridge.nativeCurrentSelectionRectLeftBridge();
            }

            @Override
            public int currentSelectionRectTop() {
                return NativeBridge.nativeCurrentSelectionRectTopBridge();
            }

            @Override
            public int currentSelectionRectRight() {
                return NativeBridge.nativeCurrentSelectionRectRightBridge();
            }

            @Override
            public int currentSelectionRectBottom() {
                return NativeBridge.nativeCurrentSelectionRectBottomBridge();
            }

            @Override
            public int currentSelectionStartRectLeft() {
                return NativeBridge.nativeCurrentSelectionStartRectLeftBridge();
            }

            @Override
            public int currentSelectionStartRectTop() {
                return NativeBridge.nativeCurrentSelectionStartRectTopBridge();
            }

            @Override
            public int currentSelectionStartRectRight() {
                return NativeBridge.nativeCurrentSelectionStartRectRightBridge();
            }

            @Override
            public int currentSelectionStartRectBottom() {
                return NativeBridge.nativeCurrentSelectionStartRectBottomBridge();
            }

            @Override
            public int currentSelectionEndRectLeft() {
                return NativeBridge.nativeCurrentSelectionEndRectLeftBridge();
            }

            @Override
            public int currentSelectionEndRectTop() {
                return NativeBridge.nativeCurrentSelectionEndRectTopBridge();
            }

            @Override
            public int currentSelectionEndRectRight() {
                return NativeBridge.nativeCurrentSelectionEndRectRightBridge();
            }

            @Override
            public int currentSelectionEndRectBottom() {
                return NativeBridge.nativeCurrentSelectionEndRectBottomBridge();
            }

            @Override
            public byte[] currentSelectionTextBytes() {
                return NativeBridge.nativeCurrentSelectionTextBytesBridge();
            }

            @Override
            public int currentVisibleRows() {
                return NativeBridge.nativeCurrentSessionVisibleRowsBridge();
            }

            @Override
            public int currentVisibleCols() {
                return NativeBridge.nativeCurrentSessionVisibleColsBridge();
            }

            @Override
            public int currentScrollbackCount() {
                return NativeBridge.nativeCurrentSessionScrollbackCountBridge();
            }

            @Override
            public int currentScrollbackOffset() {
                return NativeBridge.nativeCurrentSessionScrollbackOffsetBridge();
            }

            @Override
            public int setShellScrollbackOffset(int offsetRows) {
                return NativeBridge.nativeSetSessionScrollbackOffsetBridge(offsetRows);
            }

            @Override
            public int followShellLiveBottom() {
                return NativeBridge.nativeFollowSessionLiveBottomBridge();
            }
        });
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
