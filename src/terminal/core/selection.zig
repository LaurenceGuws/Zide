const types = @import("../model/types.zig");
const selection_semantics = @import("../model/selection_semantics.zig");

pub const SelectionGestureMode = enum {
    none,
    word,
    line,
};

pub const SelectionGesture = struct {
    mode: SelectionGestureMode = .none,
    row: usize = 0,
    col_start: usize = 0,
    col_end: usize = 0,
};

pub const ClickSelectionResult = struct {
    gesture: SelectionGesture = .{},
    started: bool = false,
};

pub fn clearSelection(self: anytype) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    clearSelectionLocked(self);
}

pub fn clearSelectionLocked(self: anytype) void {
    self.core.history.clearSelection();
    self.view_cache_request_offset.store(@intCast(self.core.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
}

pub fn clearSelectionIfActiveLocked(self: anytype) bool {
    if (selectionState(self) == null) return false;
    clearSelectionLocked(self);
    return true;
}

pub fn startSelection(self: anytype, row: usize, col: usize) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    startSelectionLocked(self, row, col);
}

pub fn startSelectionLocked(self: anytype, row: usize, col: usize) void {
    if (self.core.active == .alt) return;
    self.core.history.startSelection(row, col);
    self.view_cache_request_offset.store(@intCast(self.core.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
}

pub fn updateSelection(self: anytype, row: usize, col: usize) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    updateSelectionLocked(self, row, col);
}

pub fn updateSelectionLocked(self: anytype, row: usize, col: usize) void {
    if (self.core.active == .alt) return;
    self.core.history.updateSelection(row, col);
    self.view_cache_request_offset.store(@intCast(self.core.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
}

pub fn finishSelection(self: anytype) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    finishSelectionLocked(self);
}

pub fn finishSelectionLocked(self: anytype) void {
    if (self.core.active == .alt) return;
    self.core.history.finishSelection();
    self.view_cache_request_offset.store(@intCast(self.core.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
}

pub fn finishSelectionIfActiveLocked(self: anytype) bool {
    if (selectionState(self) == null) return false;
    finishSelectionLocked(self);
    return true;
}

pub fn selectRange(self: anytype, start: types.SelectionPos, end: types.SelectionPos, finished: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    selectRangeLocked(self, start, end, finished);
}

pub fn selectRangeLocked(self: anytype, start: types.SelectionPos, end: types.SelectionPos, finished: bool) void {
    if (self.core.active == .alt) return;
    self.core.history.startSelection(start.row, start.col);
    self.core.history.updateSelection(end.row, end.col);
    if (finished) {
        self.core.history.finishSelection();
    }
    self.view_cache_request_offset.store(@intCast(self.core.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
}

pub fn selectCellLocked(self: anytype, pos: types.SelectionPos, finished: bool) void {
    selectRangeLocked(self, pos, pos, finished);
}

pub fn selectOrUpdateCellLocked(self: anytype, pos: types.SelectionPos) bool {
    if (selectionState(self) == null) {
        selectCellLocked(self, pos, false);
    } else {
        updateSelectionLocked(self, pos.row, pos.col);
    }
    return true;
}

pub fn selectOrderedRangeLocked(
    self: anytype,
    anchor_start: types.SelectionPos,
    anchor_end: types.SelectionPos,
    target_start: types.SelectionPos,
    target_end: types.SelectionPos,
    finished: bool,
) bool {
    const range = selection_semantics.orderedRange(anchor_start, anchor_end, target_start, target_end);
    selectRangeLocked(self, range.start, range.end, finished);
    return true;
}

pub fn beginClickSelectionLocked(
    self: anytype,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
    click_count: u8,
) ClickSelectionResult {
    const last_col = selection_semantics.rowLastContentCol(row_cells) orelse return .{};
    if (click_count >= 3) {
        const result: ClickSelectionResult = .{
            .gesture = .{
                .mode = .line,
                .row = global_row,
                .col_start = 0,
                .col_end = last_col,
            },
            .started = true,
        };
        selectRangeLocked(
            self,
            .{ .row = global_row, .col = 0 },
            .{ .row = global_row, .col = last_col },
            true,
        );
        return result;
    }
    if (click_count == 2) {
        if (selection_semantics.wordSpan(row_cells, col, last_col)) |span| {
            const result: ClickSelectionResult = .{
                .gesture = .{
                    .mode = .word,
                    .row = global_row,
                    .col_start = span.start,
                    .col_end = span.end,
                },
                .started = true,
            };
            selectRangeLocked(
                self,
                .{ .row = global_row, .col = span.start },
                .{ .row = global_row, .col = span.end },
                true,
            );
            return result;
        }
        const sel_col = @min(col, last_col);
        selectCellLocked(self, .{ .row = global_row, .col = sel_col }, false);
        return .{ .started = true };
    }
    return .{};
}

pub fn selectOrUpdateCellInRowLocked(
    self: anytype,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
) bool {
    const last_col = selection_semantics.rowLastContentCol(row_cells) orelse return false;
    const sel_col = @min(col, last_col);
    return selectOrUpdateCellLocked(self, .{ .row = global_row, .col = sel_col });
}

pub fn extendGestureSelectionLocked(
    self: anytype,
    gesture: SelectionGesture,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
) bool {
    switch (gesture.mode) {
        .none => return false,
        .word => {
            var target_start: usize = col;
            var target_end: usize = col;
            if (selection_semantics.rowLastContentCol(row_cells)) |last_col| {
                if (selection_semantics.wordSpan(row_cells, col, last_col)) |span| {
                    target_start = span.start;
                    target_end = span.end;
                } else {
                    const sel_col = @min(col, last_col);
                    target_start = sel_col;
                    target_end = sel_col;
                }
            } else {
                target_start = 0;
                target_end = 0;
            }
            return selectOrderedRangeLocked(
                self,
                .{ .row = gesture.row, .col = gesture.col_start },
                .{ .row = gesture.row, .col = gesture.col_end },
                .{ .row = global_row, .col = target_start },
                .{ .row = global_row, .col = target_end },
                false,
            );
        },
        .line => {
            const target_last = selection_semantics.rowLastContentCol(row_cells) orelse 0;
            return selectOrderedRangeLocked(
                self,
                .{ .row = gesture.row, .col = 0 },
                .{ .row = gesture.row, .col = gesture.col_end },
                .{ .row = global_row, .col = 0 },
                .{ .row = global_row, .col = target_last },
                false,
            );
        },
    }
}

pub fn selectionState(self: anytype) ?types.TerminalSelection {
    if (self.core.active == .alt) return null;
    return self.core.history.selectionState();
}
