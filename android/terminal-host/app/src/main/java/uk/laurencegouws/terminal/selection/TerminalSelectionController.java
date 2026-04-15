package uk.laurencegouws.terminal.selection;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Rect;
import android.graphics.drawable.GradientDrawable;
import android.view.ActionMode;
import android.view.Choreographer;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.widget.FrameLayout;

/**
 * Owns Android-native terminal selection interaction.
 *
 * <p>This controller keeps selection mutation, helper chrome, and handle drag policy out of the
 * activity. The shared terminal core still owns selection truth; this controller only translates
 * Android-native interaction into that bridge.
 */
public final class TerminalSelectionController {
    /** Host-owned Android surfaces and product callbacks needed by selection interaction. */
    public interface Host {
        Context context();

        FrameLayout productSurfaceContainer();

        int productViewportWidthPx();

        int productViewportHeightPx();

        void stopScrollbackFling();

        void refreshProductScrollOverlay();

        void reevaluateProductFrameLoop();

        void appendEvent(String event);
    }

    /** Native bridge contract needed by Android selection interaction. */
    public interface Bridge {
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

    private static final float SELECTION_AUTOSCROLL_BAND_DP = 120.0f;
    private static final float SELECTION_AUTOSCROLL_MAX_ROWS_PER_SECOND = 28.0f;
    private static final float SELECTION_AUTOSCROLL_MIN_ROWS_PER_SECOND = 4.0f;
    private static final float SELECTION_AUTOSCROLL_IMMEDIATE_STEP_SECONDS = 1.0f / 60.0f;
    private static final float SELECTION_HANDLE_SIZE_DP = 18.0f;
    private static final float SELECTION_HANDLE_Y_OFFSET_DP = 6.0f;

    private final Host host;
    private final Bridge bridge;
    private View selectionStartHandle;
    private View selectionEndHandle;
    private ActionMode terminalSelectionActionMode;
    private boolean selectionHelpersVisible = true;
    private boolean selectionToolbarVisible = true;
    private boolean suppressSelectionClearOnActionModeDestroy = false;
    private boolean selectionDragActive = false;
    private boolean selectionDragCommitted = false;
    private boolean selectionAutoscrollScheduled = false;
    private float selectionDragX = 0.0f;
    private float selectionDragY = 0.0f;
    private float selectionDragDownX = 0.0f;
    private float selectionDragDownY = 0.0f;
    private long selectionAutoscrollLastFrameNanos = 0L;
    private SelectionDragMode selectionDragMode = SelectionDragMode.none;
    private TerminalCellHit selectionDragAnchorCell;
    private View selectionDraggedHandleView;
    private float selectionDraggedHandleTouchOffsetX = 0.0f;
    private float selectionDraggedHandleTouchOffsetY = 0.0f;
    private float activeGestureScrollRemainderRows = 0.0f;
    private final Choreographer.FrameCallback selectionAutoscrollFrameCallback;

    private enum SelectionDragMode {
        none,
        gesture,
        startHandle,
        endHandle,
    }

    private static final class TerminalCellHit {
        final int row;
        final int col;

        TerminalCellHit(int row, int col) {
            this.row = row;
            this.col = col;
        }
    }

    private static final class AnchorPoint {
        final float x;
        final float y;

        AnchorPoint(float x, float y) {
            this.x = x;
            this.y = y;
        }

        static AnchorPoint of(float x, float y) {
            return new AnchorPoint(x, y);
        }
    }

    private static final class ViewportGridMetrics {
        final int visibleRows;
        final int visibleCols;
        final int viewportWidth;
        final int viewportHeight;
        final float colWidthPx;
        final float rowHeightPx;

        ViewportGridMetrics(
                int visibleRows,
                int visibleCols,
                int viewportWidth,
                int viewportHeight,
                float colWidthPx,
                float rowHeightPx) {
            this.visibleRows = visibleRows;
            this.visibleCols = visibleCols;
            this.viewportWidth = viewportWidth;
            this.viewportHeight = viewportHeight;
            this.colWidthPx = colWidthPx;
            this.rowHeightPx = rowHeightPx;
        }
    }

