const std = @import("std");
const zlua = @import("zlua");
const zlua_portable = @import("zlua_portable");
const config_reader = @import("./lua_config_reader.zig");
const iface = @import("./lua_config_iface.zig");
const app_logger = @import("../app_logger.zig");

const Config = iface.Config;
const LogGroupConfig = iface.LogGroupConfig;
const LogLevel = std.meta.Child(@TypeOf((@as(Config, undefined)).log_file_level));
const SdlLogLevel = std.meta.Child(@TypeOf((@as(Config, undefined)).sdl_log_level));

fn luaState(lua: *zlua.Lua) zlua_portable.api.State {
    return zlua_portable.api.State.fromRaw(@ptrCast(lua));
}

fn wrapReader(
    lua: *zlua.Lua,
    allocator: std.mem.Allocator,
    reader: zlua_portable.reader.Reader,
) config_reader.Reader {
    return .{
        .lua = lua,
        .allocator = allocator,
        .state = reader.state,
        .table = reader,
    };
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

fn parseLogLevelField(reader: config_reader.Reader, field: []const u8) ?LogLevel {
    const value = reader.fieldString(field) orelse return null;
    return parseLoggerLevelFromString(value);
}

fn parseOutputModeField(reader: config_reader.Reader, field: []const u8) ?app_logger.OutputMode {
    const value = reader.fieldString(field) orelse return null;
    return parseLoggerOutputModeFromString(value);
}

fn parseSdlLogLevelField(reader: config_reader.Reader, field: []const u8) ?SdlLogLevel {
    const value = reader.fieldString(field) orelse return null;
    return parseSdlLogLevelFromString(value);
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
    const reader = config_reader.Reader.init(lua, allocator, table_index);

    if (try reader.stringOrStringListOwned("log")) |v| {
        out.log_file_filter = v;
        out.log_console_filter = try allocator.dupe(u8, v);
    }

    if (try reader.ownedStringField("log_file_path")) |v| out.log_file_path = v;

    if (try reader.stringOrStringListOwned("log_file_filter")) |v| out.log_file_filter = v;

    if (try reader.stringOrStringListOwned("log_console_filter")) |v| out.log_console_filter = v;

    if (parseLogLevelField(reader, "log_file_level")) |level| out.log_file_level = level;

    if (parseLogLevelField(reader, "log_console_level")) |level| out.log_console_level = level;

    _ = lua.getField(table_index, "log_file_level_overrides");
    if (try parseLevelOverrideValueOwned(allocator, lua, -1)) |v| out.log_file_level_overrides = v;
    lua.pop(1);

    _ = lua.getField(table_index, "log_console_level_overrides");
    if (try parseLevelOverrideValueOwned(allocator, lua, -1)) |v| out.log_console_level_overrides = v;
    lua.pop(1);

    if (parseOutputModeField(reader, "log_file_output_mode")) |mode| out.log_file_output_mode = mode;

    if (parseOutputModeField(reader, "log_console_output_mode")) |mode| out.log_console_output_mode = mode;

    if (reader.childReader("logs")) |logs_reader| {
        defer logs_reader.table.finish();
        const logs_idx = logs_reader.table.index;

        if (try logs_reader.stringOrStringListOwned("file")) |v| {
            replaceOwnedString(allocator, &out.log_file_filter, v);
        }

        if (try logs_reader.ownedStringField("file_path")) |v| {
            replaceOwnedString(allocator, &out.log_file_path, v);
        }

        if (try logs_reader.stringOrStringListOwned("console")) |v| {
            replaceOwnedString(allocator, &out.log_console_filter, v);
        }

        if (try logs_reader.stringOrStringListOwned("enable")) |v| {
            if (out.log_file_filter == null) {
                out.log_file_filter = v;
            } else {
                allocator.free(v);
            }
            if (out.log_console_filter == null) {
                if (out.log_file_filter) |file_v| out.log_console_filter = try allocator.dupe(u8, file_v);
            }
        }

        if (parseLogLevelField(logs_reader, "file_level")) |level| out.log_file_level = level;

        _ = lua.getField(logs_idx, "file_levels");
        if (try parseLevelOverrideValueOwned(allocator, lua, -1)) |v| replaceOwnedString(allocator, &out.log_file_level_overrides, v);
        lua.pop(1);

        _ = lua.getField(logs_idx, "console_levels");
        if (try parseLevelOverrideValueOwned(allocator, lua, -1)) |v| replaceOwnedString(allocator, &out.log_console_level_overrides, v);
        lua.pop(1);

        if (parseLogLevelField(logs_reader, "console_level")) |level| out.log_console_level = level;

        if (parseOutputModeField(logs_reader, "mode")) |mode| {
            if (out.log_file_output_mode == null) out.log_file_output_mode = mode;
            if (out.log_console_output_mode == null) out.log_console_output_mode = mode;
        }

        if (parseOutputModeField(logs_reader, "file_mode")) |mode| out.log_file_output_mode = mode;

        if (parseOutputModeField(logs_reader, "console_mode")) |mode| out.log_console_output_mode = mode;

        _ = lua.getField(logs_idx, "groups");
        if (try parseLogGroupsOwned(allocator, lua, -1)) |groups| {
            out.log_groups = groups;
        }
        lua.pop(1);
    }

    if (parseSdlLogLevelField(reader, "sdl_log_level")) |lvl| out.sdl_log_level = lvl;

    if (reader.child("sdl")) |sdl_reader| {
        defer sdl_reader.finish();
        if (parseSdlLogLevelField(wrapReader(lua, allocator, sdl_reader), "log_level")) |lvl| {
            out.sdl_log_level = lvl;
        }
    }

}
