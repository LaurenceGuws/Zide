const builtin = @import("builtin");
const std = @import("std");

var log_file: ?std.fs.File = null;
var log_mutex: std.Thread.Mutex = .{};
var log_filter_file: ?[]u8 = null;
var log_filter_console: ?[]u8 = null;
var log_level_file: Level = .info;
var log_level_console: Level = .info;
var log_level_overrides_file: ?[]u8 = null;
var log_level_overrides_console: ?[]u8 = null;
var log_start_ns: i128 = 0;

pub const Level = enum(u8) {
    critical = 0,
    @"error" = 1,
    warning = 2,
    info = 3,
    debug = 4,
    trace = 5,
};

pub fn levelFromString(value: []const u8) ?Level {
    if (std.ascii.eqlIgnoreCase(value, "critical")) return .critical;
    if (std.ascii.eqlIgnoreCase(value, "error")) return .@"error";
    if (std.ascii.eqlIgnoreCase(value, "warning") or std.ascii.eqlIgnoreCase(value, "warn")) return .warning;
    if (std.ascii.eqlIgnoreCase(value, "info")) return .info;
    if (std.ascii.eqlIgnoreCase(value, "debug")) return .debug;
    if (std.ascii.eqlIgnoreCase(value, "trace")) return .trace;
    return null;
}

fn levelName(level: Level) []const u8 {
    return switch (level) {
        .critical => "Critical",
        .@"error" => "Error",
        .warning => "Warning",
        .info => "Info",
        .debug => "Debug",
        .trace => "Trace",
    };
}

fn shouldEmit(level: Level, min_level: Level) bool {
    return @intFromEnum(level) <= @intFromEnum(min_level);
}

fn timestampMicros() i128 {
    const now = std.time.nanoTimestamp();
    const base = if (log_start_ns != 0) log_start_ns else now;
    return @divTrunc(now - base, std.time.ns_per_us);
}

fn timeOfDayMicrosUtc() struct { h: i64, m: i64, s: i64, us: i64 } {
    const us_per_day: i64 = 24 * 60 * 60 * 1_000_000;
    const us_now = std.time.microTimestamp();
    var day_us = @mod(us_now, us_per_day);
    if (day_us < 0) day_us += us_per_day;
    const h = @divTrunc(day_us, 3_600_000_000);
    day_us -= h * 3_600_000_000;
    const m = @divTrunc(day_us, 60_000_000);
    day_us -= m * 60_000_000;
    const s = @divTrunc(day_us, 1_000_000);
    const us = day_us - s * 1_000_000;
    return .{ .h = h, .m = m, .s = s, .us = us };
}

fn writeLogLine(file: std.fs.File, prefix: []const u8, msg: []const u8) !void {
    try file.writeAll(prefix);
    try file.writeAll(msg);
    try file.writeAll("\n");
}

pub fn init() !void {
    if (log_file != null) return;
    var file = try std.fs.cwd().createFile("zide.log", .{ .truncate = false, .read = false });
    try file.seekFromEnd(0);
    log_file = file;
    if (log_start_ns == 0) log_start_ns = std.time.nanoTimestamp();
}

pub fn deinit() void {
    if (log_file) |file| {
        file.close();
    }
    log_file = null;
    resetConfig();
    log_start_ns = 0;
}

pub fn resetConfig() void {
    if (log_filter_file) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter_file = null;
    if (log_filter_console) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter_console = null;
    if (log_level_overrides_file) |overrides| {
        std.heap.c_allocator.free(overrides);
    }
    log_level_overrides_file = null;
    if (log_level_overrides_console) |overrides| {
        std.heap.c_allocator.free(overrides);
    }
    log_level_overrides_console = null;
    log_level_file = .info;
    log_level_console = .info;
}

