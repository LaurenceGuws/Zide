package dev.zide.terminal.host.interaction;

import dev.zide.terminal.selection.TerminalSelectionController;

/**
 * Adapts activity native callbacks to the selection bridge contract.
 */
public final class SelectionBridge implements TerminalSelectionController.Bridge {
    /** Native callbacks required by selection interaction. */
    public interface Callbacks {
        boolean nativeLoaded();

        int beginWordSelectionAtVisibleCell(int row, int col);

        int extendSelectionGestureToVisibleCell(int row, int col);

        int finishSelectionGesture();

        int clearSelection();

        int updateSelectionStartAtVisibleCell(int row, int col);

        int updateSelectionEndAtVisibleCell(int row, int col);

        boolean currentSelectionActive();

        int currentSelectionRectLeft();

        int currentSelectionRectTop();

        int currentSelectionRectRight();

        int currentSelectionRectBottom();

        int currentSelectionStartRectLeft();

        int currentSelectionStartRectTop();

        int currentSelectionStartRectRight();

        int currentSelectionStartRectBottom();

        int currentSelectionEndRectLeft();

        int currentSelectionEndRectTop();

        int currentSelectionEndRectRight();

        int currentSelectionEndRectBottom();

        byte[] currentSelectionTextBytes();

        int currentVisibleRows();

        int currentVisibleCols();

        int currentScrollbackCount();

        int currentScrollbackOffset();

        int setShellScrollbackOffset(int offsetRows);

        int followShellLiveBottom();
    }

    private final Callbacks callbacks;

    public SelectionBridge(Callbacks callbacks) {
        this.callbacks = callbacks;
    }

    @Override
    public boolean nativeLoaded() {
        return callbacks.nativeLoaded();
    }

    @Override
    public int beginWordSelectionAtVisibleCell(int row, int col) {
        return callbacks.beginWordSelectionAtVisibleCell(row, col);
    }

    @Override
    public int extendSelectionGestureToVisibleCell(int row, int col) {
        return callbacks.extendSelectionGestureToVisibleCell(row, col);
    }

    @Override
    public int finishSelectionGesture() {
        return callbacks.finishSelectionGesture();
    }

    @Override
    public int clearSelection() {
        return callbacks.clearSelection();
    }

    @Override
    public int updateSelectionStartAtVisibleCell(int row, int col) {
        return callbacks.updateSelectionStartAtVisibleCell(row, col);
    }

    @Override
    public int updateSelectionEndAtVisibleCell(int row, int col) {
        return callbacks.updateSelectionEndAtVisibleCell(row, col);
    }

    @Override
    public boolean currentSelectionActive() {
        return callbacks.currentSelectionActive();
    }

    @Override
    public int currentSelectionRectLeft() {
        return callbacks.currentSelectionRectLeft();
    }

    @Override
    public int currentSelectionRectTop() {
        return callbacks.currentSelectionRectTop();
    }

    @Override
    public int currentSelectionRectRight() {
        return callbacks.currentSelectionRectRight();
    }

    @Override
    public int currentSelectionRectBottom() {
        return callbacks.currentSelectionRectBottom();
    }

    @Override
    public int currentSelectionStartRectLeft() {
        return callbacks.currentSelectionStartRectLeft();
    }

    @Override
    public int currentSelectionStartRectTop() {
        return callbacks.currentSelectionStartRectTop();
    }

    @Override
    public int currentSelectionStartRectRight() {
        return callbacks.currentSelectionStartRectRight();
    }

    @Override
    public int currentSelectionStartRectBottom() {
        return callbacks.currentSelectionStartRectBottom();
    }

    @Override
    public int currentSelectionEndRectLeft() {
        return callbacks.currentSelectionEndRectLeft();
    }

    @Override
    public int currentSelectionEndRectTop() {
        return callbacks.currentSelectionEndRectTop();
    }

    @Override
    public int currentSelectionEndRectRight() {
        return callbacks.currentSelectionEndRectRight();
    }

    @Override
    public int currentSelectionEndRectBottom() {
        return callbacks.currentSelectionEndRectBottom();
    }

    @Override
    public byte[] currentSelectionTextBytes() {
        return callbacks.currentSelectionTextBytes();
    }

    @Override
    public int currentVisibleRows() {
        return callbacks.currentVisibleRows();
    }

    @Override
    public int currentVisibleCols() {
        return callbacks.currentVisibleCols();
    }

    @Override
    public int currentScrollbackCount() {
        return callbacks.currentScrollbackCount();
    }

    @Override
    public int currentScrollbackOffset() {
        return callbacks.currentScrollbackOffset();
    }

    @Override
    public int setShellScrollbackOffset(int offsetRows) {
        return callbacks.setShellScrollbackOffset(offsetRows);
    }

    @Override
    public int followShellLiveBottom() {
        return callbacks.followShellLiveBottom();
    }
}
