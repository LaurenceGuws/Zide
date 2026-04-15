package uk.laurencegouws.terminal.host.interaction;

import java.util.function.Consumer;
import java.util.function.IntSupplier;

import uk.laurencegouws.terminal.TerminalNativeBridge;
import uk.laurencegouws.terminal.selection.TerminalSelectionControllerFactory;

/** Functional callback adapter for {@link TerminalSelectionControllerFactory}. */
public final class SelectionCallbacks implements TerminalSelectionControllerFactory.Host {
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
        return TerminalNativeBridge.nativeLoaded();
    }

    @Override
    public int beginWordSelectionAtVisibleCell(int row, int col) {
        return TerminalNativeBridge.nativeBeginSelectionWordAtVisibleCellBridge(row, col);
    }

    @Override
    public int extendSelectionGestureToVisibleCell(int row, int col) {
        return TerminalNativeBridge.nativeExtendSelectionGestureToVisibleCellBridge(row, col);
    }

    @Override
    public int finishSelectionGesture() {
        return TerminalNativeBridge.nativeFinishSelectionGestureBridge();
    }

    @Override
    public int clearSelection() {
        return TerminalNativeBridge.nativeClearSelectionBridge();
    }

    @Override
    public int updateSelectionStartAtVisibleCell(int row, int col) {
        return TerminalNativeBridge.nativeUpdateSelectionStartAtVisibleCellBridge(row, col);
    }

    @Override
    public int updateSelectionEndAtVisibleCell(int row, int col) {
        return TerminalNativeBridge.nativeUpdateSelectionEndAtVisibleCellBridge(row, col);
    }

    @Override
    public boolean currentSelectionActive() {
        return TerminalNativeBridge.nativeCurrentSelectionActiveBridge();
    }

    @Override
    public int currentSelectionRectLeft() {
        return TerminalNativeBridge.nativeCurrentSelectionRectLeftBridge();
    }

    @Override
    public int currentSelectionRectTop() {
        return TerminalNativeBridge.nativeCurrentSelectionRectTopBridge();
    }

    @Override
    public int currentSelectionRectRight() {
        return TerminalNativeBridge.nativeCurrentSelectionRectRightBridge();
    }

    @Override
    public int currentSelectionRectBottom() {
        return TerminalNativeBridge.nativeCurrentSelectionRectBottomBridge();
    }

    @Override
    public int currentSelectionStartRectLeft() {
        return TerminalNativeBridge.nativeCurrentSelectionStartRectLeftBridge();
    }

    @Override
    public int currentSelectionStartRectTop() {
        return TerminalNativeBridge.nativeCurrentSelectionStartRectTopBridge();
    }

    @Override
    public int currentSelectionStartRectRight() {
        return TerminalNativeBridge.nativeCurrentSelectionStartRectRightBridge();
    }

    @Override
    public int currentSelectionStartRectBottom() {
        return TerminalNativeBridge.nativeCurrentSelectionStartRectBottomBridge();
    }

    @Override
    public int currentSelectionEndRectLeft() {
        return TerminalNativeBridge.nativeCurrentSelectionEndRectLeftBridge();
    }

    @Override
    public int currentSelectionEndRectTop() {
        return TerminalNativeBridge.nativeCurrentSelectionEndRectTopBridge();
    }

    @Override
    public int currentSelectionEndRectRight() {
        return TerminalNativeBridge.nativeCurrentSelectionEndRectRightBridge();
    }

    @Override
    public int currentSelectionEndRectBottom() {
        return TerminalNativeBridge.nativeCurrentSelectionEndRectBottomBridge();
    }

    @Override
    public byte[] currentSelectionTextBytes() {
        return TerminalNativeBridge.nativeCurrentSelectionTextBytesBridge();
    }

    @Override
    public int currentVisibleRows() {
        return TerminalNativeBridge.nativeCurrentSessionVisibleRowsBridge();
    }

    @Override
    public int currentVisibleCols() {
        return TerminalNativeBridge.nativeCurrentSessionVisibleColsBridge();
    }

    @Override
    public int currentScrollbackCount() {
        return TerminalNativeBridge.nativeCurrentSessionScrollbackCountBridge();
    }

    @Override
    public int currentScrollbackOffset() {
        return TerminalNativeBridge.nativeCurrentSessionScrollbackOffsetBridge();
    }

    @Override
    public int setShellScrollbackOffset(int offsetRows) {
        return TerminalNativeBridge.nativeSetSessionScrollbackOffsetBridge(offsetRows);
    }

    @Override
    public int followShellLiveBottom() {
        return TerminalNativeBridge.nativeFollowSessionLiveBottomBridge();
    }
}
