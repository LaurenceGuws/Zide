const std = @import("std");
const builtin = @import("builtin");
const osc_util = @import("osc_util.zig");
const app_logger = @import("../../app_logger.zig");

pub const SessionFacade = struct {
    allocator: std.mem.Allocator,
    cwd: osc_util.SessionFacade,

    pub fn from(session: anytype) SessionFacade {
        return .{
            .allocator = session.allocator,
            .cwd = osc_util.SessionFacade.from(session),
        };
    }

    pub fn normalizeCwd(self: *const SessionFacade, raw_path: []const u8) void {
        osc_util.normalizeCwd(self.cwd, raw_path);
    }
};

pub fn parseCwd(session: SessionFacade, text: []const u8) void {
    const prefix = "file://";
    if (!std.mem.startsWith(u8, text, prefix)) return;
    const rest = text[prefix.len..];
    const slash = std.mem.indexOfScalar(u8, rest, '/') orelse return;
    const host = rest[0..slash];
    const raw_path = rest[slash..];
    if (raw_path.len == 0) return;
    if (!oscCwdHostOk(host)) return;

    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(session.allocator);
    if (!osc_util.decodeOscPercent(session.allocator, &decoded, raw_path)) return;

    session.normalizeCwd(decoded.items);
}

fn oscCwdHostOk(host: []const u8) bool {
    const log = app_logger.logger("terminal.osc");
    if (host.len == 0) return true;
    if (std.mem.eql(u8, host, "localhost")) return true;
    if (builtin.target.os.tag == .windows) return false;

    var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const local = std.posix.gethostname(&buf) catch |err| {
        log.logf(.warning, "osc cwd hostname lookup failed: {s}", .{@errorName(err)});
        return false;
    };
    if (std.mem.eql(u8, host, local)) return true;
    if (host.len > local.len and std.mem.startsWith(u8, host, local) and host[local.len] == '.') {
        return true;
    }
    return false;
}
