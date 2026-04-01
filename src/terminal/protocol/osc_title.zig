const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub fn setTitle(self: anytype, text: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    self.core.clearTitleBuffer();
    const max_len: usize = 256;
    const slice = if (text.len > max_len) text[0..max_len] else text;
    self.core.appendTitleSlice(self.allocator, slice) catch |err| {
        log.logf(.warning, "osc title append failed: {s}", .{@errorName(err)});
        return;
    };
    self.core.publishTitleBuffer();
}
