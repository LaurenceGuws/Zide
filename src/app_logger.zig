const std = @import("std");

var log_file: ?std.fs.File = null;
var log_mutex: std.Thread.Mutex = .{};
var log_filter: ?[]u8 = null;

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
    if (log_filter) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter = null;
}

pub const Logger = struct {
    name: []const u8,
    enabled: bool,

    pub fn logf(self: Logger, comptime fmt: []const u8, args: anytype) void {
        if (!self.enabled or log_file == null) return;
        log_mutex.lock();
        defer log_mutex.unlock();

        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
        if (log_file) |file| {
            _ = file.writeAll("[") catch {};
            _ = file.writeAll(self.name) catch {};
            _ = file.writeAll("] ") catch {};
            _ = file.writeAll(msg) catch {};
            _ = file.writeAll("\n") catch {};
        }
    }

    pub fn logStdout(self: Logger, comptime fmt: []const u8, args: anytype) void {
        if (!self.enabled) return;
        std.debug.print("[{s}] ", .{self.name});
        std.debug.print(fmt ++ "\n", args);
    }
};

pub fn logger(name: []const u8) Logger {
    return .{
        .name = name,
        .enabled = isEnabled(name),
    };
}

pub fn setFilterString(value: []const u8) !void {
    if (log_filter) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter = try std.heap.c_allocator.dupe(u8, value);
}

fn isEnabled(name: []const u8) bool {
    const raw = if (log_filter) |filter| filter else blk: {
        const env = std.c.getenv("ZIDE_LOG") orelse return true;
        break :blk std.mem.sliceTo(env, 0);
    };
    if (raw.len == 0) return false;
    if (std.mem.eql(u8, raw, "all")) return true;
    if (std.mem.eql(u8, raw, "none")) return false;

    var it = std.mem.splitScalar(u8, raw, ',');
    while (it.next()) |chunk| {
        const trimmed = std.mem.trim(u8, chunk, " \t");
        if (trimmed.len == 0) continue;
        if (std.mem.eql(u8, trimmed, name)) return true;
    }
    return false;
}
