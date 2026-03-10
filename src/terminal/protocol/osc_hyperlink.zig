const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub const SessionFacade = struct {
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
    osc_hyperlink: *std.ArrayList(u8),
    osc_hyperlink_active: *bool,
    current_hyperlink_id: *u32,
    append_hyperlink_fn: *const fn (ctx: *anyopaque, uri: []const u8) ?u32,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .allocator = session.allocator,
            .osc_hyperlink = &session.core.osc_hyperlink,
            .osc_hyperlink_active = &session.core.osc_hyperlink_active,
            .current_hyperlink_id = &session.core.current_hyperlink_id,
            .append_hyperlink_fn = struct {
                fn call(ctx: *anyopaque, uri: []const u8) ?u32 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.appendHyperlink(uri);
                }
            }.call,
        };
    }

    pub fn clearOscHyperlink(self: *const SessionFacade) void {
        self.osc_hyperlink.clearRetainingCapacity();
    }

    pub fn setOscHyperlinkActive(self: *const SessionFacade, active: bool) void {
        self.osc_hyperlink_active.* = active;
    }

    pub fn setCurrentHyperlinkId(self: *const SessionFacade, id: u32) void {
        self.current_hyperlink_id.* = id;
    }

    pub fn appendOscHyperlinkUri(self: *const SessionFacade, uri: []const u8) !void {
        _ = try self.osc_hyperlink.appendSlice(self.allocator, uri);
    }

    pub fn appendHyperlink(self: *const SessionFacade, uri: []const u8) ?u32 {
        return self.append_hyperlink_fn(self.ctx, uri);
    }
};

pub fn parseHyperlink(session: SessionFacade, text: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
    const uri = text[split + 1 ..];
    session.clearOscHyperlink();
    if (uri.len == 0) {
        session.setOscHyperlinkActive(false);
        session.setCurrentHyperlinkId(0);
        return;
    }
    session.appendOscHyperlinkUri(uri) catch |err| {
        log.logf(.warning, "osc hyperlink append failed: {s}", .{@errorName(err)});
        return;
    };
    session.setOscHyperlinkActive(true);
    session.setCurrentHyperlinkId(session.appendHyperlink(uri) orelse 0);
}
