const std = @import("std");
const zlua = @import("zlua");
const zlua_portable = @import("zlua_portable");
const iface = @import("./lua_config_iface.zig");
const app_logger = @import("../app_logger.zig");

const Config = iface.Config;
const LogGroupConfig = iface.LogGroupConfig;
const LogLevel = std.meta.Child(@TypeOf((@as(Config, undefined)).log_file_level));
const SdlLogLevel = std.meta.Child(@TypeOf((@as(Config, undefined)).sdl_log_level));

fn luaState(lua: *zlua.Lua) zlua_portable.api.State {
    return zlua_portable.api.State.fromRaw(@ptrCast(lua));
}

fn replaceOwnedString(allocator: std.mem.Allocator, slot: *?[]u8, value: ?[]u8) void {
    if (slot.*) |old| allocator.free(old);
    slot.* = value;
}

pub fn parseFilterValueOwned(allocator: std.mem.Allocator, lua: *zlua.Lua, idx: i32) !?[]u8 {
    const state = luaState(lua);
    if (state.readString(idx)) |v| {
        return try allocator.dupe(u8, v);
    }
    if (!state.isTable(idx)) return null;

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    const reader = zlua_portable.reader.Reader.init(state, allocator, idx);
    var it = reader.iter();
    defer it.finish();
    while (it.next()) {
        if (it.valueString()) |s| {
            if (out.items.len > 0) try out.append(allocator, ',');
            try out.appendSlice(allocator, s);
        }
    }
    return try out.toOwnedSlice(allocator);
}

fn parseLevelOverrideValueOwned(allocator: std.mem.Allocator, lua: *zlua.Lua, idx: i32) !?[]u8 {
    const state = luaState(lua);
    if (state.readString(idx)) |v| {
        return try allocator.dupe(u8, v);
    }
    if (!state.isTable(idx)) return null;

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    const reader = zlua_portable.reader.Reader.init(state, allocator, idx);
    var it = reader.iter();
    defer it.finish();
    while (it.next()) {
        const key = it.keyString() orelse continue;
        const value = it.valueString() orelse continue;
        if (parseLoggerLevelFromString(value) == null) continue;
        if (out.items.len > 0) try out.append(allocator, ',');
        try out.appendSlice(allocator, key);
        try out.append(allocator, '=');
        try out.appendSlice(allocator, value);
    }
    return try out.toOwnedSlice(allocator);
}

fn parseSdlLogLevelFromString(value: []const u8) ?SdlLogLevel {
    if (std.mem.eql(u8, value, "critical")) return 6;
    if (std.mem.eql(u8, value, "error")) return 5;
    if (std.mem.eql(u8, value, "warning")) return 4;
    if (std.mem.eql(u8, value, "warn")) return 4;
    if (std.mem.eql(u8, value, "info")) return 3;
    if (std.mem.eql(u8, value, "debug")) return 2;
    if (std.mem.eql(u8, value, "trace")) return 1;
    return null;
}

fn parseLoggerLevelFromString(value: []const u8) ?LogLevel {
    return app_logger.levelFromString(value);
}

fn parseLoggerOutputModeFromString(value: []const u8) ?app_logger.OutputMode {
    return app_logger.outputModeFromString(value);
}

fn defaultLogGroupFileName(
    allocator: std.mem.Allocator,
    group_name: []const u8,
    mode: ?app_logger.OutputMode,
) ![]u8 {
    const suffix = switch (mode orelse .text) {
        .text => ".log",
        .jsonl => ".jsonl",
    };
    return try std.fmt.allocPrint(allocator, "zide-{s}{s}", .{ group_name, suffix });
}

fn parseLogGroupsOwned(allocator: std.mem.Allocator, lua: *zlua.Lua, idx: i32) !?[]LogGroupConfig {
    const state = luaState(lua);
    if (!state.isTable(idx)) return null;

    var groups = std.ArrayList(LogGroupConfig).empty;
    errdefer {
        for (groups.items) |*group| {
            allocator.free(group.name);
            allocator.free(group.file);
            allocator.free(group.tags);
        }
        groups.deinit(allocator);
    }

    const reader = zlua_portable.reader.Reader.init(state, allocator, idx);
    var it = reader.iter();
    defer it.finish();
    while (it.next()) {
        const group_name = it.keyString() orelse continue;
        if (group_name.len == 0) continue;

        if (!reader.state.isTable(-1)) continue;
        const group_reader = zlua_portable.reader.Reader.init(reader.state, allocator, -1);
        defer group_reader.finish();

        const tags = if (group_reader.child("tags")) |tags_reader| blk: {
            defer tags_reader.finish();
            break :blk try parseFilterValueOwned(allocator, lua, -1);
        } else null;
        if (tags == null or tags.?.len == 0) {
            if (tags) |value| allocator.free(value);
            continue;
        }

        var mode: ?app_logger.OutputMode = null;
        if (group_reader.fieldString("mode")) |value| {
            mode = parseLoggerOutputModeFromString(value);
        }

        var file_path: ?[]u8 = null;
        if (group_reader.fieldString("file")) |value| {
            file_path = try allocator.dupe(u8, value);
        }

        const resolved_file = file_path orelse try defaultLogGroupFileName(allocator, group_name, mode);
        try groups.append(allocator, .{
            .name = try allocator.dupe(u8, group_name),
            .file = resolved_file,
            .tags = tags.?,
            .mode = mode,
        });
    }

    return try groups.toOwnedSlice(allocator);
}

