const builtin = @import("builtin");
const std = @import("std");

var log_file: ?std.fs.File = null;
var log_mutex: std.Thread.Mutex = .{};
var log_filter_file: ?[]u8 = null;
var log_filter_console: ?[]u8 = null;

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
    if (log_filter_file) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter_file = null;
    if (log_filter_console) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter_console = null;
}

pub const Logger = struct {
    name: []const u8,
    enabled_file: bool,
    enabled_console: bool,

    pub fn logf(self: Logger, comptime fmt: []const u8, args: anytype) void {
        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;

        if (self.enabled_file and log_file != null) {
            log_mutex.lock();
            defer log_mutex.unlock();
            if (log_file) |file| {
                _ = file.writeAll("[") catch {};
                _ = file.writeAll(self.name) catch {};
                _ = file.writeAll("] ") catch {};
                _ = file.writeAll(msg) catch {};
                _ = file.writeAll("\n") catch {};
            }
        }

        if (self.enabled_console) {
            std.debug.print("[{s}] ", .{self.name});
            std.debug.print("{s}\n", .{msg});
        }
    }

    pub fn logStdout(self: Logger, comptime fmt: []const u8, args: anytype) void {
        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
        if (self.enabled_console) {
            std.debug.print("[{s}] ", .{self.name});
            std.debug.print("{s}\n", .{msg});
        }
        if (self.enabled_file and log_file != null) {
            log_mutex.lock();
            defer log_mutex.unlock();
            if (log_file) |file| {
                _ = file.writeAll("[") catch {};
                _ = file.writeAll(self.name) catch {};
                _ = file.writeAll("] ") catch {};
                _ = file.writeAll(msg) catch {};
                _ = file.writeAll("\n") catch {};
            }
        }
    }
};

pub fn logger(name: []const u8) Logger {
    return .{
        .name = name,
        .enabled_file = isEnabled(name, log_filter_file, "ZIDE_LOG_FILE\x00"),
        .enabled_console = isEnabled(name, log_filter_console, "ZIDE_LOG_CONSOLE\x00"),
    };
}

pub fn setFileFilterString(value: []const u8) !void {
    if (log_filter_file) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter_file = try std.heap.c_allocator.dupe(u8, value);
}

pub fn setConsoleFilterString(value: []const u8) !void {
    if (log_filter_console) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter_console = try std.heap.c_allocator.dupe(u8, value);
}

fn isEnabled(name: []const u8, filter_override: ?[]const u8, env_key: [:0]const u8) bool {
    const raw = if (filter_override) |filter| filter else blk: {
        if (std.c.getenv("ZIDE_LOG")) |env_all| {
            break :blk std.mem.sliceTo(env_all, 0);
        }
        const env = std.c.getenv(env_key) orelse {
            if (builtin.is_test) return false;
            return true;
        };
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
