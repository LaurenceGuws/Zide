const std = @import("std");
const zlua_portable = @import("zlua_portable");
const lua_shared = @import("./lua_config_shared.zig");
const lua_config = @import("./lua_config.zig");

const State = zlua_portable.api.State;
const c = zlua_portable.api.c;

pub const ExportScope = enum {
    full,
    editor,
    terminal,
};

pub fn renderStandaloneDefaultConfig(allocator: std.mem.Allocator, scope: ExportScope) ![]u8 {
    const init_path = (try lua_shared.findInstalledAssetPath(allocator, "assets/config/init.lua")) orelse return error.MissingDefaultConfig;
    defer allocator.free(init_path);

    var lua = try State.init();
    defer lua.deinit();
    try lua.loadFile(allocator, init_path);
    if (!lua.topIsTable()) return error.InvalidDefaultConfig;

    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    const writer = out.writer(allocator);

    try writer.writeAll(
        \\-- Zide default config reference (exported standalone for user customization).
        \\-- This file is self-contained and safe to place at ~/.config/zide/init.lua.
        \\---@diagnostic disable: undefined-global
        \\local mod
        \\do
        \\  local ok, loaded = pcall(require, "zide-meta")
        \\  if ok and type(loaded) == "table" then
        \\    mod = loaded
        \\  end
        \\end
        \\---@type ZideModule
        \\local zide
        \\if mod then
        \\  zide = mod
        \\else
        \\  zide = {
        \\    config = function(opts)
        \\      return opts
        \\    end,
        \\  }
        \\end
        \\
        \\---@type ZideConfig
        \\return zide.config(
    );
    try writeLuaRootConfig(writer, lua, lua.absIndex(-1), scope);
    try writer.writeAll("\n)\n");
    return try out.toOwnedSlice(allocator);
}

fn writeLuaRootConfig(writer: anytype, lua: State, idx: c_int, scope: ExportScope) anyerror!void {
    const table_index = lua.absIndex(idx);
    var keys = std.ArrayList([]const u8).empty;
    defer keys.deinit(std.heap.page_allocator);
    var it = lua.tableIter(table_index);
    defer it.finish();
    while (it.next()) {
        const key = it.keyString() orelse return error.UnsupportedLuaTableKey;
        if (rootKeyAllowed(scope, key)) {
            try keys.append(std.heap.page_allocator, key);
        }
    }
    std.mem.sort([]const u8, keys.items, {}, struct {
        fn lessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
            return std.mem.lessThan(u8, lhs, rhs);
        }
    }.lessThan);

    if (keys.items.len == 0) {
        try writer.writeAll("{}");
        return;
    }

    try writer.writeAll("{\n");
    for (keys.items) |key| {
        try writeIndent(writer, 1);
        try writeLuaKey(writer, key);
        try writer.writeAll(" = ");
        lua.getField(table_index, key);
        defer lua.pop(1);
        if (std.mem.eql(u8, key, "keybinds") and scope != .full) {
            try writeScopedKeybinds(writer, lua, lua.absIndex(-1), scope, 1);
        } else {
            try writeLuaValue(writer, lua, lua.absIndex(-1), 1);
        }
        try writer.writeAll(",\n");
    }
    try writer.writeAll("}");
}

fn rootKeyAllowed(scope: ExportScope, key: []const u8) bool {
    return switch (scope) {
        .full => true,
        .editor => std.mem.eql(u8, key, "theme") or
            std.mem.eql(u8, key, "font_rendering") or
            std.mem.eql(u8, key, "selection_overlay") or
            std.mem.eql(u8, key, "editor") or
            std.mem.eql(u8, key, "keybinds"),
        .terminal => std.mem.eql(u8, key, "theme") or
            std.mem.eql(u8, key, "font_rendering") or
            std.mem.eql(u8, key, "selection_overlay") or
            std.mem.eql(u8, key, "terminal") or
            std.mem.eql(u8, key, "keybinds"),
    };
}

