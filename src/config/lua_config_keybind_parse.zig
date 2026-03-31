const std = @import("std");
const zlua = @import("zlua");
const config_reader = @import("./lua_config_reader.zig");
const input_actions = @import("../input/input_actions.zig");
const input_types = @import("../types/input.zig");

fn parseKeyField(lua: *zlua.Lua, idx: i32) ?input_types.Key {
    const reader = config_reader.Reader.init(lua, std.heap.page_allocator, idx);
    const s = reader.fieldString("key") orelse return null;
    return std.meta.stringToEnum(input_types.Key, s);
}

const ModFlag = enum { ctrl, shift, alt, super, altgr };

fn readModString(slice: []const u8) ?ModFlag {
    if (std.mem.eql(u8, slice, "ctrl")) return .ctrl;
    if (std.mem.eql(u8, slice, "shift")) return .shift;
    if (std.mem.eql(u8, slice, "alt")) return .alt;
    if (std.mem.eql(u8, slice, "super")) return .super;
    if (std.mem.eql(u8, slice, "altgr")) return .altgr;
    return null;
}

fn applyMod(mods: *input_types.Modifiers, mod_flag: ModFlag) void {
    switch (mod_flag) {
        .ctrl => mods.ctrl = true,
        .shift => mods.shift = true,
        .alt => mods.alt = true,
        .super => mods.super = true,
        .altgr => mods.altgr = true,
    }
}

fn parseModsField(lua: *zlua.Lua, idx: i32) input_types.Modifiers {
    var mods: input_types.Modifiers = .{};
    const reader = config_reader.Reader.init(lua, std.heap.page_allocator, idx);
    if (reader.fieldString("mods")) |s| {
        if (readModString(s)) |mod_flag| applyMod(&mods, mod_flag);
        return mods;
    }

    _ = lua.getField(idx, "mods");
    defer lua.pop(1);
    if (!lua.isTable(-1)) return mods;

    const mods_idx = lua.absIndex(-1);
    const len = reader.rawLen(mods_idx);
    for (0..len) |i| {
        const s = reader.rawStringIndex(mods_idx, i + 1) orelse continue;
        if (readModString(s)) |mod_flag| applyMod(&mods, mod_flag);
    }
    return mods;
}

fn parseActionField(lua: *zlua.Lua, idx: i32) ?input_actions.ActionKind {
    const reader = config_reader.Reader.init(lua, std.heap.page_allocator, idx);
    const s = reader.fieldString("action") orelse return null;
    return std.meta.stringToEnum(input_actions.ActionKind, s);
}

fn parseRepeatField(lua: *zlua.Lua, idx: i32) bool {
    const reader = config_reader.Reader.init(lua, std.heap.page_allocator, idx);
    return reader.boolField("repeat") orelse false;
}

fn parseKeybindScope(
    allocator: std.mem.Allocator,
    lua: *zlua.Lua,
    idx: i32,
    field: [:0]const u8,
    scope: input_actions.BindScope,
    out: *std.ArrayList(input_actions.BindSpec),
) !void {
    const root_reader = config_reader.Reader.init(lua, allocator, idx);
    const scope_reader = root_reader.child(field) orelse return;
    defer scope_reader.finish();

    const len = scope_reader.arrayLen();
    for (0..len) |i| {
        const entry_reader = scope_reader.arrayItem(i + 1) orelse continue;
        defer entry_reader.finish();

        const entry_idx = entry_reader.index;
        const key = parseKeyField(lua, entry_idx) orelse continue;
        const action = parseActionField(lua, entry_idx) orelse continue;
        const mods = parseModsField(lua, entry_idx);
        const repeat = parseRepeatField(lua, entry_idx);
        try out.append(allocator, .{
            .scope = scope,
            .key = key,
            .mods = mods,
            .action = action,
            .repeat = repeat,
        });
    }
}

pub fn parseKeybindsNative(allocator: std.mem.Allocator, lua: *zlua.Lua, idx: i32) ![]input_actions.BindSpec {
    var out = std.ArrayList(input_actions.BindSpec).empty;
    errdefer out.deinit(allocator);

    try parseKeybindScope(allocator, lua, idx, "global", .global, &out);
    try parseKeybindScope(allocator, lua, idx, "editor", .editor, &out);
    try parseKeybindScope(allocator, lua, idx, "terminal", .terminal, &out);
    return out.toOwnedSlice(allocator);
}