pub const Logger = struct {
    name: []const u8,
    enabled_file: bool,
    enabled_console: bool,
    file_level: Level,
    console_level: Level,

    pub fn logfSrc(self: Logger, level: Level, src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
        self.logf(level, "{s}:{d} " ++ fmt, .{ src.file, src.line } ++ args);
    }

    pub fn logf(self: Logger, level: Level, comptime fmt: []const u8, args: anytype) void {
        const emit_file = self.enabled_file and log_file != null and shouldEmit(level, self.file_level);
        const emit_console = self.enabled_console and shouldEmit(level, self.console_level);
        if (!emit_file and !emit_console) return;

        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, fmt, args) catch |err| {
            std.debug.print("[app.logger][Warning][{s}] dropped log message due to fmt error: {s}\n", .{ self.name, @errorName(err) });
            return;
        };
        const ts_us = timestampMicros();
        const tod = timeOfDayMicrosUtc();
        const level_name = levelName(level);
        var prefix_buf: [128]u8 = undefined;
        const prefix = std.fmt.bufPrint(
            &prefix_buf,
            "[{d:0>2}:{d:0>2}:{d:0>2}.{d:0>6}][+{d}us][{s}][{s}] ",
            .{ tod.h, tod.m, tod.s, tod.us, ts_us, level_name, self.name },
        ) catch |err| {
            const fallback_prefix = "[app.logger][Warning] ";
            if (emit_file) {
                log_mutex.lock();
                defer log_mutex.unlock();
                if (log_file) |file| {
                    writeLogLine(file, fallback_prefix, msg) catch {};
                }
            }
            if (emit_console) {
                std.debug.print("{s}{s}\n", .{ fallback_prefix, msg });
            }
            std.debug.print("[app.logger][Warning][{s}] prefix formatting failed: {s}\n", .{ self.name, @errorName(err) });
            return;
        };

        if (emit_file) {
            log_mutex.lock();
            defer log_mutex.unlock();
            if (log_file) |file| {
                writeLogLine(file, prefix, msg) catch |err| {
                    log_file = null;
                    std.debug.print("[app.logger] disabled file sink after write failure: {s}\n", .{@errorName(err)});
                };
            }
        }

        if (emit_console) {
            std.debug.print("{s}", .{prefix});
            std.debug.print("{s}\n", .{msg});
        }
    }

    pub fn logStdout(self: Logger, level: Level, comptime fmt: []const u8, args: anytype) void {
        const emit_file = self.enabled_file and log_file != null and shouldEmit(level, self.file_level);
        const emit_console = self.enabled_console and shouldEmit(level, self.console_level);
        if (!emit_file and !emit_console) return;

        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, fmt, args) catch |err| {
            std.debug.print("[app.logger][Warning][{s}] dropped log message due to fmt error: {s}\n", .{ self.name, @errorName(err) });
            return;
        };
        const ts_us = timestampMicros();
        const tod = timeOfDayMicrosUtc();
        const level_name = levelName(level);
        var prefix_buf: [128]u8 = undefined;
        const prefix = std.fmt.bufPrint(
            &prefix_buf,
            "[{d:0>2}:{d:0>2}:{d:0>2}.{d:0>6}][+{d}us][{s}][{s}] ",
            .{ tod.h, tod.m, tod.s, tod.us, ts_us, level_name, self.name },
        ) catch |err| {
            const fallback_prefix = "[app.logger][Warning] ";
            if (emit_console) {
                std.debug.print("{s}{s}\n", .{ fallback_prefix, msg });
            }
            if (emit_file) {
                log_mutex.lock();
                defer log_mutex.unlock();
                if (log_file) |file| {
                    writeLogLine(file, fallback_prefix, msg) catch {};
                }
            }
            std.debug.print("[app.logger][Warning][{s}] prefix formatting failed: {s}\n", .{ self.name, @errorName(err) });
            return;
        };

        if (emit_console) {
            std.debug.print("{s}", .{prefix});
            std.debug.print("{s}\n", .{msg});
        }
        if (emit_file) {
            log_mutex.lock();
            defer log_mutex.unlock();
            if (log_file) |file| {
                writeLogLine(file, prefix, msg) catch |err| {
                    log_file = null;
                    std.debug.print("[app.logger] disabled file sink after write failure: {s}\n", .{@errorName(err)});
                };
            }
        }
    }
};