fn writeScopedKeybinds(writer: anytype, lua: State, idx: c_int, scope: ExportScope, indent: usize) anyerror!void {
    const table_index = lua.absIndex(idx);
    var keys = std.ArrayList([]const u8).empty;
    defer keys.deinit(std.heap.page_allocator);

    var it = lua.tableIter(table_index);
    defer it.finish();
    while (it.next()) {
        const key = it.keyString() orelse return error.UnsupportedLuaTableKey;
        if (std.mem.eql(u8, key, "global") or
            (scope == .editor and std.mem.eql(u8, key, "editor")) or
            (scope == .terminal and std.mem.eql(u8, key, "terminal")))
        {
            try keys.append(std.heap.page_allocator, key);
        }
    }

    std.mem.sort([]const u8, keys.items, {}, struct {
        fn lessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
            return std.mem.lessThan(u8, lhs, rhs);
        }
    }.lessThan);

    if (keys.items.len == 0) {
        try writer.writeAll("{}");
        return;
    }

    try writer.writeAll("{\n");
    for (keys.items) |key| {
        try writeIndent(writer, indent + 1);
        try writeLuaKey(writer, key);
        try writer.writeAll(" = ");
        lua.getField(table_index, key);
        defer lua.pop(1);
        try writeLuaValue(writer, lua, lua.absIndex(-1), indent + 1);
        try writer.writeAll(",\n");
    }
    try writeIndent(writer, indent);
    try writer.writeAll("}");
}

fn writeLuaValue(writer: anytype, lua: State, idx: c_int, indent: usize) anyerror!void {
    switch (lua.valueType(idx)) {
        c.LUA_TNIL => try writer.writeAll("nil"),
        c.LUA_TBOOLEAN => try writer.writeAll(if (lua.readBoolean(idx)) "true" else "false"),
        c.LUA_TNUMBER => {
            if (lua.isInteger(idx)) {
                try writer.print("{d}", .{lua.readInteger(idx)});
            } else {
                try writer.print("{d}", .{lua.readNumber(idx)});
            }
        },
        c.LUA_TSTRING => try writeLuaString(writer, lua.readString(idx) orelse ""),
        c.LUA_TTABLE => try writeLuaTable(writer, lua, idx, indent),
        else => return error.UnsupportedLuaValue,
    }
}

fn writeLuaTable(writer: anytype, lua: State, idx: c_int, indent: usize) anyerror!void {
    const table_index = lua.absIndex(idx);
    if (isArrayLike(lua, table_index)) {
        try writeLuaArray(writer, lua, table_index, indent);
        return;
    }

    var keys = std.ArrayList([]const u8).empty;
    defer keys.deinit(std.heap.page_allocator);
    var it = lua.tableIter(table_index);
    defer it.finish();
    while (it.next()) {
        const key = it.keyString() orelse return error.UnsupportedLuaTableKey;
        try keys.append(std.heap.page_allocator, key);
    }
    std.mem.sort([]const u8, keys.items, {}, struct {
        fn lessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
            return std.mem.lessThan(u8, lhs, rhs);
        }
    }.lessThan);

    if (keys.items.len == 0) {
        try writer.writeAll("{}");
        return;
    }

    try writer.writeAll("{\n");
    for (keys.items) |key| {
        try writeIndent(writer, indent + 1);
        try writeLuaKey(writer, key);
        try writer.writeAll(" = ");
        lua.getField(table_index, key);
        defer lua.pop(1);
        try writeLuaValue(writer, lua, lua.absIndex(-1), indent + 1);
        try writer.writeAll(",\n");
    }
    try writeIndent(writer, indent);
    try writer.writeAll("}");
}

fn writeLuaArray(writer: anytype, lua: State, idx: c_int, indent: usize) anyerror!void {
    const table_index = lua.absIndex(idx);
    const len = lua.rawLen(table_index);
    if (len == 0) {
        try writer.writeAll("{}");
        return;
    }

    try writer.writeAll("{\n");
    var i: usize = 1;
    while (i <= len) : (i += 1) {
        try writeIndent(writer, indent + 1);
        lua.rawGetIndex(table_index, i);
        defer lua.pop(1);
        try writeLuaValue(writer, lua, lua.absIndex(-1), indent + 1);
        try writer.writeAll(",\n");
    }
    try writeIndent(writer, indent);
    try writer.writeAll("}");
}

