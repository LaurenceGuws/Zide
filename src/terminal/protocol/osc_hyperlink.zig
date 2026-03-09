const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub const SessionFacade = struct {
    ctx: *anyopaque,
    clear_osc_hyperlink_fn: *const fn (ctx: *anyopaque) void,
    set_osc_hyperlink_active_fn: *const fn (ctx: *anyopaque, active: bool) void,
    set_current_hyperlink_id_fn: *const fn (ctx: *anyopaque, id: u32) void,
    append_osc_hyperlink_uri_fn: *const fn (ctx: *anyopaque, uri: []const u8) anyerror!void,
    append_hyperlink_fn: *const fn (ctx: *anyopaque, uri: []const u8) ?u32,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .clear_osc_hyperlink_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.osc_hyperlink.clearRetainingCapacity();
                }
            }.call,
            .set_osc_hyperlink_active_fn = struct {
                fn call(ctx: *anyopaque, active: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.osc_hyperlink_active = active;
                }
            }.call,
            .set_current_hyperlink_id_fn = struct {
                fn call(ctx: *anyopaque, id: u32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.current_hyperlink_id = id;
                }
            }.call,
            .append_osc_hyperlink_uri_fn = struct {
                fn call(ctx: *anyopaque, uri: []const u8) anyerror!void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    _ = try s.osc_hyperlink.appendSlice(s.allocator, uri);
                }
            }.call,
            .append_hyperlink_fn = struct {
                fn call(ctx: *anyopaque, uri: []const u8) ?u32 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.appendHyperlink(uri);
                }
            }.call,
        };
    }

    pub fn clearOscHyperlink(self: *const SessionFacade) void {
        self.clear_osc_hyperlink_fn(self.ctx);
    }

    pub fn setOscHyperlinkActive(self: *const SessionFacade, active: bool) void {
        self.set_osc_hyperlink_active_fn(self.ctx, active);
    }

    pub fn setCurrentHyperlinkId(self: *const SessionFacade, id: u32) void {
        self.set_current_hyperlink_id_fn(self.ctx, id);
    }

    pub fn appendOscHyperlinkUri(self: *const SessionFacade, uri: []const u8) !void {
        try self.append_osc_hyperlink_uri_fn(self.ctx, uri);
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
