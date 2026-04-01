const std = @import("std");
const types = @import("../model/types.zig");
const terminal_publication = @import("publication/terminal_publication.zig");

const Cell = types.Cell;

pub const ScrollbackRange = struct {
    total_rows: usize,
    row_count: usize,
    cols: usize,
};

pub const ScrollbackInfo = struct {
    total_rows: usize,
    cols: usize,
};

pub const default_wheel_lines_per_step: isize = 3;

pub fn scrollbackCount(self: anytype) usize {
    self.core.ensureScrollbackView(self.core.primary.grid.cols, self.core.primary.defaultCell());
    return self.core.scrollbackCount();
}

pub fn scrollbackRow(self: anytype, index: usize) ?[]const Cell {
    return self.core.scrollbackRow(self.core.primary.grid.cols, self.core.primary.defaultCell(), index);
}

pub fn scrollbackInfo(self: anytype) ScrollbackInfo {
    if (self.core.active == .alt) {
        return .{
            .total_rows = 0,
            .cols = self.core.primary.grid.cols,
        };
    }
    self.core.ensureScrollbackView(self.core.primary.grid.cols, self.core.primary.defaultCell());
    return .{
        .total_rows = self.core.scrollbackCount(),
        .cols = self.core.primary.grid.cols,
    };
}

pub fn copyScrollbackRange(
    self: anytype,
    allocator: std.mem.Allocator,
    start_row: usize,
    max_rows: usize,
    out: *std.ArrayList(Cell),
) !ScrollbackRange {
    self.control.state_mutex.lock();
    defer self.control.state_mutex.unlock();

    out.clearRetainingCapacity();
    const info = scrollbackInfo(self);
    const total_rows = info.total_rows;
    const cols = info.cols;
    if (start_row > total_rows) return error.InvalidArgument;

    const available = total_rows - start_row;
    const requested = if (max_rows == 0) available else @min(available, max_rows);

    try out.ensureTotalCapacityPrecise(allocator, requested * cols);

    var row_index: usize = 0;
    while (row_index < requested) : (row_index += 1) {
        const row = self.core.scrollbackRow(@intCast(cols), self.core.primary.defaultCell(), start_row + row_index) orelse return error.InvalidArgument;
        try out.appendSlice(allocator, row);
    }

    return .{
        .total_rows = total_rows,
        .row_count = requested,
        .cols = cols,
    };
}

pub fn scrollOffset(self: anytype) usize {
    if (self.core.active == .alt) return 0;
    return self.core.history.scrollOffset();
}

pub fn setScrollOffset(self: anytype, offset: usize) void {
    self.control.state_mutex.lock();
    defer self.control.state_mutex.unlock();
    setScrollOffsetLocked(self, offset);
}

pub fn setScrollOffsetLocked(self: anytype, offset: usize) void {
    const before = self.core.history.scrollOffset();
    const after = self.core.setScrollbackOffset(self.core.primary.grid.rows, self.core.primary.grid.cols, self.core.primary.defaultCell(), offset);
    if (after != before) {
        _ = terminal_publication.requestViewRefreshLocked(self, after);
    } else {
        terminal_publication.queueViewRefreshLocked(self, after);
    }
    terminal_publication.updateViewCacheForScrollLocked(self);
}

pub fn resetToLiveBottomLocked(self: anytype) bool {
    if (self.core.active == .alt) return false;
    if (self.core.history.scrollOffset() == 0) return false;
    setScrollOffsetLocked(self, 0);
    return true;
}

pub fn resetToLiveBottomForInputLocked(self: anytype, saw_non_modifier_key_press: bool, saw_text_input: bool) bool {
    if (!saw_non_modifier_key_press and !saw_text_input) return false;
    return resetToLiveBottomLocked(self);
}

pub fn setScrollOffsetFromNormalizedTrackLocked(self: anytype, track_ratio: f32) ?usize {
    if (self.core.active == .alt) return null;
    const max_offset = self.core.maxScrollbackOffset(self.core.primary.grid.rows, self.core.primary.grid.cols, self.core.primary.defaultCell());
    const clamped = std.math.clamp(track_ratio, 0.0, 1.0);
    const target_offset = @as(usize, @intFromFloat(@round(@as(f32, @floatFromInt(max_offset)) * (1.0 - clamped))));
    if (target_offset == self.core.history.scrollOffset()) return null;
    setScrollOffsetLocked(self, target_offset);
    return self.core.history.scrollOffset();
}

pub fn scrollSelectionDragLocked(self: anytype, toward_top: bool) bool {
    if (self.core.active == .alt) return false;
    scrollByLocked(self, if (toward_top) 1 else -1);
    return true;
}

pub fn scrollWheelLocked(self: anytype, wheel_steps: i32) bool {
    if (self.core.active == .alt) return false;
    if (wheel_steps == 0) return false;
    const before = self.core.history.scrollOffset();
    const delta: isize = @as(isize, @intCast(wheel_steps)) * default_wheel_lines_per_step;
    scrollByLocked(self, delta);
    return self.core.history.scrollOffset() != before;
}

pub fn scrollBy(self: anytype, delta: isize) void {
    self.control.state_mutex.lock();
    defer self.control.state_mutex.unlock();
    scrollByLocked(self, delta);
}

pub fn scrollByLocked(self: anytype, delta: isize) void {
    if (self.core.active == .alt) return;
    if (delta == 0) return;
    const before = self.core.history.scrollOffset();
    const after = self.core.scrollScrollbackBy(self.core.primary.grid.rows, self.core.primary.grid.cols, self.core.primary.defaultCell(), delta);
    if (after != before) {
        _ = terminal_publication.requestViewRefreshLocked(self, after);
    } else {
        terminal_publication.queueViewRefreshLocked(self, after);
    }
    terminal_publication.updateViewCacheForScrollLocked(self);
}
