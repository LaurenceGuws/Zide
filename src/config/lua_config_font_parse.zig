const std = @import("std");
const zlua = @import("zlua");
const iface = @import("./lua_config_iface.zig");

const Config = iface.Config;
const LuaConfigError = iface.LuaConfigError;
const FontHinting = std.meta.Child(@TypeOf((@as(Config, undefined)).font_hinting));
const GlyphOverflow = std.meta.Child(@TypeOf((@as(Config, undefined)).font_glyph_overflow));
const LigatureStrategy = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_disable_ligatures));

fn replaceOwnedString(allocator: std.mem.Allocator, slot: *?[]u8, value: ?[]u8) void {
    if (slot.*) |old| allocator.free(old);
    slot.* = value;
}

pub fn parseFontHintingFromString(value: []const u8) ?FontHinting {
    if (std.mem.eql(u8, value, "default")) return .default;
    if (std.mem.eql(u8, value, "none")) return .none;
    if (std.mem.eql(u8, value, "light")) return .light;
    if (std.mem.eql(u8, value, "normal")) return .normal;
    return null;
}

pub fn parseGlyphOverflowFromString(value: []const u8) ?GlyphOverflow {
    if (std.mem.eql(u8, value, "when_followed_by_space")) return .when_followed_by_space;
    if (std.mem.eql(u8, value, "never")) return .never;
    if (std.mem.eql(u8, value, "always")) return .always;
    return null;
}

pub fn parseFontSetting(
    allocator: std.mem.Allocator,
    lua: *zlua.Lua,
    idx: i32,
    path_out: *?[]u8,
    size_out: *?f32,
) !void {
    if (lua.isString(idx)) {
        if (lua.toString(idx)) |v| {
            replaceOwnedString(allocator, path_out, try allocator.dupe(u8, v));
        } else |_| {}
        return;
    }
    if (!lua.isTable(idx)) return;

    const table_idx = lua.absIndex(idx);
    _ = lua.getField(table_idx, "path");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| replaceOwnedString(allocator, path_out, try allocator.dupe(u8, v)) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_idx, "size");
    if (lua.isNumber(-1)) {
        if (lua.toNumber(-1)) |v| {
            if (v > 0) size_out.* = @floatCast(v);
        } else |_| {}
    }
    lua.pop(1);
}

pub fn parseRootFontSettings(
    allocator: std.mem.Allocator,
    lua: *zlua.Lua,
    table_index: i32,
    out: *Config,
) !void {
    _ = lua.getField(table_index, "font_lcd");
    if (lua.isBoolean(-1)) out.font_lcd = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(table_index, "font_autohint");
    if (lua.isBoolean(-1)) out.font_autohint = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(table_index, "text_linear_correction");
    if (lua.isBoolean(-1)) out.text_linear_correction = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(table_index, "text_gamma");
    if (lua.isNumber(-1)) {
        if (lua.toNumber(-1)) |v| out.text_gamma = @floatCast(v) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "text_contrast");
    if (lua.isNumber(-1)) {
        if (lua.toNumber(-1)) |v| out.text_contrast = @floatCast(v) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "app_font_size");
    if (lua.isNumber(-1)) {
        if (lua.toNumber(-1)) |v| out.app_font_size = @floatCast(v) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "editor_font_size");
    if (lua.isNumber(-1)) {
        if (lua.toNumber(-1)) |v| out.editor_font_size = @floatCast(v) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_font_size");
    if (lua.isNumber(-1)) {
        if (lua.toNumber(-1)) |v| out.terminal_font_size = @floatCast(v) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "app_font_path");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| out.app_font_path = try allocator.dupe(u8, v) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "editor_font_path");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| out.editor_font_path = try allocator.dupe(u8, v) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_font_path");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| out.terminal_font_path = try allocator.dupe(u8, v) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "editor_font_features");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| out.editor_font_features = try allocator.dupe(u8, v) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_font_features");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| out.terminal_font_features = try allocator.dupe(u8, v) else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "font_hinting");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseFontHintingFromString(v)) |hint| out.font_hinting = hint;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "font_glyph_overflow");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseGlyphOverflowFromString(v)) |mode| out.font_glyph_overflow = mode;
        } else |_| {}
    }
    lua.pop(1);
}

