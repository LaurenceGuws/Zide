const builtin = @import("builtin");
const std = @import("std");

var log_file: ?std.fs.File = null;
var log_mutex: std.Thread.Mutex = .{};
var log_filter_file: ?[]u8 = null;
var log_filter_console: ?[]u8 = null;
var log_file_path: ?[]u8 = null;
var log_level_file: Level = .info;
var log_level_console: Level = .info;
var log_level_overrides_file: ?[]u8 = null;
var log_level_overrides_console: ?[]u8 = null;
var log_start_ns: i128 = 0;
var log_output_mode_file: OutputMode = .text;
var log_output_mode_console: OutputMode = .text;
var log_group_sinks: ?[]GroupSink = null;

pub const Level = enum(u8) {
    critical = 0,
    @"error" = 1,
    warning = 2,
    info = 3,
    debug = 4,
    trace = 5,
};

pub const OutputMode = enum {
    text,
    jsonl,
};

pub const FieldValue = union(enum) {
    string: []const u8,
    integer: i64,
    unsigned: u64,
    boolean: bool,
    float: f64,
};

pub const Field = struct {
    key: []const u8,
    value: FieldValue,
};

const TimeOfDayMicros = struct {
    h: i64,
    m: i64,
    s: i64,
    us: i64,
};

pub const GroupSinkConfig = struct {
    name: []const u8,
    file: []const u8,
    tags: []const u8,
    mode: OutputMode = .text,
};

