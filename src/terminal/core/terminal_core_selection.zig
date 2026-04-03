const selection_semantics = @import("../model/selection_semantics.zig");
const types = @import("../model/types.zig");

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

pub const SelectionMutationEffect = struct {
    changed: bool = false,
    scroll_offset: usize = 0,
};

fn unchanged(self: anytype) SelectionMutationEffect {
    return .{ .changed = false, .scroll_offset = self.scrollbackOffset() };
}

fn changed(self: anytype) SelectionMutationEffect {
    return .{ .changed = true, .scroll_offset = self.scrollbackOffset() };
}

pub fn clearSelectionIfActive(self: anytype) SelectionMutationEffect {
    if (self.selectionState() == null) return unchanged(self);
    self.clearSelection();
    return changed(self);
}

pub fn selectRange(self: anytype, start: types.SelectionPos, end: types.SelectionPos, finished: bool) SelectionMutationEffect {
    if (self.active == .alt) return unchanged(self);
    self.startSelection(start.row, start.col);
    self.updateSelection(end.row, end.col);
    if (finished) self.finishSelection();
    return changed(self);
}

pub fn selectCell(self: anytype, pos: types.SelectionPos, finished: bool) SelectionMutationEffect {
    return selectRange(self, pos, pos, finished);
}

pub fn selectOrUpdateCell(self: anytype, pos: types.SelectionPos) SelectionMutationEffect {
    if (self.selectionState() == null) {
        return selectCell(self, pos, false);
    }
    if (self.active == .alt) return unchanged(self);
    self.updateSelection(pos.row, pos.col);
    return changed(self);
}

pub fn selectOrderedRange(
    self: anytype,
    anchor_start: types.SelectionPos,
    anchor_end: types.SelectionPos,
    target_start: types.SelectionPos,
    target_end: types.SelectionPos,
    finished: bool,
) SelectionMutationEffect {
    const range = selection_semantics.orderedRange(anchor_start, anchor_end, target_start, target_end);
    return selectRange(self, range.start, range.end, finished);
}

pub fn beginClickSelection(
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
        _ = selectRange(
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
            _ = selectRange(
                self,
                .{ .row = global_row, .col = span.start },
                .{ .row = global_row, .col = span.end },
                true,
            );
            return result;
        }
        const sel_col = @min(col, last_col);
        _ = selectCell(self, .{ .row = global_row, .col = sel_col }, false);
        return .{ .started = true };
    }
    return .{};
}

pub fn selectOrUpdateCellInRow(
    self: anytype,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
) SelectionMutationEffect {
    const last_col = selection_semantics.rowLastContentCol(row_cells) orelse return false;
    const sel_col = @min(col, last_col);
    return selectOrUpdateCell(self, .{ .row = global_row, .col = sel_col });
}

pub fn extendGestureSelection(
    self: anytype,
    gesture: SelectionGesture,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
) SelectionMutationEffect {
    switch (gesture.mode) {
        .none => return unchanged(self),
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
            return selectOrderedRange(
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
            return selectOrderedRange(
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