pub fn parseAppFontTable(
    allocator: std.mem.Allocator,
    lua: *zlua.Lua,
    app_idx: i32,
    out: *Config,
) !void {
    _ = lua.getField(app_idx, "font");
    try parseFontSetting(allocator, lua, -1, &out.app_font_path, &out.app_font_size);
    lua.pop(1);
}

pub fn parseEditorFontTable(
    allocator: std.mem.Allocator,
    lua: *zlua.Lua,
    editor_idx: i32,
    out: *Config,
    parse_filter_value_owned: fn (std.mem.Allocator, *zlua.Lua, i32) LuaConfigError!?[]u8,
    replace_owned_string: fn (std.mem.Allocator, *?[]u8, ?[]u8) void,
    parse_ligature_strategy_from_string: fn ([]const u8) ?LigatureStrategy,
) !void {
    _ = lua.getField(editor_idx, "font");
    try parseFontSetting(allocator, lua, -1, &out.editor_font_path, &out.editor_font_size);
    lua.pop(1);

    _ = lua.getField(editor_idx, "font_features");
    if (try parse_filter_value_owned(allocator, lua, -1)) |v| replace_owned_string(allocator, &out.editor_font_features, v);
    lua.pop(1);

    _ = lua.getField(editor_idx, "disable_ligatures");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parse_ligature_strategy_from_string(v)) |strategy| out.editor_disable_ligatures = strategy;
        } else |_| {}
    }
    lua.pop(1);
}

pub fn parseTerminalFontTable(
    allocator: std.mem.Allocator,
    lua: *zlua.Lua,
    terminal_idx: i32,
    out: *Config,
    parse_filter_value_owned: fn (std.mem.Allocator, *zlua.Lua, i32) LuaConfigError!?[]u8,
    replace_owned_string: fn (std.mem.Allocator, *?[]u8, ?[]u8) void,
    parse_ligature_strategy_from_string: fn ([]const u8) ?LigatureStrategy,
) !void {
    _ = lua.getField(terminal_idx, "font");
    try parseFontSetting(allocator, lua, -1, &out.terminal_font_path, &out.terminal_font_size);
    lua.pop(1);

    _ = lua.getField(terminal_idx, "font_features");
    if (try parse_filter_value_owned(allocator, lua, -1)) |v| replace_owned_string(allocator, &out.terminal_font_features, v);
    lua.pop(1);

    _ = lua.getField(terminal_idx, "disable_ligatures");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parse_ligature_strategy_from_string(v)) |strategy| out.terminal_disable_ligatures = strategy;
        } else |_| {}
    }
    lua.pop(1);
}

pub fn parseFontRenderingTable(lua: *zlua.Lua, idx: i32, out: *Config) void {
    if (!lua.isTable(idx)) return;

    const fr_idx = lua.absIndex(idx);
    _ = lua.getField(fr_idx, "lcd");
    if (lua.isBoolean(-1)) out.font_lcd = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(fr_idx, "autohint");
    if (lua.isBoolean(-1)) out.font_autohint = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(fr_idx, "hinting");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseFontHintingFromString(v)) |hint| out.font_hinting = hint;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(fr_idx, "glyph_overflow");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseGlyphOverflowFromString(v)) |go| out.font_glyph_overflow = go;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(fr_idx, "text");
    if (lua.isTable(-1)) {
        const text_idx = lua.absIndex(-1);
        _ = lua.getField(text_idx, "gamma");
        if (lua.isNumber(-1)) {
            if (lua.toNumber(-1)) |v| {
                if (v > 0) out.text_gamma = @floatCast(v);
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(text_idx, "contrast");
        if (lua.isNumber(-1)) {
            if (lua.toNumber(-1)) |v| {
                if (v > 0) out.text_contrast = @floatCast(v);
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(text_idx, "linear_correction");
        if (lua.isBoolean(-1)) out.text_linear_correction = lua.toBoolean(-1);
        lua.pop(1);
    }
    lua.pop(1);
}
