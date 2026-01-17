const std = @import("std");

var log_file: ?std.fs.File = null;
var log_mutex: std.Thread.Mutex = .{};

pub fn init() !void {
    if (log_file != null) return;
    var file = try std.fs.cwd().createFile("zide.log", .{ .truncate = false, .read = false });
    try file.seekFromEnd(0);
    log_file = file;
}

pub fn deinit() void {
    if (log_file) |file| {
        file.close();
    }
    log_file = null;
}

pub fn logf(comptime fmt: []const u8, args: anytype) void {
    if (log_file == null) return;
    log_mutex.lock();
    defer log_mutex.unlock();

    var buf: [1024]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    if (log_file) |file| {
        _ = file.writeAll(msg) catch {};
        _ = file.writeAll("\n") catch {};
    }
}

pub fn logStdout(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
