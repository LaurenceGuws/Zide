package uk.laurencegouws.terminal.host.interaction;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.IntBinaryOperator;
import java.util.function.IntSupplier;
import java.util.function.IntUnaryOperator;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.selection.TerminalSelectionControllerFactory;

/** Functional callback adapter for {@link TerminalSelectionControllerFactory}. */
public final class SelectionCallbacks implements TerminalSelectionControllerFactory.Host {
    private final IntSupplier productViewportWidthPx;
    private final IntSupplier productViewportHeightPx;
    private final Runnable stopScrollbackFling;
    private final Runnable refreshProductScrollOverlay;
    private final Runnable reevaluateProductFrameLoop;
    private final Consumer<String> appendEvent;
    private final BooleanSupplier nativeLoaded;
    private final IntBinaryOperator beginWordSelectionAtVisibleCell;
    private final IntBinaryOperator extendSelectionGestureToVisibleCell;
    private final IntSupplier finishSelectionGesture;
    private final IntSupplier clearSelection;
    private final IntBinaryOperator updateSelectionStartAtVisibleCell;
    private final IntBinaryOperator updateSelectionEndAtVisibleCell;
    private final BooleanSupplier currentSelectionActive;
    private final IntSupplier currentSelectionRectLeft;
    private final IntSupplier currentSelectionRectTop;
    private final IntSupplier currentSelectionRectRight;
    private final IntSupplier currentSelectionRectBottom;
    private final IntSupplier currentSelectionStartRectLeft;
    private final IntSupplier currentSelectionStartRectTop;
    private final IntSupplier currentSelectionStartRectRight;
    private final IntSupplier currentSelectionStartRectBottom;
    private final IntSupplier currentSelectionEndRectLeft;
    private final IntSupplier currentSelectionEndRectTop;
    private final IntSupplier currentSelectionEndRectRight;
    private final IntSupplier currentSelectionEndRectBottom;
    private final Supplier<byte[]> currentSelectionTextBytes;
    private final IntSupplier currentVisibleRows;
    private final IntSupplier currentVisibleCols;
    private final IntSupplier currentScrollbackCount;
    private final IntSupplier currentScrollbackOffset;
    private final IntUnaryOperator setShellScrollbackOffset;
    private final IntSupplier followShellLiveBottom;

    public SelectionCallbacks(
            IntSupplier productViewportWidthPx,
            IntSupplier productViewportHeightPx,
            Runnable stopScrollbackFling,
            Runnable refreshProductScrollOverlay,
            Runnable reevaluateProductFrameLoop,
            Consumer<String> appendEvent,
            BooleanSupplier nativeLoaded,
            IntBinaryOperator beginWordSelectionAtVisibleCell,
            IntBinaryOperator extendSelectionGestureToVisibleCell,
            IntSupplier finishSelectionGesture,
            IntSupplier clearSelection,
            IntBinaryOperator updateSelectionStartAtVisibleCell,
            IntBinaryOperator updateSelectionEndAtVisibleCell,
            BooleanSupplier currentSelectionActive,
            IntSupplier currentSelectionRectLeft,
            IntSupplier currentSelectionRectTop,
            IntSupplier currentSelectionRectRight,
            IntSupplier currentSelectionRectBottom,
            IntSupplier currentSelectionStartRectLeft,
            IntSupplier currentSelectionStartRectTop,
            IntSupplier currentSelectionStartRectRight,
            IntSupplier currentSelectionStartRectBottom,
            IntSupplier currentSelectionEndRectLeft,
            IntSupplier currentSelectionEndRectTop,
            IntSupplier currentSelectionEndRectRight,
            IntSupplier currentSelectionEndRectBottom,
            Supplier<byte[]> currentSelectionTextBytes,
            IntSupplier currentVisibleRows,
            IntSupplier currentVisibleCols,
            IntSupplier currentScrollbackCount,
            IntSupplier currentScrollbackOffset,
            IntUnaryOperator setShellScrollbackOffset,
            IntSupplier followShellLiveBottom) {
        this.productViewportWidthPx = productViewportWidthPx;
        this.productViewportHeightPx = productViewportHeightPx;
        this.stopScrollbackFling = stopScrollbackFling;
        this.refreshProductScrollOverlay = refreshProductScrollOverlay;
        this.reevaluateProductFrameLoop = reevaluateProductFrameLoop;
        this.appendEvent = appendEvent;
        this.nativeLoaded = nativeLoaded;
        this.beginWordSelectionAtVisibleCell = beginWordSelectionAtVisibleCell;
        this.extendSelectionGestureToVisibleCell = extendSelectionGestureToVisibleCell;
        this.finishSelectionGesture = finishSelectionGesture;
        this.clearSelection = clearSelection;
        this.updateSelectionStartAtVisibleCell = updateSelectionStartAtVisibleCell;
        this.updateSelectionEndAtVisibleCell = updateSelectionEndAtVisibleCell;
        this.currentSelectionActive = currentSelectionActive;
        this.currentSelectionRectLeft = currentSelectionRectLeft;
        this.currentSelectionRectTop = currentSelectionRectTop;
        this.currentSelectionRectRight = currentSelectionRectRight;
        this.currentSelectionRectBottom = currentSelectionRectBottom;
        this.currentSelectionStartRectLeft = currentSelectionStartRectLeft;
        this.currentSelectionStartRectTop = currentSelectionStartRectTop;
        this.currentSelectionStartRectRight = currentSelectionStartRectRight;
        this.currentSelectionStartRectBottom = currentSelectionStartRectBottom;
        this.currentSelectionEndRectLeft = currentSelectionEndRectLeft;
        this.currentSelectionEndRectTop = currentSelectionEndRectTop;
        this.currentSelectionEndRectRight = currentSelectionEndRectRight;
        this.currentSelectionEndRectBottom = currentSelectionEndRectBottom;
        this.currentSelectionTextBytes = currentSelectionTextBytes;
        this.currentVisibleRows = currentVisibleRows;
        this.currentVisibleCols = currentVisibleCols;
        this.currentScrollbackCount = currentScrollbackCount;
        this.currentScrollbackOffset = currentScrollbackOffset;
        this.setShellScrollbackOffset = setShellScrollbackOffset;
        this.followShellLiveBottom = followShellLiveBottom;
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
        return nativeLoaded.getAsBoolean();
    }

