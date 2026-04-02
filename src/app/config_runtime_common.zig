const std = @import("std");
const app_logger = @import("../app_logger.zig");
const config_mod = @import("../config/lua_config.zig");
const term_types = @import("../terminal/model/types.zig");

pub fn resolveTerminalDefaultStartLocation(
    allocator: std.mem.Allocator,
    configured: ?[]const u8,
) !?[]u8 {
    const home = blk: {
        if (std.c.getenv("HOME")) |value| break :blk std.mem.sliceTo(value, 0);
        if (std.c.getenv("USERPROFILE")) |value| break :blk std.mem.sliceTo(value, 0);
        break :blk null;
    };
    const raw = configured orelse home orelse return null;
    if (raw.len == 0) return null;

    if (raw[0] == '~' and home != null) {
        if (raw.len == 1) return try allocator.dupe(u8, home.?);
        if (raw.len >= 2 and raw[1] == '/') {
            return try std.fs.path.join(allocator, &.{ home.?, raw[2..] });
        }
    }

    return try allocator.dupe(u8, raw);
}

pub fn resolveTerminalShellPath(
    allocator: std.mem.Allocator,
    configured: ?[]const u8,
) !?[]u8 {
    const raw = configured orelse return null;
    if (raw.len == 0) return null;
    return try allocator.dupe(u8, raw);
}

pub fn applyLoggerConfig(config: *const config_mod.Config, comptime prefix: []const u8) void {
    app_logger.resetConfig();
    if (config.log_file_filter) |filter| {
        app_logger.setFileFilterString(filter) catch |err| {
            std.debug.print("{s} log file filter parse error: {any}\n", .{ prefix, err });
        };
    }
    if (config.log_console_filter) |filter| {
        app_logger.setConsoleFilterString(filter) catch |err| {
            std.debug.print("{s} log console filter parse error: {any}\n", .{ prefix, err });
        };
    }
    if (config.log_file_level) |level| {
        app_logger.setFileLevel(level);
    }
    if (config.log_console_level) |level| {
        app_logger.setConsoleLevel(level);
    }
    if (config.log_file_level_overrides) |value| {
        app_logger.setFileLevelOverrideString(value) catch |err| {
            std.debug.print("{s} log file level overrides parse error: {any}\n", .{ prefix, err });
        };
    }
    if (config.log_console_level_overrides) |value| {
        app_logger.setConsoleLevelOverrideString(value) catch |err| {
            std.debug.print("{s} log console level overrides parse error: {any}\n", .{ prefix, err });
        };
    }
    if (config.log_file_output_mode) |mode| {
        app_logger.setFileOutputMode(mode);
    }
    if (config.log_console_output_mode) |mode| {
        app_logger.setConsoleOutputMode(mode);
    }
    if (config.log_groups) |groups| {
        app_logger.setGroupSinks(groups) catch |err| {
            std.debug.print("{s} log group sink setup error: {any}\n", .{ prefix, err });
        };
    }
}

pub fn resolveTerminalCursorStyle(config: *const config_mod.Config) ?term_types.CursorStyle {
    if (config.terminal_cursor_shape == null and config.terminal_cursor_blink == null) return null;

    var cursor_style = term_types.default_cursor_style;
    if (config.terminal_cursor_shape) |shape| {
        cursor_style.shape = shape;
    }
    if (config.terminal_cursor_blink) |blink| {
        cursor_style.blink = blink;
    }
    return cursor_style;
}
