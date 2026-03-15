const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub const SessionFacade = struct {
    allocator: std.mem.Allocator,
    ctx: *anyopaque,
    clear_title_buffer_fn: *const fn (ctx: *anyopaque) void,
    append_title_slice_fn: *const fn (ctx: *anyopaque, allocator: std.mem.Allocator, text: []const u8) anyerror!void,
    publish_title_buffer_fn: *const fn (ctx: *anyopaque) void,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .allocator = session.allocator,
            .ctx = @ptrCast(session),
            .clear_title_buffer_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.core.clearTitleBuffer();
                }
            }.call,
            .append_title_slice_fn = struct {
                fn call(ctx: *anyopaque, allocator: std.mem.Allocator, text: []const u8) anyerror!void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    try s.core.appendTitleSlice(allocator, text);
                }
            }.call,
            .publish_title_buffer_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.core.publishTitleBuffer();
                }
            }.call,
        };
    }

    pub fn clearTitleBuffer(self: *const SessionFacade) void {
        self.clear_title_buffer_fn(self.ctx);
    }

    pub fn appendTitleSlice(self: *const SessionFacade, text: []const u8) !void {
        try self.append_title_slice_fn(self.ctx, self.allocator, text);
    }

    pub fn publishTitle(self: *const SessionFacade) void {
        self.publish_title_buffer_fn(self.ctx);
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