    public TerminalSelectionController(Host host, Bridge bridge) {
        this.host = host;
        this.bridge = bridge;
        this.selectionAutoscrollFrameCallback = this::onSelectionAutoscrollFrame;
    }

    /** Installs Android-owned selection handles into the product surface container. */
    public void install() {
        selectionStartHandle = createSelectionHandleView(SelectionDragMode.startHandle);
        selectionEndHandle = createSelectionHandleView(SelectionDragMode.endHandle);
        host.productSurfaceContainer().addView(selectionStartHandle);
        host.productSurfaceContainer().addView(selectionEndHandle);
        selectionStartHandle.setVisibility(View.GONE);
        selectionEndHandle.setVisibility(View.GONE);
    }

    /** Keeps selection chrome aligned after viewport/scrollback changes. */
    public void syncChrome() {
        syncSelectionChrome();
    }

    /** Keeps handles above the terminal surface when the surface host is recreated. */
    public void bringToFront() {
        if (selectionStartHandle != null) {
            selectionStartHandle.bringToFront();
        }
        if (selectionEndHandle != null) {
            selectionEndHandle.bringToFront();
        }
    }

    public void onProductSingleTap(float x, float y) {
        if (!canHandleSelectionTap()) {
            return;
        }
        if (tapHitsCurrentSelection(x, y)) {
            toggleSelectionHelpers();
            host.appendEvent("product.selection.tap result=inside");
            return;
        }
        bridge.clearSelection();
        selectionHelpersVisible = true;
        selectionToolbarVisible = true;
        finishTerminalSelectionActionMode();
        requestFrameLoopReevaluation();
        host.appendEvent("product.selection.cleared reason=tap-outside");
    }

    public void onProductLongPress(float x, float y) {
        if (!isBridgeReady()) {
            return;
        }
        final TerminalCellHit hit = resolveProductTerminalCell(x, y);
        if (hit == null) {
            host.appendEvent("product.selection.long_press result=miss");
            return;
        }
        host.stopScrollbackFling();
        final int status = bridge.beginWordSelectionAtVisibleCell(hit.row, hit.col);
        host.appendEvent("product.selection.word row=" + hit.row + " col=" + hit.col + " status=" + status);
        if (status == 0) {
            beginSelectionDrag(SelectionDragMode.gesture, x, y);
            hideSelectionToolbar();
        }
        requestFrameLoopReevaluation();
    }

    public void onProductSelectionDrag(float x, float y) {
        if (!canHandleSelectionDrag()) {
            return;
        }
        final int status = updateSelectionFromPoint(x, y);
        if (status == 0) {
            onSelectionUpdateSuccessDuringDrag();
        }
    }

    public void onProductSelectionDragEnd(float x, float y) {
        if (!canHandleSelectionDrag()) {
            return;
        }
        final int status = updateSelectionFromPoint(x, y);
        if (status == 0) {
            onSelectionUpdateSuccess();
        }
        if (selectionDragMode == SelectionDragMode.gesture) {
            bridge.finishSelectionGesture();
        }
        completeSelectionDragInteraction();
    }

    private View createSelectionHandleView(SelectionDragMode dragMode) {
        final int sizePx = Math.max(1, Math.round(SELECTION_HANDLE_SIZE_DP * host.context().getResources().getDisplayMetrics().density));
        final View handle = new View(host.context());
        final GradientDrawable background = new GradientDrawable();
        background.setShape(GradientDrawable.OVAL);
        background.setColor(Color.parseColor("#d7ecff"));
        background.setStroke(Math.max(1, sizePx / 12), Color.parseColor("#35566f"));
        handle.setBackground(background);
        handle.setAlpha(0.95f);
        final FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(sizePx, sizePx);
        params.gravity = Gravity.TOP | Gravity.START;
        handle.setLayoutParams(params);
        handle.setOnTouchListener((view, event) -> onSelectionHandleTouch(dragMode, view, event));
        return handle;
    }