    @Override
    public int beginWordSelectionAtVisibleCell(int row, int col) {
        return beginWordSelectionAtVisibleCell.applyAsInt(row, col);
    }

    @Override
    public int extendSelectionGestureToVisibleCell(int row, int col) {
        return extendSelectionGestureToVisibleCell.applyAsInt(row, col);
    }

    @Override
    public int finishSelectionGesture() {
        return finishSelectionGesture.getAsInt();
    }

    @Override
    public int clearSelection() {
        return clearSelection.getAsInt();
    }

    @Override
    public int updateSelectionStartAtVisibleCell(int row, int col) {
        return updateSelectionStartAtVisibleCell.applyAsInt(row, col);
    }

    @Override
    public int updateSelectionEndAtVisibleCell(int row, int col) {
        return updateSelectionEndAtVisibleCell.applyAsInt(row, col);
    }

    @Override
    public boolean currentSelectionActive() {
        return currentSelectionActive.getAsBoolean();
    }

    @Override
    public int currentSelectionRectLeft() {
        return currentSelectionRectLeft.getAsInt();
    }

    @Override
    public int currentSelectionRectTop() {
        return currentSelectionRectTop.getAsInt();
    }

    @Override
    public int currentSelectionRectRight() {
        return currentSelectionRectRight.getAsInt();
    }

    @Override
    public int currentSelectionRectBottom() {
        return currentSelectionRectBottom.getAsInt();
    }

    @Override
    public int currentSelectionStartRectLeft() {
        return currentSelectionStartRectLeft.getAsInt();
    }

    @Override
    public int currentSelectionStartRectTop() {
        return currentSelectionStartRectTop.getAsInt();
    }

    @Override
    public int currentSelectionStartRectRight() {
        return currentSelectionStartRectRight.getAsInt();
    }

    @Override
    public int currentSelectionStartRectBottom() {
        return currentSelectionStartRectBottom.getAsInt();
    }

    @Override
    public int currentSelectionEndRectLeft() {
        return currentSelectionEndRectLeft.getAsInt();
    }

    @Override
    public int currentSelectionEndRectTop() {
        return currentSelectionEndRectTop.getAsInt();
    }

    @Override
    public int currentSelectionEndRectRight() {
        return currentSelectionEndRectRight.getAsInt();
    }

    @Override
    public int currentSelectionEndRectBottom() {
        return currentSelectionEndRectBottom.getAsInt();
    }

    @Override
    public byte[] currentSelectionTextBytes() {
        return currentSelectionTextBytes.get();
    }

    @Override
    public int currentVisibleRows() {
        return currentVisibleRows.getAsInt();
    }

    @Override
    public int currentVisibleCols() {
        return currentVisibleCols.getAsInt();
    }

    @Override
    public int currentScrollbackCount() {
        return currentScrollbackCount.getAsInt();
    }

    @Override
    public int currentScrollbackOffset() {
        return currentScrollbackOffset.getAsInt();
    }

    @Override
    public int setShellScrollbackOffset(int offsetRows) {
        return setShellScrollbackOffset.applyAsInt(offsetRows);
    }

    @Override
    public int followShellLiveBottom() {
        return followShellLiveBottom.getAsInt();
    }
}
