const std = @import("std");
const zlua = @import("zlua");
const input_actions = @import("../input/input_actions.zig");
const input_types = @import("../types/input.zig");

fn parseKeyField(lua: *zlua.Lua, idx: i32) ?input_types.Key {
    _ = lua.getField(idx, "key");
    defer lua.pop(1);
    if (!lua.isString(-1)) return null;
    if (lua.toString(-1)) |s| return std.meta.stringToEnum(input_types.Key, s) else |_| return null;
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
    _ = lua.getField(idx, "mods");
    defer lua.pop(1);

    if (lua.isString(-1)) {
        if (lua.toString(-1)) |s| {
            if (readModString(s)) |mod_flag| applyMod(&mods, mod_flag);
        } else |_| {}
        return mods;
    }
    if (!lua.isTable(-1)) return mods;

    const mods_idx = lua.absIndex(-1);
    const len = lua.rawLen(mods_idx);
    var i: i32 = 1;
    while (i <= @as(i32, @intCast(len))) : (i += 1) {
        _ = lua.rawGetIndex(mods_idx, i);
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |s| {
                if (readModString(s)) |mod_flag| applyMod(&mods, mod_flag);
            } else |_| {}
        }
        lua.pop(1);
    }
    return mods;
}

fn parseActionField(lua: *zlua.Lua, idx: i32) ?input_actions.ActionKind {
    _ = lua.getField(idx, "action");
    defer lua.pop(1);
    if (!lua.isString(-1)) return null;
    if (lua.toString(-1)) |s| return std.meta.stringToEnum(input_actions.ActionKind, s) else |_| return null;
}

fn parseRepeatField(lua: *zlua.Lua, idx: i32) bool {
    _ = lua.getField(idx, "repeat");
    defer lua.pop(1);
    if (!lua.isBoolean(-1)) return false;
    return lua.toBoolean(-1);
}

fn parseKeybindScope(
    allocator: std.mem.Allocator,
    lua: *zlua.Lua,
    idx: i32,
    field: [:0]const u8,
    scope: input_actions.BindScope,
    out: *std.ArrayList(input_actions.BindSpec),
) !void {
    _ = lua.getField(idx, field);
    defer lua.pop(1);
    if (!lua.isTable(-1)) return;

    const scope_idx = lua.absIndex(-1);
    const len = lua.rawLen(scope_idx);
    var i: i32 = 1;
    while (i <= @as(i32, @intCast(len))) : (i += 1) {
        _ = lua.rawGetIndex(scope_idx, i);
        defer lua.pop(1);
        if (!lua.isTable(-1)) continue;

        const entry_idx = lua.absIndex(-1);
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