    private boolean onSelectionHandleTouch(SelectionDragMode dragMode, View handle, MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                host.stopScrollbackFling();
                selectionDraggedHandleView = handle;
                selectionDraggedHandleTouchOffsetX = event.getX();
                selectionDraggedHandleTouchOffsetY = event.getY();
                beginSelectionDrag(dragMode, selectionHandleAnchorX(handle), selectionHandleAnchorY(handle));
                syncSelectionChrome();
                requestFrameLoopReevaluation();
                return true;
            case MotionEvent.ACTION_MOVE:
                positionDraggedHandle(handle, handle.getX() + event.getX(), handle.getY() + event.getY());
                final AnchorPoint moveAnchor = currentDraggedHandleAnchor(handle);
                if (!commitSelectionDragIfNeeded(moveAnchor.x, moveAnchor.y)) {
                    return true;
                }
                if (updateSelectionFromPoint(moveAnchor.x, moveAnchor.y) == 0) {
                    onSelectionUpdateSuccessDuringDrag();
                }
                return true;
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_CANCEL:
                if (selectionDragCommitted) {
                    positionDraggedHandle(handle, handle.getX() + event.getX(), handle.getY() + event.getY());
                    final AnchorPoint releaseAnchor = currentDraggedHandleAnchor(handle);
                    if (updateSelectionFromPoint(releaseAnchor.x, releaseAnchor.y) == 0) {
                        onSelectionUpdateSuccess();
                    }
                }
                completeSelectionDragInteraction();
                return true;
            default:
                return false;
        }
    }

    private TerminalCellHit resolveProductTerminalCell(float x, float y) {
        if (!isBridgeReady()) {
            return null;
        }
        final ViewportGridMetrics grid = currentViewportGridMetrics();
        if (grid == null) {
            return null;
        }
        final float clampedX = Math.max(0.0f, Math.min(x, grid.viewportWidth - 1.0f));
        final float clampedY = Math.max(0.0f, Math.min(y, grid.viewportHeight - 1.0f));
        final int col = clampInt((int) (clampedX / grid.colWidthPx), 0, grid.visibleCols - 1);
        final int row = clampInt((int) (clampedY / grid.rowHeightPx), 0, grid.visibleRows - 1);
        return new TerminalCellHit(row, col);
    }

    private void beginSelectionDrag(SelectionDragMode dragMode, float x, float y) {
        selectionDragMode = dragMode;
        selectionDragActive = true;
        selectionDragCommitted = false;
        selectionDragDownX = x;
        selectionDragDownY = y;
        selectionAutoscrollLastFrameNanos = 0L;
        selectionDragAnchorCell = selectionDragAnchorCellForMode(dragMode);
        updateSelectionDragPoint(x, y);
        hideSelectionToolbar();
    }

    private void endSelectionDrag() {
        selectionDragActive = false;
        selectionDragCommitted = false;
        selectionAutoscrollLastFrameNanos = 0L;
        selectionDragMode = SelectionDragMode.none;
        selectionDragAnchorCell = null;
        selectionDragDownX = 0.0f;
        selectionDragDownY = 0.0f;
        selectionDraggedHandleView = null;
        selectionDraggedHandleTouchOffsetX = 0.0f;
        selectionDraggedHandleTouchOffsetY = 0.0f;
    }

    private void completeSelectionDragInteraction() {
        endSelectionDrag();
        showSelectionToolbar();
        requestFrameLoopReevaluation();
    }

    private void syncSelectionChromeAndReevaluateFrameLoop() {
        syncSelectionChrome();
        requestFrameLoopReevaluation();
    }

    private void onSelectionUpdateSuccess() {
        syncSelectionChrome();
    }

    private void onSelectionUpdateSuccessDuringDrag() {
        applyImmediateSelectionAutoscrollStep();
        syncSelectionChromeAndReevaluateFrameLoop();
    }

    private boolean canHandleSelectionTap() {
        return isBridgeReady() && bridge.currentSelectionActive();
    }

    private boolean canHandleSelectionDrag() {
        return isBridgeReady() && bridge.currentSelectionActive();
    }

    private boolean commitSelectionDragIfNeeded(float x, float y) {
        if (!selectionDragActive) {
            return false;
        }
        if (selectionDragCommitted) {
            return true;
        }
        final int slop = ViewConfiguration.get(host.context()).getScaledTouchSlop();
        if (Math.hypot(x - selectionDragDownX, y - selectionDragDownY) < slop) {
            return false;
        }
        selectionDragCommitted = true;
        return true;
    }

