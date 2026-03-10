const selection_mod = @import("selection.zig");
const types = @import("../model/types.zig");

pub const SelectionGesture = selection_mod.SelectionGesture;
pub const ClickSelectionResult = selection_mod.ClickSelectionResult;

pub fn clearSelection(self: anytype) void {
    selection_mod.clearSelection(self);
}

pub fn clearSelectionLocked(self: anytype) void {
    selection_mod.clearSelectionLocked(self);
}

pub fn clearSelectionIfActiveLocked(self: anytype) bool {
    return selection_mod.clearSelectionIfActiveLocked(self);
}

pub fn startSelection(self: anytype, row: usize, col: usize) void {
    selection_mod.startSelection(self, row, col);
}

pub fn startSelectionLocked(self: anytype, row: usize, col: usize) void {
    selection_mod.startSelectionLocked(self, row, col);
}

pub fn updateSelection(self: anytype, row: usize, col: usize) void {
    selection_mod.updateSelection(self, row, col);
}

pub fn updateSelectionLocked(self: anytype, row: usize, col: usize) void {
    selection_mod.updateSelectionLocked(self, row, col);
}

pub fn finishSelection(self: anytype) void {
    selection_mod.finishSelection(self);
}

pub fn finishSelectionLocked(self: anytype) void {
    selection_mod.finishSelectionLocked(self);
}

pub fn finishSelectionIfActiveLocked(self: anytype) bool {
    return selection_mod.finishSelectionIfActiveLocked(self);
}

pub fn selectRange(self: anytype, start_pos: types.SelectionPos, end_pos: types.SelectionPos, finished: bool) void {
    selection_mod.selectRange(self, start_pos, end_pos, finished);
}

pub fn selectRangeLocked(self: anytype, start_pos: types.SelectionPos, end_pos: types.SelectionPos, finished: bool) void {
    selection_mod.selectRangeLocked(self, start_pos, end_pos, finished);
}

pub fn selectCellLocked(self: anytype, pos: types.SelectionPos, finished: bool) void {
    selection_mod.selectCellLocked(self, pos, finished);
}

pub fn selectOrUpdateCellLocked(self: anytype, pos: types.SelectionPos) bool {
    return selection_mod.selectOrUpdateCellLocked(self, pos);
}

pub fn selectOrderedRangeLocked(
    self: anytype,
    anchor_start: types.SelectionPos,
    anchor_end: types.SelectionPos,
    target_start: types.SelectionPos,
    target_end: types.SelectionPos,
    finished: bool,
) bool {
    return selection_mod.selectOrderedRangeLocked(self, anchor_start, anchor_end, target_start, target_end, finished);
}

pub fn beginClickSelectionLocked(
    self: anytype,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
    click_count: u8,
) ClickSelectionResult {
    return selection_mod.beginClickSelectionLocked(self, row_cells, global_row, col, click_count);
}

pub fn extendGestureSelectionLocked(
    self: anytype,
    gesture: SelectionGesture,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
) bool {
    return selection_mod.extendGestureSelectionLocked(self, gesture, row_cells, global_row, col);
}

pub fn selectOrUpdateCellInRowLocked(
    self: anytype,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
) bool {
    return selection_mod.selectOrUpdateCellInRowLocked(self, row_cells, global_row, col);
}
