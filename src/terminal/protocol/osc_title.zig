const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub const SessionFacade = struct {
    allocator: std.mem.Allocator,
    title_buffer: *std.ArrayList(u8),
    title: *[]const u8,

    pub fn from(session: anytype) SessionFacade {
        return .{
            .allocator = session.allocator,
            .title_buffer = &session.core.title_buffer,
            .title = &session.core.title,
        };
    }

    pub fn clearTitleBuffer(self: *const SessionFacade) void {
        self.title_buffer.clearRetainingCapacity();
    }

    pub fn appendTitleSlice(self: *const SessionFacade, text: []const u8) !void {
        try self.title_buffer.appendSlice(self.allocator, text);
    }

    pub fn publishTitle(self: *const SessionFacade) void {
        self.title.* = self.title_buffer.items;
    }
};

pub fn setTitle(session: SessionFacade, text: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    session.clearTitleBuffer();
    const max_len: usize = 256;
    const slice = if (text.len > max_len) text[0..max_len] else text;
    session.appendTitleSlice(slice) catch |err| {
        log.logf(.warning, "osc title append failed: {s}", .{@errorName(err)});
        return;
    };
    session.publishTitle();
}
