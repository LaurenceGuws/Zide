const std = @import("std");
const app_logger = @import("../app_logger.zig");

pub fn isProbablyTextFile(path: []const u8) bool {
    const log = app_logger.logger("app.file_detect");
    var file = if (std.fs.path.isAbsolute(path))
        std.fs.openFileAbsolute(path, .{ .mode = .read_only }) catch |err| {
            log.logf(.debug, "open absolute failed path={s}: {s}", .{ path, @errorName(err) });
            return false;
        }
    else
        std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err| {
            log.logf(.debug, "open relative failed path={s}: {s}", .{ path, @errorName(err) });
            return false;
        };
    defer file.close();
    const stat = file.stat() catch |err| {
        log.logf(.debug, "stat failed path={s}: {s}", .{ path, @errorName(err) });
        return false;
    };
    if (stat.kind != .file) return false;
    var buf: [8192]u8 = undefined;
    const n = file.read(&buf) catch |err| {
        log.logf(.debug, "read failed path={s}: {s}", .{ path, @errorName(err) });
        return false;
    };
    if (n == 0) return true;
    if (std.mem.indexOfScalar(u8, buf[0..n], 0) != null) return false;
    return std.unicode.utf8ValidateSlice(buf[0..n]);
}