    private void updateSelectionDragPoint(float x, float y) {
        selectionDragX = x;
        selectionDragY = y;
        if (!selectionDragActive) {
            return;
        }
        if (computeSelectionAutoscrollRowsPerSecond(y) != 0.0f) {
            scheduleSelectionAutoscrollFrame();
        }
    }

    private int updateSelectionFromPoint(float x, float y) {
        updateSelectionDragPoint(x, y);
        return updateSelectionFromActiveDrag();
    }

    private int updateSelectionFromActiveDrag() {
        if (!selectionDragActive || selectionDragMode == SelectionDragMode.none) {
            return -1;
        }
        final TerminalCellHit hit = resolveProductTerminalCell(selectionDragX, selectionDragY);
        if (hit == null) {
            return -1;
        }
        switch (selectionDragMode) {
            case gesture:
                return bridge.extendSelectionGestureToVisibleCell(hit.row, hit.col);
            case startHandle:
            case endHandle:
                return updateSelectionPairFromHandleDrag(hit);
            default:
                return -1;
        }
    }

    private int updateSelectionPairFromHandleDrag(TerminalCellHit hit) {
        final TerminalCellHit anchor = selectionDragAnchorCell;
        if (anchor == null) {
            return -1;
        }
        final TerminalCellHit nextStart;
        final TerminalCellHit nextEnd;
        if (selectionDragMode == SelectionDragMode.startHandle) {
            if (selectionCellBefore(hit, anchor) || selectionCellEquals(hit, anchor)) {
                nextStart = hit;
                nextEnd = anchor;
            } else {
                nextStart = offsetVisibleCell(anchor, 1);
                nextEnd = hit;
            }
        } else {
            if (selectionCellBefore(anchor, hit) || selectionCellEquals(anchor, hit)) {
                nextStart = anchor;
                nextEnd = hit;
            } else {
                nextStart = hit;
                nextEnd = offsetVisibleCell(anchor, -1);
            }
        }
        final int startStatus = bridge.updateSelectionStartAtVisibleCell(nextStart.row, nextStart.col);
        if (startStatus != 0) {
            return startStatus;
        }
        return bridge.updateSelectionEndAtVisibleCell(nextEnd.row, nextEnd.col);
    }

    private TerminalCellHit selectionDragAnchorCellForMode(SelectionDragMode dragMode) {
        if (dragMode != SelectionDragMode.startHandle && dragMode != SelectionDragMode.endHandle) {
            return null;
        }
        return currentSelectionEndpointCell(dragMode == SelectionDragMode.endHandle);
    }

    private TerminalCellHit currentSelectionEndpointCell(boolean startHandle) {
        final Rect rect = populateSelectionEndpointRectRaw(startHandle);
        if (rect == null || rect.isEmpty()) {
            return null;
        }
        final ViewportGridMetrics grid = currentViewportGridMetrics();
        if (grid == null) {
            return null;
        }
        final int row = clampInt((int) (rect.top / grid.rowHeightPx), 0, grid.visibleRows - 1);
        final int col = startHandle
                ? clampInt((int) (rect.left / grid.colWidthPx), 0, grid.visibleCols - 1)
                : clampInt((int) (Math.max(rect.right - 1, 0) / grid.colWidthPx), 0, grid.visibleCols - 1);
        return new TerminalCellHit(row, col);
    }

    private ViewportGridMetrics currentViewportGridMetrics() {
        final int visibleRows = bridge.currentVisibleRows();
        final int visibleCols = bridge.currentVisibleCols();
        final int viewportWidth = host.productViewportWidthPx();
        final int viewportHeight = host.productViewportHeightPx();
        if (visibleRows <= 0 || visibleCols <= 0 || viewportWidth <= 0 || viewportHeight <= 0) {
            return null;
        }
        final float colWidthPx = (float) viewportWidth / (float) visibleCols;
        final float rowHeightPx = (float) viewportHeight / (float) visibleRows;
        if (!(colWidthPx > 0.0f) || !(rowHeightPx > 0.0f)) {
            return null;
        }
        return viewportGridMetrics(
                visibleRows,
                visibleCols,
                viewportWidth,
                viewportHeight,
                colWidthPx,
                rowHeightPx);
    }

