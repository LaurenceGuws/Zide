const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const types = @import("../model/types.zig");

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
    if (self.core.active == .alt) return 0;
    self.core.history.ensureViewCache(self.core.primary.grid.cols, self.core.primary.defaultCell());
    return self.core.history.scrollbackCount();
}

pub fn scrollbackRow(self: anytype, index: usize) ?[]const Cell {
    if (self.core.active == .alt) return null;
    self.core.history.ensureViewCache(self.core.primary.grid.cols, self.core.primary.defaultCell());
    return self.core.history.scrollbackRow(index);
}

pub fn scrollbackInfo(self: anytype) ScrollbackInfo {
    if (self.core.active == .alt) {
        return .{
            .total_rows = 0,
            .cols = self.core.primary.grid.cols,
        };
    }
    self.core.history.ensureViewCache(self.core.primary.grid.cols, self.core.primary.defaultCell());
    return .{
        .total_rows = self.core.history.scrollbackCount(),
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
    self.state_mutex.lock();
    defer self.state_mutex.unlock();

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
        const row = self.core.history.scrollbackRow(start_row + row_index) orelse return error.InvalidArgument;
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
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setScrollOffsetLocked(self, offset);
}

pub fn setScrollOffsetLocked(self: anytype, offset: usize) void {
    if (self.core.active == .alt) {
        self.core.history.scrollback_offset = 0;
        return;
    }
    self.core.history.ensureViewCache(self.core.primary.grid.cols, self.core.primary.defaultCell());
    const before = self.core.history.scrollOffset();
    self.core.history.setScrollOffset(self.core.primary.grid.rows, offset);
    const after = self.core.history.scrollOffset();
    if (after != before) {
        _ = self.output_generation.fetchAdd(1, .acq_rel);
    }
    self.view_cache_request_offset.store(@intCast(self.core.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
    self.updateViewCacheForScroll();
    const log = app_logger.logger("terminal.core");
    const max_offset = self.core.history.maxScrollOffset(self.core.primary.grid.rows);
    log.logf(.debug, "set scroll offset={d} max={d}", .{ self.core.history.scrollOffset(), max_offset });
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
    self.core.history.ensureViewCache(self.core.primary.grid.cols, self.core.primary.defaultCell());
    const max_offset = self.core.history.maxScrollOffset(self.core.primary.grid.rows);
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
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    scrollByLocked(self, delta);
}

pub fn scrollByLocked(self: anytype, delta: isize) void {
    if (self.core.active == .alt) return;
    if (delta == 0) return;
    self.core.history.ensureViewCache(self.core.primary.grid.cols, self.core.primary.defaultCell());
    const before = self.core.history.scrollOffset();
    self.core.history.scrollBy(self.core.primary.grid.rows, delta);
    const after = self.core.history.scrollOffset();
    if (after != before) {
        _ = self.output_generation.fetchAdd(1, .acq_rel);
    }
    self.view_cache_request_offset.store(@intCast(self.core.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
    self.updateViewCacheForScroll();
    const log = app_logger.logger("terminal.core");
    const max_offset = self.core.history.maxScrollOffset(self.core.primary.grid.rows);
    log.logf(.debug, "scroll by delta={d} offset={d} max={d}", .{ delta, self.core.history.scrollOffset(), max_offset });
}
