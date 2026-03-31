const std = @import("std");
const zlua = @import("zlua");
const config_reader = @import("./lua_config_reader.zig");
const iface = @import("./lua_config_iface.zig");

const Config = iface.Config;
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
    const reader = config_reader.Reader.init(lua, allocator, idx);
    if (lua.isString(idx)) {
        if (reader.state.readString(idx)) |v| replaceOwnedString(allocator, path_out, try allocator.dupe(u8, v));
        return;
    }
    if (!reader.state.isTable(idx)) return;

    if (try reader.ownedStringField("path")) |v| replaceOwnedString(allocator, path_out, v);
    if (reader.positiveF32Field("size")) |v| size_out.* = v;
}

pub fn parseRootFontSettings(
    allocator: std.mem.Allocator,
    lua: *zlua.Lua,
    table_index: i32,
    out: *Config,
) !void {
    const reader = config_reader.Reader.init(lua, allocator, table_index);

    if (reader.boolField("font_lcd")) |v| out.font_lcd = v;
    if (reader.boolField("font_autohint")) |v| out.font_autohint = v;
    if (reader.boolField("text_linear_correction")) |v| out.text_linear_correction = v;
    if (reader.positiveF32Field("text_gamma")) |v| out.text_gamma = v;
    if (reader.positiveF32Field("text_contrast")) |v| out.text_contrast = v;
    if (reader.positiveF32Field("app_font_size")) |v| out.app_font_size = v;
    if (reader.positiveF32Field("editor_font_size")) |v| out.editor_font_size = v;
    if (reader.positiveF32Field("terminal_font_size")) |v| out.terminal_font_size = v;
    if (try reader.ownedStringField("app_font_path")) |v| out.app_font_path = v;
    if (try reader.ownedStringField("editor_font_path")) |v| out.editor_font_path = v;
    if (try reader.ownedStringField("terminal_font_path")) |v| out.terminal_font_path = v;
    if (try reader.ownedStringField("editor_font_features")) |v| out.editor_font_features = v;
    if (try reader.ownedStringField("terminal_font_features")) |v| out.terminal_font_features = v;
    if (reader.fieldString("font_hinting")) |v| {
        if (parseFontHintingFromString(v)) |hint| out.font_hinting = hint;
    }
    if (reader.fieldString("font_glyph_overflow")) |v| {
        if (parseGlyphOverflowFromString(v)) |mode| out.font_glyph_overflow = mode;
    }
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
    replace_owned_string: fn (std.mem.Allocator, *?[]u8, ?[]u8) void,
    parse_ligature_strategy_from_string: fn ([]const u8) ?LigatureStrategy,
) !void {
    const reader = config_reader.Reader.init(lua, allocator, editor_idx);
    _ = lua.getField(editor_idx, "font");
    try parseFontSetting(allocator, lua, -1, &out.editor_font_path, &out.editor_font_size);
    lua.pop(1);

    if (try reader.stringOrStringListOwned("font_features")) |v| {
        replace_owned_string(allocator, &out.editor_font_features, v);
    }

    if (reader.fieldString("disable_ligatures")) |v| {
        if (parse_ligature_strategy_from_string(v)) |strategy| out.editor_disable_ligatures = strategy;
    }
}

pub fn parseTerminalFontTable(
    allocator: std.mem.Allocator,
    lua: *zlua.Lua,
    terminal_idx: i32,
    out: *Config,
    replace_owned_string: fn (std.mem.Allocator, *?[]u8, ?[]u8) void,
    parse_ligature_strategy_from_string: fn ([]const u8) ?LigatureStrategy,
) !void {
    const reader = config_reader.Reader.init(lua, allocator, terminal_idx);
    _ = lua.getField(terminal_idx, "font");
    try parseFontSetting(allocator, lua, -1, &out.terminal_font_path, &out.terminal_font_size);
    lua.pop(1);

    if (try reader.stringOrStringListOwned("font_features")) |v| {
        replace_owned_string(allocator, &out.terminal_font_features, v);
    }

    if (reader.fieldString("disable_ligatures")) |v| {
        if (parse_ligature_strategy_from_string(v)) |strategy| out.terminal_disable_ligatures = strategy;
    }
}

pub fn parseFontRenderingTable(lua: *zlua.Lua, idx: i32, out: *Config) void {
    const reader = config_reader.Reader.init(lua, std.heap.page_allocator, idx);
    if (!reader.state.isTable(idx)) return;

    if (reader.boolField("lcd")) |v| out.font_lcd = v;
    if (reader.boolField("autohint")) |v| out.font_autohint = v;
    if (reader.fieldString("hinting")) |v| {
        if (parseFontHintingFromString(v)) |hint| out.font_hinting = hint;
    }
    if (reader.fieldString("glyph_overflow")) |v| {
        if (parseGlyphOverflowFromString(v)) |go| out.font_glyph_overflow = go;
    }

    if (reader.child("text")) |text_reader| {
        defer text_reader.finish();
        if (text_reader.numberField("gamma")) |v| {
            if (v > 0) out.text_gamma = @floatCast(v);
        }
        if (text_reader.numberField("contrast")) |v| {
            if (v > 0) out.text_contrast = @floatCast(v);
        }
        if (text_reader.boolField("linear_correction")) |v| out.text_linear_correction = v;
    }
}
