package uk.laurencegouws.terminal.host.interaction;

import java.util.function.Consumer;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.selection.SelectionControllerFactory;

/** Functional callback adapter for {@link SelectionControllerFactory}. */
public final class SelectionCallbacks implements SelectionControllerFactory.Host {
    private final IntSupplier productViewportWidthPx;
    private final IntSupplier productViewportHeightPx;
    private final Runnable stopScrollbackFling;
    private final Runnable refreshProductScrollOverlay;
    private final Runnable reevaluateProductFrameLoop;
    private final Consumer<String> appendEvent;

    public SelectionCallbacks(
            IntSupplier productViewportWidthPx,
            IntSupplier productViewportHeightPx,
            Runnable stopScrollbackFling,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop,
            Consumer<String> appendEvent) {
        this.productViewportWidthPx = productViewportWidthPx;
        this.productViewportHeightPx = productViewportHeightPx;
        this.stopScrollbackFling = stopScrollbackFling;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
        this.appendEvent = appendEvent;
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
    public void refreshProductScrollOverlay() {
        refreshProductScrollOverlay.run();
    }

    @Override
    public void reevaluateProductFrameLoop() {
        reevaluateProductFrameLoop.run();
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
}
