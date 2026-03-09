const types = @import("../model/types.zig");

pub fn clearSelection(self: anytype) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    clearSelectionLocked(self);
}

pub fn clearSelectionLocked(self: anytype) void {
    self.history.clearSelection();
    self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
}

pub fn startSelection(self: anytype, row: usize, col: usize) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    startSelectionLocked(self, row, col);
}

pub fn startSelectionLocked(self: anytype, row: usize, col: usize) void {
    if (self.active == .alt) return;
    self.history.startSelection(row, col);
    self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
}

pub fn updateSelection(self: anytype, row: usize, col: usize) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    updateSelectionLocked(self, row, col);
}

pub fn updateSelectionLocked(self: anytype, row: usize, col: usize) void {
    if (self.active == .alt) return;
    self.history.updateSelection(row, col);
    self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
}

pub fn finishSelection(self: anytype) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    finishSelectionLocked(self);
}

pub fn finishSelectionLocked(self: anytype) void {
    if (self.active == .alt) return;
    self.history.finishSelection();
    self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
}

pub fn selectionState(self: anytype) ?types.TerminalSelection {
    if (self.active == .alt) return null;
    return self.history.selectionState();
}