pub fn logger(name: []const u8) Logger {
    return .{
        .name = name,
        .enabled_file = isEnabled(name, log_filter_file, "ZIDE_LOG_FILE\x00"),
        .enabled_console = isEnabled(name, log_filter_console, "ZIDE_LOG_CONSOLE\x00"),
        .file_level = effectiveLevel(name, log_level_overrides_file, "ZIDE_LOG_FILE_LEVELS\x00", log_level_file),
        .console_level = effectiveLevel(name, log_level_overrides_console, "ZIDE_LOG_CONSOLE_LEVELS\x00", log_level_console),
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

pub fn setFileLevel(level: Level) void {
    log_level_file = level;
}

pub fn setConsoleLevel(level: Level) void {
    log_level_console = level;
}

pub fn setFileLevelOverrideString(value: []const u8) !void {
    if (log_level_overrides_file) |overrides| {
        std.heap.c_allocator.free(overrides);
    }
    log_level_overrides_file = try std.heap.c_allocator.dupe(u8, value);
}

pub fn setConsoleLevelOverrideString(value: []const u8) !void {
    if (log_level_overrides_console) |overrides| {
        std.heap.c_allocator.free(overrides);
    }
    log_level_overrides_console = try std.heap.c_allocator.dupe(u8, value);
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

fn effectiveLevel(name: []const u8, overrides_override: ?[]u8, env_key: [:0]const u8, fallback: Level) Level {
    const raw = if (overrides_override) |overrides|
        overrides
    else if (std.c.getenv(env_key)) |env|
        std.mem.sliceTo(env, 0)
    else
        return fallback;
    return levelOverrideFor(name, raw) orelse fallback;
}

fn levelOverrideFor(name: []const u8, raw: []const u8) ?Level {
    if (raw.len == 0) return null;

    var it = std.mem.splitScalar(u8, raw, ',');
    while (it.next()) |chunk| {
        const trimmed = std.mem.trim(u8, chunk, " \t");
        if (trimmed.len == 0) continue;
        const eq_index = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
        const key = std.mem.trim(u8, trimmed[0..eq_index], " \t");
        const value = std.mem.trim(u8, trimmed[eq_index + 1 ..], " \t");
        if (key.len == 0 or value.len == 0) continue;
        if (!std.mem.eql(u8, key, name)) continue;
        if (levelFromString(value)) |level| return level;
    }
    return null;
}

test "levelOverrideFor parses exact tag overrides" {
    try std.testing.expectEqual(@as(?Level, .debug), levelOverrideFor("terminal.ui.redraw", "terminal.ui.redraw=debug,terminal.ui.perf=info"));
    try std.testing.expectEqual(@as(?Level, .info), levelOverrideFor("terminal.ui.perf", "terminal.ui.redraw=debug, terminal.ui.perf = info "));
    try std.testing.expectEqual(@as(?Level, null), levelOverrideFor("terminal.ui.lifecycle", "terminal.ui.redraw=debug"));
}

test "resetConfig clears logger filters and level overrides" {
    defer deinit();

    try setFileFilterString("terminal.ui.redraw");
    try setConsoleFilterString("terminal.ui.redraw");
    setFileLevel(.warning);
    setConsoleLevel(.warning);
    try setFileLevelOverrideString("terminal.ui.redraw=debug");
    try setConsoleLevelOverrideString("terminal.ui.redraw=trace");

    try std.testing.expect(logger("terminal.ui.redraw").enabled_file);
    try std.testing.expectEqual(Level.debug, logger("terminal.ui.redraw").file_level);
    try std.testing.expectEqual(Level.trace, logger("terminal.ui.redraw").console_level);

    resetConfig();

    try std.testing.expect(!logger("terminal.ui.redraw").enabled_file);
    try std.testing.expect(!logger("terminal.ui.redraw").enabled_console);
    try std.testing.expectEqual(Level.info, logger("terminal.ui.redraw").file_level);
    try std.testing.expectEqual(Level.info, logger("terminal.ui.redraw").console_level);
}