    private static boolean selectionCellBefore(TerminalCellHit a, TerminalCellHit b) {
        if (a.row < b.row) {
            return true;
        }
        if (a.row > b.row) {
            return false;
        }
        return a.col < b.col;
    }

    private static boolean selectionCellEquals(TerminalCellHit a, TerminalCellHit b) {
        return a.row == b.row && a.col == b.col;
    }

    private TerminalCellHit offsetVisibleCell(TerminalCellHit cell, int delta) {
        final int visibleRows = bridge.currentVisibleRows();
        final int visibleCols = bridge.currentVisibleCols();
        if (cell == null || visibleRows <= 0 || visibleCols <= 0) {
            return cell;
        }
        final int totalCells = visibleRows * visibleCols;
        if (totalCells <= 0) {
            return cell;
        }
        final int index = clampInt((cell.row * visibleCols) + cell.col, 0, totalCells - 1);
        final int shifted = clampInt(index + delta, 0, totalCells - 1);
        return new TerminalCellHit(shifted / visibleCols, shifted % visibleCols);
    }

    private void scheduleSelectionAutoscrollFrame() {
        if (selectionAutoscrollScheduled) {
            return;
        }
        selectionAutoscrollScheduled = true;
        Choreographer.getInstance().postFrameCallback(selectionAutoscrollFrameCallback);
    }

    private float computeSelectionAutoscrollRowsPerSecond(float y) {
        final int visibleRows = bridge.currentVisibleRows();
        final int viewportHeight = host.productViewportHeightPx();
        if (viewportHeight <= 0 || visibleRows <= 0) {
            return 0.0f;
        }
        final float rowHeightPx = (float) viewportHeight / (float) visibleRows;
        final float bandPx = SELECTION_AUTOSCROLL_BAND_DP * host.context().getResources().getDisplayMetrics().density;
        if (!(bandPx > 0.0f) || !(rowHeightPx > 0.0f)) {
            return 0.0f;
        }
        final float topTriggerY = rowHeightPx;
        final float bottomTriggerY = viewportHeight - rowHeightPx;
        final float triggerRangePx = bandPx + rowHeightPx;
        if (y <= topTriggerY) {
            final float distance = Math.min((topTriggerY - y) + rowHeightPx, triggerRangePx);
            final float normalized = distance / triggerRangePx;
            return lerp(
                    SELECTION_AUTOSCROLL_MIN_ROWS_PER_SECOND,
                    SELECTION_AUTOSCROLL_MAX_ROWS_PER_SECOND,
                    normalized * normalized);
        }
        if (y >= bottomTriggerY) {
            final float distance = Math.min((y - bottomTriggerY) + rowHeightPx, triggerRangePx);
            final float normalized = distance / triggerRangePx;
            return -lerp(
                    SELECTION_AUTOSCROLL_MIN_ROWS_PER_SECOND,
                    SELECTION_AUTOSCROLL_MAX_ROWS_PER_SECOND,
                    normalized * normalized);
        }
        return 0.0f;
    }

    private void onSelectionAutoscrollFrame(long frameTimeNanos) {
        selectionAutoscrollScheduled = false;
        if (!selectionDragActive || !bridge.nativeLoaded()) {
            selectionAutoscrollLastFrameNanos = 0L;
            return;
        }
        final float rowsPerSecond = currentSelectionAutoscrollRowsPerSecond();
        if (rowsPerSecond == 0.0f) {
            selectionAutoscrollLastFrameNanos = 0L;
            return;
        }
        final float deltaSeconds = resolveSelectionAutoscrollDeltaSeconds(frameTimeNanos);
        applySelectionAutoscrollRows(rowsPerSecond * deltaSeconds);
        if (shouldContinueSelectionAutoscroll()) {
            scheduleSelectionAutoscrollFrame();
            return;
        }
        selectionAutoscrollLastFrameNanos = 0L;
    }

    private float currentSelectionAutoscrollRowsPerSecond() {
        return computeSelectionAutoscrollRowsPerSecond(selectionDragY);
    }

