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

pub fn scrollbackCount(self: anytype) usize {
    if (self.active == .alt) return 0;
    self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
    return self.history.scrollbackCount();
}

pub fn scrollbackRow(self: anytype, index: usize) ?[]const Cell {
    if (self.active == .alt) return null;
    self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
    return self.history.scrollbackRow(index);
}

pub fn scrollbackInfo(self: anytype) ScrollbackInfo {
    if (self.active == .alt) {
        return .{
            .total_rows = 0,
            .cols = self.primary.grid.cols,
        };
    }
    self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
    return .{
        .total_rows = self.history.scrollbackCount(),
        .cols = self.primary.grid.cols,
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
        const row = self.history.scrollbackRow(start_row + row_index) orelse return error.InvalidArgument;
        try out.appendSlice(allocator, row);
    }

    return .{
        .total_rows = total_rows,
        .row_count = requested,
        .cols = cols,
    };
}

pub fn scrollOffset(self: anytype) usize {
    if (self.active == .alt) return 0;
    return self.history.scrollOffset();
}

pub fn setScrollOffset(self: anytype, offset: usize) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setScrollOffsetLocked(self, offset);
}

pub fn setScrollOffsetLocked(self: anytype, offset: usize) void {
    if (self.active == .alt) {
        self.history.scrollback_offset = 0;
        return;
    }
    self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
    self.history.setScrollOffset(self.primary.grid.rows, offset);
    self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
    self.updateViewCacheForScroll();
    const log = app_logger.logger("terminal.core");
    const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
    log.logf(.info, "set scroll offset={d} max={d}", .{ self.history.scrollOffset(), max_offset });
    log.logStdout(.info, "set scroll offset={d} max={d}", .{ self.history.scrollOffset(), max_offset });
}

pub fn scrollBy(self: anytype, delta: isize) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    scrollByLocked(self, delta);
}

pub fn scrollByLocked(self: anytype, delta: isize) void {
    if (self.active == .alt) return;
    if (delta == 0) return;
    self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
    self.history.scrollBy(self.primary.grid.rows, delta);
    self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
    self.view_cache_pending.store(true, .release);
    self.io_wait_cond.signal();
    self.updateViewCacheForScroll();
    const log = app_logger.logger("terminal.core");
    const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
    log.logf(.info, "scroll by delta={d} offset={d} max={d}", .{ delta, self.history.scrollOffset(), max_offset });
    log.logStdout(.info, "scroll by delta={d} offset={d} max={d}", .{ delta, self.history.scrollOffset(), max_offset });
}