fn isArrayLike(lua: State, idx: c_int) bool {
    const table_index = lua.absIndex(idx);
    const len = lua.rawLen(table_index);
    if (len == 0) return false;

    var count: usize = 0;
    var it = lua.tableIter(table_index);
    defer it.finish();
    while (it.next()) {
        if (!lua.isInteger(-2)) return false;
        const key = lua.readInteger(-2);
        if (key < 1) return false;
        count += 1;
    }
    return count == len;
}

fn writeLuaKey(writer: anytype, key: []const u8) anyerror!void {
    if (isLuaIdentifier(key)) {
        try writer.writeAll(key);
        return;
    }
    try writer.writeAll("[");
    try writeLuaString(writer, key);
    try writer.writeAll("]");
}

fn isLuaIdentifier(key: []const u8) bool {
    if (key.len == 0) return false;
    if (!(std.ascii.isAlphabetic(key[0]) or key[0] == '_')) return false;
    for (key[1..]) |ch| {
        if (!(std.ascii.isAlphanumeric(ch) or ch == '_')) return false;
    }
    return !std.mem.eql(u8, key, "and") and
        !std.mem.eql(u8, key, "break") and
        !std.mem.eql(u8, key, "do") and
        !std.mem.eql(u8, key, "else") and
        !std.mem.eql(u8, key, "elseif") and
        !std.mem.eql(u8, key, "end") and
        !std.mem.eql(u8, key, "false") and
        !std.mem.eql(u8, key, "for") and
        !std.mem.eql(u8, key, "function") and
        !std.mem.eql(u8, key, "goto") and
        !std.mem.eql(u8, key, "if") and
        !std.mem.eql(u8, key, "in") and
        !std.mem.eql(u8, key, "local") and
        !std.mem.eql(u8, key, "nil") and
        !std.mem.eql(u8, key, "not") and
        !std.mem.eql(u8, key, "or") and
        !std.mem.eql(u8, key, "repeat") and
        !std.mem.eql(u8, key, "return") and
        !std.mem.eql(u8, key, "then") and
        !std.mem.eql(u8, key, "true") and
        !std.mem.eql(u8, key, "until") and
        !std.mem.eql(u8, key, "while");
}

fn writeLuaString(writer: anytype, value: []const u8) anyerror!void {
    try writer.writeByte('"');
    for (value) |ch| switch (ch) {
        '\\' => try writer.writeAll("\\\\"),
        '"' => try writer.writeAll("\\\""),
        '\n' => try writer.writeAll("\\n"),
        '\r' => try writer.writeAll("\\r"),
        '\t' => try writer.writeAll("\\t"),
        else => {
            if (std.ascii.isPrint(ch)) {
                try writer.writeByte(ch);
            } else {
                try writer.print("\\x{X:0>2}", .{ch});
            }
        },
    };
    try writer.writeByte('"');
}

fn writeIndent(writer: anytype, indent: usize) anyerror!void {
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        try writer.writeAll("  ");
    }
}

test "standalone default config export is self-contained" {
    const rendered = try renderStandaloneDefaultConfig(std.testing.allocator, .full);
    defer std.testing.allocator.free(rendered);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "load_relative(") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "return zide.config(") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "terminal =") != null);
}

test "standalone default config export can be loaded back by config parser" {
    const allocator = std.testing.allocator;
    const rendered = try renderStandaloneDefaultConfig(allocator, .full);
    defer allocator.free(rendered);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{ .sub_path = "init.lua", .data = rendered });

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp.dir.realpath("init.lua", &path_buf);
    var config = try lua_config.loadConfigFile(allocator, path);
    defer lua_config.freeConfig(allocator, &config);

    try std.testing.expect(config.terminal_texture_shift != null);
    try std.testing.expect(config.editor_wrap != null);
}

test "editor scoped export excludes terminal section" {
    const rendered = try renderStandaloneDefaultConfig(std.testing.allocator, .editor);
    defer std.testing.allocator.free(rendered);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "editor =") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "terminal =") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  terminal = {") == null);
}

test "terminal scoped export excludes editor section" {
    const rendered = try renderStandaloneDefaultConfig(std.testing.allocator, .terminal);
    defer std.testing.allocator.free(rendered);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "terminal =") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "editor =") == null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "  editor = {") == null);
}