    private float resolveSelectionAutoscrollDeltaSeconds(long frameTimeNanos) {
        final long previousFrameNanos = selectionAutoscrollLastFrameNanos;
        selectionAutoscrollLastFrameNanos = frameTimeNanos;
        if (previousFrameNanos == 0L) {
            return SELECTION_AUTOSCROLL_IMMEDIATE_STEP_SECONDS;
        }
        return Math.max(1.0e-3f, Math.min(0.05f, (frameTimeNanos - previousFrameNanos) / 1_000_000_000.0f));
    }

    private void applyImmediateSelectionAutoscrollStep() {
        final float rowsPerSecond = computeSelectionAutoscrollRowsPerSecond(selectionDragY);
        if (rowsPerSecond == 0.0f) {
            return;
        }
        applySelectionAutoscrollRows(rowsPerSecond * SELECTION_AUTOSCROLL_IMMEDIATE_STEP_SECONDS);
        if (shouldContinueSelectionAutoscroll()) {
            scheduleSelectionAutoscrollFrame();
        }
    }

    private boolean shouldContinueSelectionAutoscroll() {
        return selectionDragActive && currentSelectionAutoscrollRowsPerSecond() != 0.0f;
    }

    private static float lerp(float start, float end, float t) {
        return start + ((end - start) * t);
    }