pub fn parseLogSettings(allocator: std.mem.Allocator, lua: *zlua.Lua, table_index: i32, out: *Config) !void {
    _ = lua.getField(table_index, "log");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            out.log_file_filter = try allocator.dupe(u8, v);
            out.log_console_filter = try allocator.dupe(u8, v);
        } else |_| {}
    } else if (lua.isTable(-1)) {
        if (try parseFilterValueOwned(allocator, lua, -1)) |v| {
            out.log_file_filter = v;
            out.log_console_filter = try allocator.dupe(u8, v);
        }
    }
    lua.pop(1);

    _ = lua.getField(table_index, "log_file_filter");
    const log_file_direct = try parseFilterValueOwned(allocator, lua, -1);
    if (log_file_direct) |v| out.log_file_filter = v;
    lua.pop(1);

    _ = lua.getField(table_index, "log_console_filter");
    const log_console_direct = try parseFilterValueOwned(allocator, lua, -1);
    if (log_console_direct) |v| out.log_console_filter = v;
    lua.pop(1);

    _ = lua.getField(table_index, "log_file_level");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseLoggerLevelFromString(v)) |level| out.log_file_level = level;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "log_console_level");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseLoggerLevelFromString(v)) |level| out.log_console_level = level;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "log_file_level_overrides");
    if (try parseLevelOverrideValueOwned(allocator, lua, -1)) |v| out.log_file_level_overrides = v;
    lua.pop(1);

    _ = lua.getField(table_index, "log_console_level_overrides");
    if (try parseLevelOverrideValueOwned(allocator, lua, -1)) |v| out.log_console_level_overrides = v;
    lua.pop(1);

    _ = lua.getField(table_index, "log_file_output_mode");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseLoggerOutputModeFromString(v)) |mode| out.log_file_output_mode = mode;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "log_console_output_mode");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseLoggerOutputModeFromString(v)) |mode| out.log_console_output_mode = mode;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "logs");
    if (lua.isTable(-1)) {
        const logs_idx = lua.absIndex(-1);

        _ = lua.getField(logs_idx, "file");
        if (try parseFilterValueOwned(allocator, lua, -1)) |v| replaceOwnedString(allocator, &out.log_file_filter, v);
        lua.pop(1);

        _ = lua.getField(logs_idx, "console");
        if (try parseFilterValueOwned(allocator, lua, -1)) |v| replaceOwnedString(allocator, &out.log_console_filter, v);
        lua.pop(1);

        _ = lua.getField(logs_idx, "enable");
        if (try parseFilterValueOwned(allocator, lua, -1)) |v| {
            if (out.log_file_filter == null) {
                out.log_file_filter = v;
            } else {
                allocator.free(v);
            }
            if (out.log_console_filter == null) {
                if (out.log_file_filter) |file_v| out.log_console_filter = try allocator.dupe(u8, file_v);
            }
        }
        lua.pop(1);

        _ = lua.getField(logs_idx, "file_level");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseLoggerLevelFromString(v)) |level| out.log_file_level = level;
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(logs_idx, "file_levels");
        if (try parseLevelOverrideValueOwned(allocator, lua, -1)) |v| replaceOwnedString(allocator, &out.log_file_level_overrides, v);
        lua.pop(1);

        _ = lua.getField(logs_idx, "console_levels");
        if (try parseLevelOverrideValueOwned(allocator, lua, -1)) |v| replaceOwnedString(allocator, &out.log_console_level_overrides, v);
        lua.pop(1);

        _ = lua.getField(logs_idx, "console_level");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseLoggerLevelFromString(v)) |level| out.log_console_level = level;
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(logs_idx, "mode");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseLoggerOutputModeFromString(v)) |mode| {
                    if (out.log_file_output_mode == null) out.log_file_output_mode = mode;
                    if (out.log_console_output_mode == null) out.log_console_output_mode = mode;
                }
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(logs_idx, "file_mode");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseLoggerOutputModeFromString(v)) |mode| out.log_file_output_mode = mode;
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(logs_idx, "console_mode");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseLoggerOutputModeFromString(v)) |mode| out.log_console_output_mode = mode;
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(logs_idx, "groups");
        if (try parseLogGroupsOwned(allocator, lua, -1)) |groups| {
            out.log_groups = groups;
        }
        lua.pop(1);
    }
    lua.pop(1);

    _ = lua.getField(table_index, "sdl_log_level");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseSdlLogLevelFromString(v)) |lvl| out.sdl_log_level = lvl;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "sdl");
    if (lua.isTable(-1)) {
        const sdl_idx = lua.absIndex(-1);
        _ = lua.getField(sdl_idx, "log_level");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseSdlLogLevelFromString(v)) |lvl| out.sdl_log_level = lvl;
            } else |_| {}
        }
        lua.pop(1);
    }
    lua.pop(1);

    if (out.sdl_log_level == null) {
        _ = lua.getField(table_index, "raylib");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseSdlLogLevelFromString(v)) |lvl| out.sdl_log_level = lvl;
            } else |_| {}
        } else if (lua.isTable(-1)) {
            const raylib_idx = lua.absIndex(-1);
            _ = lua.getField(raylib_idx, "log_level");
            if (lua.isString(-1)) {
                if (lua.toString(-1)) |v| {
                    if (parseSdlLogLevelFromString(v)) |lvl| out.sdl_log_level = lvl;
                } else |_| {}
            }
            lua.pop(1);
        }
        lua.pop(1);
    }
}