const GroupSink = struct {
    name: []u8,
    tags: []u8,
    mode: OutputMode,
    file: std.fs.File,
    active: bool,
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

pub fn outputModeFromString(value: []const u8) ?OutputMode {
    if (std.ascii.eqlIgnoreCase(value, "text")) return .text;
    if (std.ascii.eqlIgnoreCase(value, "jsonl")) return .jsonl;
    if (std.ascii.eqlIgnoreCase(value, "json")) return .jsonl;
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

fn timeOfDayMicrosUtc() TimeOfDayMicros {
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

fn openLogFile(path: []const u8) !std.fs.File {
    if (std.fs.path.dirname(path)) |dir_path| {
        if (dir_path.len != 0) try std.fs.cwd().makePath(dir_path);
    }
    var file = try std.fs.cwd().createFile(path, .{ .truncate = false, .read = false });
    try file.seekFromEnd(0);
    return file;
}

fn openWindowsFallbackLogFile() !std.fs.File {
    const local_appdata = std.c.getenv("LOCALAPPDATA") orelse return error.FileNotFound;
    const base = std.mem.sliceTo(local_appdata, 0);
    const dir_path = try std.fs.path.join(std.heap.c_allocator, &.{ base, "Zide" });
    defer std.heap.c_allocator.free(dir_path);

    std.fs.cwd().makePath(dir_path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const file_path = try std.fs.path.join(std.heap.c_allocator, &.{ dir_path, "zide.log" });
    defer std.heap.c_allocator.free(file_path);
    return openLogFile(file_path);
}

fn defaultLogFilePath() []const u8 {
    if (builtin.target.abi == .android) return "/data/user/0/dev.zide.terminal/files/home/.local/state/zide/zide.log";
    return "zide.log";
}

pub fn init() !void {
    if (log_file != null) return;
    const path = log_file_path orelse defaultLogFilePath();
    log_file = openLogFile(path) catch |err| blk: {
        if (builtin.target.os.tag == .windows and err == error.AccessDenied) {
            break :blk try openWindowsFallbackLogFile();
        }
        return err;
    };
    if (log_start_ns == 0) log_start_ns = std.time.nanoTimestamp();
}

pub fn deinit() void {
    clearGroupSinks();
    if (log_file) |file| {
        file.close();
    }
    log_file = null;
    resetConfig();
    log_start_ns = 0;
}

pub fn resetConfig() void {
    clearGroupSinks();
    if (log_filter_file) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter_file = null;
    if (log_filter_console) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter_console = null;
    if (log_file_path) |path| {
        std.heap.c_allocator.free(path);
    }
    log_file_path = null;
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
    log_output_mode_file = .text;
    log_output_mode_console = .text;
}

pub const Logger = struct {
    name: []const u8,
    enabled_file: bool,
    enabled_console: bool,
    file_level: Level,
    console_level: Level,
    file_output_mode: OutputMode,
    console_output_mode: OutputMode,

    pub fn logfSrc(self: Logger, level: Level, src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
        self.logf(level, "{s}:{d} " ++ fmt, .{ src.file, src.line } ++ args);
    }

    pub fn logf(self: Logger, level: Level, comptime fmt: []const u8, args: anytype) void {
        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, fmt, args) catch |err| {
            std.debug.print("[app.logger][Warning][{s}] dropped log message due to fmt error: {s}\n", .{ self.name, @errorName(err) });
            return;
        };
        self.emit(level, msg, &.{});
    }

    pub fn logFields(self: Logger, level: Level, msg: []const u8, fields: []const Field) void {
        self.emit(level, msg, fields);
    }

    fn emit(self: Logger, level: Level, msg: []const u8, fields: []const Field) void {
        const emit_file = self.enabled_file and log_file != null and shouldEmit(level, self.file_level);
        const emit_console = self.enabled_console and shouldEmit(level, self.console_level);
        if (!emit_file and !emit_console and !shouldEmit(level, self.file_level)) return;

        const ts_us = timestampMicros();
        const tod = timeOfDayMicrosUtc();
        const level_name = levelName(level);
        const emit_group = shouldEmit(level, self.file_level) and groupSinkEnabled(self.name);
        if (emit_file or emit_group) {
            log_mutex.lock();
            defer log_mutex.unlock();
            if (log_file) |file| {
                if (emit_file) {
                    writeFormattedLine(file, self.file_output_mode, tod, ts_us, level_name, self.name, msg, fields) catch |err| {
                        log_file = null;
                        std.debug.print("[app.logger] disabled file sink after write failure: {s}\n", .{@errorName(err)});
                    };
                }
            }
            if (emit_group) {
                writeGroupLines(tod, ts_us, level_name, self.name, msg, fields);
            }
        }

        if (emit_console) {
            writeConsoleLine(self.console_output_mode, tod, ts_us, level_name, self.name, msg, fields) catch |err| {
                std.debug.print("[app.logger][Warning][{s}] console formatting failed: {s}\n", .{ self.name, @errorName(err) });
            };
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
        if (emit_console) {
            writeConsoleLine(self.console_output_mode, tod, ts_us, level_name, self.name, msg, &.{}) catch |err| {
                std.debug.print("[app.logger][Warning][{s}] console formatting failed: {s}\n", .{ self.name, @errorName(err) });
            };
        }
        const emit_group = shouldEmit(level, self.file_level) and groupSinkEnabled(self.name);
        if (emit_file or emit_group) {
            log_mutex.lock();
            defer log_mutex.unlock();
            if (log_file) |file| {
                if (emit_file) {
                    writeFormattedLine(file, self.file_output_mode, tod, ts_us, level_name, self.name, msg, &.{}) catch |err| {
                        log_file = null;
                        std.debug.print("[app.logger] disabled file sink after write failure: {s}\n", .{@errorName(err)});
                    };
                }
            }
            if (emit_group) {
                writeGroupLines(tod, ts_us, level_name, self.name, msg, &.{});
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
        .file_output_mode = log_output_mode_file,
        .console_output_mode = log_output_mode_console,
    };
}

pub fn setFileFilterString(value: []const u8) !void {
    if (log_filter_file) |filter| {
        std.heap.c_allocator.free(filter);
    }
    log_filter_file = try std.heap.c_allocator.dupe(u8, value);
}

pub fn setFilePathString(value: []const u8) !void {
    if (log_file_path) |path| {
        std.heap.c_allocator.free(path);
    }
    log_file_path = try std.heap.c_allocator.dupe(u8, value);
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

pub fn setFileOutputMode(mode: OutputMode) void {
    log_output_mode_file = mode;
}

pub fn setConsoleOutputMode(mode: OutputMode) void {
    log_output_mode_console = mode;
}

pub fn setGroupSinks(configs: anytype) !void {
    clearGroupSinks();
    const source = configs;
    if (source.len == 0) return;

    var sinks = try std.heap.c_allocator.alloc(GroupSink, source.len);
    errdefer std.heap.c_allocator.free(sinks);
    var loaded: usize = 0;
    errdefer {
        for (sinks[0..loaded]) |*sink| {
            sink.file.close();
            std.heap.c_allocator.free(sink.name);
            std.heap.c_allocator.free(sink.tags);
        }
    }

    for (source, 0..) |config, i| {
        sinks[i] = .{
            .name = try std.heap.c_allocator.dupe(u8, config.name),
            .tags = try std.heap.c_allocator.dupe(u8, config.tags),
            .mode = groupConfigMode(config),
            .file = try openLogFile(config.file),
            .active = true,
        };
        loaded += 1;
    }

    log_group_sinks = sinks;
}

fn groupConfigMode(config: anytype) OutputMode {
    return switch (@typeInfo(@TypeOf(config.mode))) {
        .optional => config.mode orelse .text,
        else => config.mode,
    };
}

fn writeFormattedLine(
    file: std.fs.File,
    mode: OutputMode,
    tod: TimeOfDayMicros,
    ts_us: i128,
    level_name: []const u8,
    logger_name: []const u8,
    msg: []const u8,
    fields: []const Field,
) !void {
    switch (mode) {
        .text => {
            var buf: [4096]u8 = undefined;
            const line = try renderTextLine(&buf, tod, ts_us, level_name, logger_name, msg, fields);
            try file.writeAll(line);
            try file.writeAll("\n");
        },
        .jsonl => {
            var buf: [4096]u8 = undefined;
            var stream = std.io.fixedBufferStream(&buf);
            try writeJsonLine(stream.writer(), tod, ts_us, level_name, logger_name, msg, fields);
            try file.writeAll(stream.getWritten());
            try file.writeAll("\n");
        },
    }
}

fn clearGroupSinks() void {
    if (log_group_sinks) |sinks| {
        for (sinks) |*sink| {
            if (sink.active) sink.file.close();
            std.heap.c_allocator.free(sink.name);
            std.heap.c_allocator.free(sink.tags);
        }
        std.heap.c_allocator.free(sinks);
    }
    log_group_sinks = null;
}

fn groupSinkEnabled(logger_name: []const u8) bool {
    const sinks = log_group_sinks orelse return false;
    for (sinks) |sink| {
        if (!sink.active) continue;
        if (filterMatches(logger_name, sink.tags)) return true;
    }
    return false;
}

fn writeGroupLines(
    tod: TimeOfDayMicros,
    ts_us: i128,
    level_name: []const u8,
    logger_name: []const u8,
    msg: []const u8,
    fields: []const Field,
) void {
    const sinks = log_group_sinks orelse return;
    for (sinks) |*sink| {
        if (!sink.active) continue;
        if (!filterMatches(logger_name, sink.tags)) continue;
        writeFormattedLine(sink.file, sink.mode, tod, ts_us, level_name, logger_name, msg, fields) catch |err| {
            std.debug.print("[app.logger] disabled grouped sink {s} after write failure: {s}\n", .{ sink.name, @errorName(err) });
            sink.file.close();
            sink.active = false;
        };
    }
}

fn writeConsoleLine(
    mode: OutputMode,
    tod: TimeOfDayMicros,
    ts_us: i128,
    level_name: []const u8,
    logger_name: []const u8,
    msg: []const u8,
    fields: []const Field,
) !void {
    switch (mode) {
        .text => {
            var buf: [4096]u8 = undefined;
            const line = try renderTextLine(&buf, tod, ts_us, level_name, logger_name, msg, fields);
            std.debug.print("{s}\n", .{line});
        },
        .jsonl => {
            var buf: [4096]u8 = undefined;
            var stream = std.io.fixedBufferStream(&buf);
            try writeJsonLine(stream.writer(), tod, ts_us, level_name, logger_name, msg, fields);
            std.debug.print("{s}\n", .{stream.getWritten()});
        },
    }
}

fn writeJsonLine(
    writer: anytype,
    tod: TimeOfDayMicros,
    ts_us: i128,
    level_name: []const u8,
    logger_name: []const u8,
    msg: []const u8,
    fields: []const Field,
) !void {
    var tod_buf: [32]u8 = undefined;
    const tod_str = try std.fmt.bufPrint(&tod_buf, "{d:0>2}:{d:0>2}:{d:0>2}.{d:0>6}", .{ tod.h, tod.m, tod.s, tod.us });
    try writer.writeByte('{');
    try writer.writeAll("\"ts_wall\":");
    try writeJsonString(writer, tod_str);
    try writer.writeAll(",\"ts_us\":");
    try writer.print("{d}", .{ts_us});
    try writer.writeAll(",\"level\":");
    try writeJsonString(writer, level_name);
    try writer.writeAll(",\"tag\":");
    try writeJsonString(writer, logger_name);
    try writer.writeAll(",\"msg\":");
    try writeJsonString(writer, msg);
    if (fields.len > 0) {
        try writer.writeAll(",\"fields\":{");
        for (fields, 0..) |field, i| {
            if (i != 0) try writer.writeByte(',');
            try writeJsonString(writer, field.key);
            try writer.writeByte(':');
            try writeJsonFieldValue(writer, field.value);
        }
        try writer.writeByte('}');
    }
    try writer.writeByte('}');
}

fn renderTextLine(
    buf: []u8,
    tod: TimeOfDayMicros,
    ts_us: i128,
    level_name: []const u8,
    logger_name: []const u8,
    msg: []const u8,
    fields: []const Field,
) ![]const u8 {
    var stream = std.io.fixedBufferStream(buf);
    const writer = stream.writer();
    try writer.print(
        "[{d:0>2}:{d:0>2}:{d:0>2}.{d:0>6}][+{d}us][{s}][{s}] {s}",
        .{ tod.h, tod.m, tod.s, tod.us, ts_us, level_name, logger_name, msg },
    );
    for (fields) |field| {
        try writer.writeByte(' ');
        try writer.writeAll(field.key);
        try writer.writeByte('=');
        try writeTextFieldValue(writer, field.value);
    }
    return stream.getWritten();
}

fn writeJsonString(writer: anytype, value: []const u8) !void {
    try writer.writeByte('"');
    for (value) |ch| {
        switch (ch) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            0x08 => try writer.writeAll("\\b"),
            0x0C => try writer.writeAll("\\f"),
            else => {
                if (ch < 0x20) {
                    try writer.print("\\u{X:0>4}", .{@as(u8, ch)});
                } else {
                    try writer.writeByte(ch);
                }
            },
        }
    }
    try writer.writeByte('"');
}

fn writeJsonFieldValue(writer: anytype, value: FieldValue) !void {
    switch (value) {
        .string => |v| try writeJsonString(writer, v),
        .integer => |v| try writer.print("{d}", .{v}),
        .unsigned => |v| try writer.print("{d}", .{v}),
        .boolean => |v| try writer.writeAll(if (v) "true" else "false"),
        .float => |v| try writer.print("{d}", .{v}),
    }
}

fn writeTextFieldValue(writer: anytype, value: FieldValue) !void {
    switch (value) {
        .string => |v| try writer.writeAll(v),
        .integer => |v| try writer.print("{d}", .{v}),
        .unsigned => |v| try writer.print("{d}", .{v}),
        .boolean => |v| try writer.writeAll(if (v) "true" else "false"),
        .float => |v| try writer.print("{d:.3}", .{v}),
    }
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
    return filterMatches(name, raw);
}

fn filterMatches(name: []const u8, raw: []const u8) bool {
    if (raw.len == 0) return false;
    if (std.mem.eql(u8, raw, "all")) return true;
    if (std.mem.eql(u8, raw, "none")) return false;

    var it = std.mem.splitScalar(u8, raw, ',');
    while (it.next()) |chunk| {
        const trimmed = std.mem.trim(u8, chunk, " \t");
        if (trimmed.len == 0) continue;
        if (std.mem.endsWith(u8, trimmed, ".*")) {
            const prefix = trimmed[0 .. trimmed.len - 1];
            if (std.mem.startsWith(u8, name, prefix)) return true;
            continue;
        }
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

test "outputModeFromString parses text and jsonl" {
    try std.testing.expectEqual(@as(?OutputMode, .text), outputModeFromString("text"));
    try std.testing.expectEqual(@as(?OutputMode, .jsonl), outputModeFromString("jsonl"));
    try std.testing.expectEqual(@as(?OutputMode, .jsonl), outputModeFromString("json"));
    try std.testing.expectEqual(@as(?OutputMode, null), outputModeFromString("yaml"));
}