    private static int clampInt(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private static ViewportGridMetrics viewportGridMetrics(
            int visibleRows,
            int visibleCols,
            int viewportWidth,
            int viewportHeight,
            float colWidthPx,
            float rowHeightPx) {
        return new ViewportGridMetrics(
                visibleRows,
                visibleCols,
                viewportWidth,
                viewportHeight,
                colWidthPx,
                rowHeightPx);
    }

    private boolean isBridgeReady() {
        return bridge.nativeLoaded();
    }

    private void applySelectionAutoscrollRows(float rowDelta) {
        if (!selectionDragActive || rowDelta == 0.0f) {
            return;
        }
        activeGestureScrollRemainderRows += rowDelta;
        final int wholeRows = (int) activeGestureScrollRemainderRows;
        if (wholeRows == 0) {
            return;
        }
        activeGestureScrollRemainderRows -= wholeRows;
        final int nextOffset = resolveSelectionAutoscrollOffset(wholeRows);
        if (nextOffset < 0) {
            return;
        }
        applySelectionAutoscrollOffset(nextOffset);
        final int status = updateSelectionFromActiveDrag();
        if (status == 0) {
            onSelectionUpdateSuccess();
        }
        host.refreshProductScrollOverlay();
        requestFrameLoopReevaluation();
    }

    private int resolveSelectionAutoscrollOffset(int wholeRows) {
        final int scrollbackCount = bridge.currentScrollbackCount();
        final int scrollbackOffset = bridge.currentScrollbackOffset();
        final int nextOffset = clampInt(scrollbackOffset + wholeRows, 0, scrollbackCount);
        return nextOffset == scrollbackOffset ? -1 : nextOffset;
    }

    private void applySelectionAutoscrollOffset(int nextOffset) {
        if (nextOffset == 0) {
            bridge.followShellLiveBottom();
            return;
        }
        bridge.setShellScrollbackOffset(nextOffset);
    }

    private boolean tapHitsCurrentSelection(float x, float y) {
        final Rect rect = new Rect();
        if (!populateTerminalSelectionContentRect(rect)) {
            return false;
        }
        final int tapX = Math.round(x);
        final int tapY = Math.round(y);
        return rect.contains(tapX, tapY);
    }

    private void hideSelectionToolbar() {
        selectionToolbarVisible = false;
        syncSelectionChrome();
    }

    private void showSelectionToolbar() {
        selectionToolbarVisible = selectionHelpersVisible;
        syncSelectionChrome();
    }

    private void toggleSelectionHelpers() {
        selectionHelpersVisible = !selectionHelpersVisible;
        selectionToolbarVisible = selectionHelpersVisible && !selectionDragActive;
        syncSelectionChrome();
    }

    private void syncSelectionChrome() {
        syncTerminalSelectionActionMode();
    }

    private void showTerminalSelectionActionMode() {
        syncSelectionHandles();
        if (!selectionToolbarVisible) {
            return;
        }
        if (!bridge.currentSelectionActive() || host.productSurfaceContainer() == null) {
            finishTerminalSelectionActionMode();
            return;
        }
        if (terminalSelectionActionMode != null) {
            terminalSelectionActionMode.invalidateContentRect();
            terminalSelectionActionMode.invalidate();
            return;
        }
        terminalSelectionActionMode = host.productSurfaceContainer().startActionMode(
                new ActionMode.Callback2() {
                    @Override
                    public boolean onCreateActionMode(ActionMode mode, Menu menu) {
                        menu.add(Menu.NONE, android.R.id.copy, Menu.NONE, android.R.string.copy)
                                .setShowAsAction(MenuItem.SHOW_AS_ACTION_IF_ROOM);
                        return true;
                    }

                    @Override
                    public boolean onPrepareActionMode(ActionMode mode, Menu menu) {
                        return false;
                    }

                    @Override
                    public boolean onActionItemClicked(ActionMode mode, MenuItem item) {
                        if (item.getItemId() == android.R.id.copy) {
                            copyCurrentShellSelectionToClipboard();
                            mode.finish();
                            return true;
                        }
                        return false;
                    }

                    @Override
                    public void onDestroyActionMode(ActionMode mode) {
                        if (terminalSelectionActionMode == mode) {
                            terminalSelectionActionMode = null;
                        }
                        if (!suppressSelectionClearOnActionModeDestroy) {
                            bridge.clearSelection();
                        }
                        suppressSelectionClearOnActionModeDestroy = false;
                        requestFrameLoopReevaluation();
                    }

                    @Override
                    public void onGetContentRect(ActionMode mode, View view, Rect outRect) {
                        if (!populateTerminalSelectionContentRect(outRect)) {
                            outRect.set(0, 0, Math.max(view.getWidth(), 1), Math.max(view.getHeight(), 1));
                        }
                    }
                },
                ActionMode.TYPE_FLOATING);
        if (terminalSelectionActionMode != null) {
            terminalSelectionActionMode.invalidateContentRect();
        }
    }

    private void finishTerminalSelectionActionMode() {
        syncSelectionHandles();
        if (terminalSelectionActionMode == null) {
            return;
        }
        final ActionMode mode = terminalSelectionActionMode;
        terminalSelectionActionMode = null;
        suppressSelectionClearOnActionModeDestroy = true;
        mode.finish();
    }

    private boolean populateTerminalSelectionContentRect(Rect outRect) {
        if (!canHandleSelectionDrag()) {
            return false;
        }
        final int left = bridge.currentSelectionRectLeft();
        final int top = bridge.currentSelectionRectTop();
        final int right = bridge.currentSelectionRectRight();
        final int bottom = bridge.currentSelectionRectBottom();
        if (right <= left || bottom <= top) {
            return false;
        }
        return clampRectToViewport(left, top, right, bottom, outRect);
    }

    private void syncTerminalSelectionActionMode() {
        syncSelectionHandles();
        if (!selectionToolbarVisible) {
            if (terminalSelectionActionMode != null) {
                finishTerminalSelectionActionMode();
            }
            return;
        }
        if (terminalSelectionActionMode == null) {
            if (bridge.currentSelectionActive()) {
                showTerminalSelectionActionMode();
            }
            return;
        }
        if (!bridge.currentSelectionActive()) {
            finishTerminalSelectionActionMode();
            return;
        }
        terminalSelectionActionMode.invalidateContentRect();
    }

    private void syncSelectionHandles() {
        if (selectionStartHandle == null || selectionEndHandle == null) {
            return;
        }
        if (!canHandleSelectionDrag()) {
            hideSelectionHandle(selectionStartHandle);
            hideSelectionHandle(selectionEndHandle);
            return;
        }
        if (!selectionHelpersVisible && !selectionDragActive) {
            hideSelectionHandle(selectionStartHandle);
            hideSelectionHandle(selectionEndHandle);
            return;
        }
        if (selectionDragMode == SelectionDragMode.startHandle || selectionDragMode == SelectionDragMode.endHandle) {
            return;
        }
        bringToFront();
        syncSelectionHandle(selectionStartHandle, true);
        syncSelectionHandle(selectionEndHandle, false);
    }

    private void positionDraggedHandle(View handle, float absoluteX, float absoluteY) {
        if (handle == null || handle != selectionDraggedHandleView) {
            return;
        }
        final int viewportWidth = host.productViewportWidthPx();
        final int viewportHeight = host.productViewportHeightPx();
        final float maxX = Math.max(0.0f, viewportWidth - handle.getWidth());
        final float maxY = Math.max(0.0f, viewportHeight - handle.getHeight());
        handle.setX(Math.max(0.0f, Math.min(maxX, absoluteX - selectionDraggedHandleTouchOffsetX)));
        handle.setY(Math.max(0.0f, Math.min(maxY, absoluteY - selectionDraggedHandleTouchOffsetY)));
        showSelectionHandle(handle);
    }

    private float selectionHandleAnchorX(View handle) {
        return handle.getX() + (handle.getWidth() / 2.0f);
    }

    private float selectionHandleAnchorY(View handle) {
        final float offsetY = SELECTION_HANDLE_Y_OFFSET_DP * host.context().getResources().getDisplayMetrics().density;
        return (handle.getY() + (handle.getHeight() / 2.0f)) - offsetY;
    }

    private AnchorPoint currentDraggedHandleAnchor(View handle) {
        return AnchorPoint.of(selectionHandleAnchorX(handle), selectionHandleAnchorY(handle));
    }

    private void syncSelectionHandle(View handle, boolean startHandle) {
        final Rect rect = populateSelectionEndpointRectRaw(startHandle);
        if (rect == null || rect.isEmpty()) {
            hideSelectionHandle(handle);
            return;
        }
        final float radius = handle.getLayoutParams().width / 2.0f;
        final float offsetY = SELECTION_HANDLE_Y_OFFSET_DP * host.context().getResources().getDisplayMetrics().density;
        final float anchorX = startHandle ? rect.left : rect.right;
        handle.setX(anchorX - radius);
        handle.setY((rect.bottom - radius) + offsetY);
        showSelectionHandle(handle);
    }

    private void showSelectionHandle(View handle) {
        handle.animate().cancel();
        handle.bringToFront();
        handle.setAlpha(0.95f);
        handle.setVisibility(View.VISIBLE);
    }

    private void hideSelectionHandle(View handle) {
        handle.animate().cancel();
        handle.setAlpha(0.0f);
        handle.setVisibility(View.GONE);
    }

    private Rect populateSelectionEndpointRectRaw(boolean startHandle) {
        final int left = startHandle ? bridge.currentSelectionStartRectLeft() : bridge.currentSelectionEndRectLeft();
        final int top = startHandle ? bridge.currentSelectionStartRectTop() : bridge.currentSelectionEndRectTop();
        final int right = startHandle ? bridge.currentSelectionStartRectRight() : bridge.currentSelectionEndRectRight();
        final int bottom = startHandle ? bridge.currentSelectionStartRectBottom() : bridge.currentSelectionEndRectBottom();
        if (right <= left || bottom <= top) {
            return null;
        }
        final Rect rect = new Rect();
        return clampRectToViewport(left, top, right, bottom, rect) ? rect : null;
    }

    private boolean clampRectToViewport(int left, int top, int right, int bottom, Rect outRect) {
        final int width = host.productViewportWidthPx();
        final int height = host.productViewportHeightPx();
        outRect.set(
                clampInt(left, 0, width),
                clampInt(top, 0, height),
                clampInt(right, 0, width),
                clampInt(bottom, 0, height));
        return !outRect.isEmpty();
    }

    private void requestFrameLoopReevaluation() {
        host.reevaluateProductFrameLoop();
    }

    private void copyCurrentShellSelectionToClipboard() {
        final byte[] bytes = bridge.currentSelectionTextBytes();
        if (bytes == null) {
            host.appendEvent("product.selection.copy result=no-bytes");
            return;
        }
        final String text = new String(bytes, java.nio.charset.StandardCharsets.UTF_8);
        final ClipboardManager clipboard = host.context().getSystemService(ClipboardManager.class);
        if (clipboard == null) {
            host.appendEvent("product.selection.copy result=no-clipboard");
            return;
        }
        clipboard.setPrimaryClip(ClipData.newPlainText("terminal-selection", text));
        host.appendEvent("product.selection.copy result=ok chars=" + text.length());
    }
}
