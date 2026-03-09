const app_logger = @import("../../app_logger.zig");
const types = @import("../model/types.zig");

const Cell = types.Cell;

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

pub fn scrollOffset(self: anytype) usize {
    if (self.active == .alt) return 0;
    return self.history.scrollOffset();
}

pub fn setScrollOffset(self: anytype, offset: usize) void {
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
