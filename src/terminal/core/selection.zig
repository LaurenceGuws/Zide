const terminal_core_mod = @import("terminal_core.zig");
const types = @import("../model/types.zig");
const publication_flow = @import("publication/publication_flow.zig");

pub const SelectionGesture = terminal_core_mod.TerminalCore.SelectionGesture;
pub const ClickSelectionResult = terminal_core_mod.TerminalCore.ClickSelectionResult;

pub fn clearSelection(self: anytype) void {
    self.session.control.state_mutex.lock();
    defer self.session.control.state_mutex.unlock();
    clearSelectionLocked(self);
}

pub fn clearSelectionLocked(self: anytype) void {
    self.core.clearSelection();
    _ = publication_flow.consumeSelectionMutationLocked(self, .{
        .changed = true,
        .scroll_offset = self.core.scrollbackOffset(),
    });
}

pub fn clearSelectionIfActiveLocked(self: anytype) bool {
    return publication_flow.consumeSelectionMutationLocked(self, self.core.clearSelectionIfActive());
}

pub fn startSelection(self: anytype, row: usize, col: usize) void {
    self.session.control.state_mutex.lock();
    defer self.session.control.state_mutex.unlock();
    startSelectionLocked(self, row, col);
}

pub fn startSelectionLocked(self: anytype, row: usize, col: usize) void {
    if (self.core.active == .alt) return;
    self.core.startSelection(row, col);
    _ = publication_flow.consumeSelectionMutationLocked(self, .{
        .changed = true,
        .scroll_offset = self.core.scrollbackOffset(),
    });
}

pub fn updateSelection(self: anytype, row: usize, col: usize) void {
    self.session.control.state_mutex.lock();
    defer self.session.control.state_mutex.unlock();
    updateSelectionLocked(self, row, col);
}

pub fn updateSelectionLocked(self: anytype, row: usize, col: usize) void {
    if (self.core.active == .alt) return;
    self.core.updateSelection(row, col);
    _ = publication_flow.consumeSelectionMutationLocked(self, .{
        .changed = true,
        .scroll_offset = self.core.scrollbackOffset(),
    });
}

pub fn finishSelection(self: anytype) void {
    self.session.control.state_mutex.lock();
    defer self.session.control.state_mutex.unlock();
    finishSelectionLocked(self);
}

pub fn finishSelectionLocked(self: anytype) void {
    if (self.core.active == .alt) return;
    self.core.finishSelection();
    _ = publication_flow.consumeSelectionMutationLocked(self, .{
        .changed = true,
        .scroll_offset = self.core.scrollbackOffset(),
    });
}

pub fn finishSelectionIfActiveLocked(self: anytype) bool {
    if (selectionState(self) == null) return false;
    finishSelectionLocked(self);
    return true;
}

pub fn selectRange(self: anytype, start: types.SelectionPos, end: types.SelectionPos, finished: bool) void {
    self.session.control.state_mutex.lock();
    defer self.session.control.state_mutex.unlock();
    selectRangeLocked(self, start, end, finished);
}

pub fn selectRangeLocked(self: anytype, start: types.SelectionPos, end: types.SelectionPos, finished: bool) void {
    _ = publication_flow.consumeSelectionMutationLocked(self, self.core.selectRange(start, end, finished));
}

pub fn selectCellLocked(self: anytype, pos: types.SelectionPos, finished: bool) void {
    _ = publication_flow.consumeSelectionMutationLocked(self, self.core.selectCell(pos, finished));
}

pub fn selectOrUpdateCellLocked(self: anytype, pos: types.SelectionPos) bool {
    return publication_flow.consumeSelectionMutationLocked(self, self.core.selectOrUpdateCell(pos));
}

pub fn selectOrderedRangeLocked(
    self: anytype,
    anchor_start: types.SelectionPos,
    anchor_end: types.SelectionPos,
    target_start: types.SelectionPos,
    target_end: types.SelectionPos,
    finished: bool,
) bool {
    return publication_flow.consumeSelectionMutationLocked(
        self,
        self.core.selectOrderedRange(anchor_start, anchor_end, target_start, target_end, finished),
    );
}

pub fn beginClickSelectionLocked(
    self: anytype,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
    click_count: u8,
) ClickSelectionResult {
    const result = self.core.beginClickSelection(row_cells, global_row, col, click_count);
    if (result.started) {
        _ = publication_flow.consumeSelectionMutationLocked(self, .{
            .changed = true,
            .scroll_offset = self.core.scrollbackOffset(),
        });
    }
    return result;
}

pub fn selectOrUpdateCellInRowLocked(
    self: anytype,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
) bool {
    return publication_flow.consumeSelectionMutationLocked(
        self,
        self.core.selectOrUpdateCellInRow(row_cells, global_row, col),
    );
}

pub fn extendGestureSelectionLocked(
    self: anytype,
    gesture: SelectionGesture,
    row_cells: []const types.Cell,
    global_row: usize,
    col: usize,
) bool {
    return publication_flow.consumeSelectionMutationLocked(
        self,
        self.core.extendGestureSelection(gesture, row_cells, global_row, col),
    );
}

pub fn selectionState(self: anytype) ?types.TerminalSelection {
    return self.core.selectionState();
}
