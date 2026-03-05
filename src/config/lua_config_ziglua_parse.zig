const std = @import("std");
const zlua = @import("zlua");
const capi_bridge = @import("./lua_config_capi_bridge.zig");
const lua_shared = @import("./lua_config_shared.zig");
const input_actions = @import("../input/input_actions.zig");
const input_types = @import("../types/input.zig");

pub const LuaConfigError = capi_bridge.LuaConfigError;
pub const Config = capi_bridge.Config;
const ThemeConfig = capi_bridge.ThemeConfig;
const Color = std.meta.Child(@TypeOf((@as(ThemeConfig, undefined)).background));
const SdlLogLevel = std.meta.Child(@TypeOf((@as(Config, undefined)).sdl_log_level));
const TabBarWidthMode = std.meta.Child(@TypeOf((@as(Config, undefined)).editor_tab_bar_width_mode));
const CursorShape = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_cursor_shape));
const FontHinting = std.meta.Child(@TypeOf((@as(Config, undefined)).font_hinting));
const GlyphOverflow = std.meta.Child(@TypeOf((@as(Config, undefined)).font_glyph_overflow));
const TerminalBlinkStyle = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_blink_style));
const LigatureStrategy = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_disable_ligatures));
const terminal_scrollback_default: usize = 1000;
const terminal_scrollback_min: usize = 100;
const terminal_scrollback_max: usize = 100000;

fn replaceOwnedString(allocator: std.mem.Allocator, slot: *?[]u8, value: ?[]u8) void {
    if (slot.*) |old| allocator.free(old);
    slot.* = value;
}

fn parseFilterValueOwned(allocator: std.mem.Allocator, lua: *zlua.Lua, idx: i32) !?[]u8 {
    if (lua.isString(idx)) {
        if (lua.toString(idx)) |v| return try allocator.dupe(u8, v) else |_| return null;
    }
    if (!lua.isTable(idx)) return null;

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    const table_index = lua.absIndex(idx);
    lua.pushNil();
    while (lua.next(table_index)) {
        defer lua.pop(1);
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |s| {
                if (out.items.len > 0) try out.append(allocator, ',');
                try out.appendSlice(allocator, s);
            } else |_| {}
        }
    }
    return try out.toOwnedSlice(allocator);
}

fn parseFontSetting(
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

fn parseTabBarWidthModeFromString(value: []const u8) ?TabBarWidthMode {
    if (std.mem.eql(u8, value, "fixed")) return .fixed;
    if (std.mem.eql(u8, value, "dynamic")) return .dynamic;
    if (std.mem.eql(u8, value, "label_length")) return .label_length;
    return null;
}

fn parseCursorShapeFromString(value: []const u8) ?CursorShape {
    if (std.mem.eql(u8, value, "block")) return .block;
    if (std.mem.eql(u8, value, "bar")) return .bar;
    if (std.mem.eql(u8, value, "underline")) return .underline;
    return null;
}

fn parseFontHintingFromString(value: []const u8) ?FontHinting {
    if (std.mem.eql(u8, value, "default")) return .default;
    if (std.mem.eql(u8, value, "none")) return .none;
    if (std.mem.eql(u8, value, "light")) return .light;
    if (std.mem.eql(u8, value, "normal")) return .normal;
    return null;
}

fn parseGlyphOverflowFromString(value: []const u8) ?GlyphOverflow {
    if (std.mem.eql(u8, value, "when_followed_by_space")) return .when_followed_by_space;
    if (std.mem.eql(u8, value, "never")) return .never;
    if (std.mem.eql(u8, value, "always")) return .always;
    return null;
}

fn parseBlinkStyleFromString(value: []const u8) ?TerminalBlinkStyle {
    if (std.mem.eql(u8, value, "kitty")) return .kitty;
    if (std.mem.eql(u8, value, "off")) return .off;
    if (std.mem.eql(u8, value, "ghostty")) return .off;
    return null;
}

fn parseLigatureStrategyFromString(value: []const u8) ?LigatureStrategy {
    if (std.mem.eql(u8, value, "never")) return .never;
    if (std.mem.eql(u8, value, "cursor")) return .cursor;
    if (std.mem.eql(u8, value, "always")) return .always;
    return null;
}

fn normalizeScrollback(value: i64) usize {
    if (value < @as(i64, @intCast(terminal_scrollback_min)) or value > @as(i64, @intCast(terminal_scrollback_max))) {
        return terminal_scrollback_default;
    }
    return @intCast(value);
}

fn parseHexByte(slice: []const u8) ?u8 {
    return std.fmt.parseInt(u8, slice, 16) catch null;
}

fn parseHexColor(value: []const u8) ?Color {
    var slice = value;
    if (slice.len >= 2 and slice[0] == '0' and (slice[1] == 'x' or slice[1] == 'X')) {
        slice = slice[2..];
    }
    if (slice.len > 0 and slice[0] == '#') {
        slice = slice[1..];
    }
    if (slice.len != 6 and slice.len != 8) return null;

    const r = parseHexByte(slice[0..2]) orelse return null;
    const g = parseHexByte(slice[2..4]) orelse return null;
    const b = parseHexByte(slice[4..6]) orelse return null;
    const a = if (slice.len == 8) parseHexByte(slice[6..8]) orelse return null else 255;
    return Color{ .r = r, .g = g, .b = b, .a = a };
}

fn parseColorChannel(lua: *zlua.Lua, idx: i32) ?u8 {
    if (!lua.isNumber(idx)) return null;
    if (lua.toInteger(idx)) |value| {
        if (value < 0 or value > 255) return null;
        return @intCast(value);
    } else |_| return null;
}

fn parseColorFromValue(lua: *zlua.Lua, idx: i32) ?Color {
    if (lua.isString(idx)) {
        if (lua.toString(idx)) |value| return parseHexColor(value) else |_| return null;
    }
    if (lua.isTable(idx)) {
        const table_idx = lua.absIndex(idx);
        var r: ?u8 = null;
        var g: ?u8 = null;
        var b: ?u8 = null;
        var a: ?u8 = null;

        _ = lua.getField(table_idx, "r");
        r = parseColorChannel(lua, -1);
        lua.pop(1);

        _ = lua.getField(table_idx, "g");
        g = parseColorChannel(lua, -1);
        lua.pop(1);

        _ = lua.getField(table_idx, "b");
        b = parseColorChannel(lua, -1);
        lua.pop(1);

        _ = lua.getField(table_idx, "a");
        a = parseColorChannel(lua, -1);
        lua.pop(1);

        if (r != null and g != null and b != null) {
            return Color{ .r = r.?, .g = g.?, .b = b.?, .a = a orelse 255 };
        }
    }
    return null;
}

fn parseColorField(lua: *zlua.Lua, idx: i32, field: [:0]const u8, out: *?Color) void {
    _ = lua.getField(idx, field);
    if (parseColorFromValue(lua, -1)) |color| out.* = color;
    lua.pop(1);
}

fn parseIndexedAnsiColors(lua: *zlua.Lua, idx: i32, ansi_colors: *[16]?Color) void {
    for (0..16) |i| {
        _ = lua.rawGetIndex(idx, @intCast(i + 1));
        if (parseColorFromValue(lua, -1)) |color| ansi_colors[i] = color;
        lua.pop(1);
    }
}

fn parseNamedAnsiColors(lua: *zlua.Lua, idx: i32, ansi_colors: *[16]?Color) void {
    parseColorField(lua, idx, "black", &ansi_colors[0]);
    parseColorField(lua, idx, "red", &ansi_colors[1]);
    parseColorField(lua, idx, "green", &ansi_colors[2]);
    parseColorField(lua, idx, "yellow", &ansi_colors[3]);
    parseColorField(lua, idx, "blue", &ansi_colors[4]);
    parseColorField(lua, idx, "magenta", &ansi_colors[5]);
    parseColorField(lua, idx, "cyan", &ansi_colors[6]);
    parseColorField(lua, idx, "white", &ansi_colors[7]);
    parseColorField(lua, idx, "bright_black", &ansi_colors[8]);
    parseColorField(lua, idx, "bright_red", &ansi_colors[9]);
    parseColorField(lua, idx, "bright_green", &ansi_colors[10]);
    parseColorField(lua, idx, "bright_yellow", &ansi_colors[11]);
    parseColorField(lua, idx, "bright_blue", &ansi_colors[12]);
    parseColorField(lua, idx, "bright_magenta", &ansi_colors[13]);
    parseColorField(lua, idx, "bright_cyan", &ansi_colors[14]);
    parseColorField(lua, idx, "bright_white", &ansi_colors[15]);
}

fn parseThemePaletteTableNative(lua: *zlua.Lua, idx: i32, theme: *ThemeConfig) void {
    parseColorField(lua, idx, "background", &theme.background);
    parseColorField(lua, idx, "foreground", &theme.foreground);
    parseColorField(lua, idx, "selection", &theme.selection);
    parseColorField(lua, idx, "selection_background", &theme.selection);
    parseColorField(lua, idx, "selection-background", &theme.selection);
    parseColorField(lua, idx, "cursor", &theme.cursor);
    parseColorField(lua, idx, "link", &theme.link);
    parseColorField(lua, idx, "line_number", &theme.line_number);
    parseColorField(lua, idx, "line_number_bg", &theme.line_number_bg);
    parseColorField(lua, idx, "current_line", &theme.current_line);
    parseColorField(lua, idx, "ui_bar_bg", &theme.ui_bar_bg);
    parseColorField(lua, idx, "ui_panel_bg", &theme.ui_panel_bg);
    parseColorField(lua, idx, "ui_panel_overlay", &theme.ui_panel_overlay);
    parseColorField(lua, idx, "ui_hover", &theme.ui_hover);
    parseColorField(lua, idx, "ui_pressed", &theme.ui_pressed);
    parseColorField(lua, idx, "ui_tab_inactive_bg", &theme.ui_tab_inactive_bg);
    parseColorField(lua, idx, "ui_accent", &theme.ui_accent);
    parseColorField(lua, idx, "ui_border", &theme.ui_border);
    parseColorField(lua, idx, "ui_modified", &theme.ui_modified);
    parseColorField(lua, idx, "ui_text", &theme.ui_text);
    parseColorField(lua, idx, "ui_text_inactive", &theme.ui_text_inactive);

    parseColorField(lua, idx, "color0", &theme.ansi_colors[0]);
    parseColorField(lua, idx, "color1", &theme.ansi_colors[1]);
    parseColorField(lua, idx, "color2", &theme.ansi_colors[2]);
    parseColorField(lua, idx, "color3", &theme.ansi_colors[3]);
    parseColorField(lua, idx, "color4", &theme.ansi_colors[4]);
    parseColorField(lua, idx, "color5", &theme.ansi_colors[5]);
    parseColorField(lua, idx, "color6", &theme.ansi_colors[6]);
    parseColorField(lua, idx, "color7", &theme.ansi_colors[7]);
    parseColorField(lua, idx, "color8", &theme.ansi_colors[8]);
    parseColorField(lua, idx, "color9", &theme.ansi_colors[9]);
    parseColorField(lua, idx, "color10", &theme.ansi_colors[10]);
    parseColorField(lua, idx, "color11", &theme.ansi_colors[11]);
    parseColorField(lua, idx, "color12", &theme.ansi_colors[12]);
    parseColorField(lua, idx, "color13", &theme.ansi_colors[13]);
    parseColorField(lua, idx, "color14", &theme.ansi_colors[14]);
    parseColorField(lua, idx, "color15", &theme.ansi_colors[15]);

    parseNamedAnsiColors(lua, idx, &theme.ansi_colors);

    _ = lua.getField(idx, "ansi");
    if (lua.isTable(-1)) {
        const ansi_idx = lua.absIndex(-1);
        parseIndexedAnsiColors(lua, ansi_idx, &theme.ansi_colors);
        parseNamedAnsiColors(lua, ansi_idx, &theme.ansi_colors);
    }
    lua.pop(1);
}

fn parseThemeSyntaxTableNative(lua: *zlua.Lua, idx: i32, theme: *ThemeConfig) void {
    parseColorField(lua, idx, "comment", &theme.comment_color);
    parseColorField(lua, idx, "comment_color", &theme.comment_color);
    parseColorField(lua, idx, "string", &theme.string);
    parseColorField(lua, idx, "keyword", &theme.keyword);
    parseColorField(lua, idx, "number", &theme.number);
    parseColorField(lua, idx, "function", &theme.function);
    parseColorField(lua, idx, "variable", &theme.variable);
    parseColorField(lua, idx, "type_name", &theme.type_name);
    parseColorField(lua, idx, "operator", &theme.operator);
    parseColorField(lua, idx, "builtin", &theme.builtin_color);
    parseColorField(lua, idx, "builtin_color", &theme.builtin_color);
    parseColorField(lua, idx, "punctuation", &theme.punctuation);
    parseColorField(lua, idx, "constant", &theme.constant);
    parseColorField(lua, idx, "attribute", &theme.attribute);
    parseColorField(lua, idx, "namespace", &theme.namespace);
    parseColorField(lua, idx, "label", &theme.label);
    parseColorField(lua, idx, "error", &theme.error_token);
    parseColorField(lua, idx, "error_token", &theme.error_token);
    parseColorField(lua, idx, "preproc", &theme.preproc);
    parseColorField(lua, idx, "macro", &theme.macro);
    parseColorField(lua, idx, "escape", &theme.escape);
    parseColorField(lua, idx, "keyword_control", &theme.keyword_control);
    parseColorField(lua, idx, "function_method", &theme.function_method);
    parseColorField(lua, idx, "type_builtin", &theme.type_builtin);
    parseColorField(lua, idx, "keyword.control", &theme.keyword_control);
    parseColorField(lua, idx, "function.method", &theme.function_method);
    parseColorField(lua, idx, "type.builtin", &theme.type_builtin);
}

fn parseThemeFromTableNative(lua: *zlua.Lua, idx: i32) ThemeConfig {
    var theme: ThemeConfig = .{};
    const table_idx = lua.absIndex(idx);

    parseThemePaletteTableNative(lua, table_idx, &theme);
    parseThemeSyntaxTableNative(lua, table_idx, &theme);

    _ = lua.getField(table_idx, "palette");
    if (lua.isTable(-1)) parseThemePaletteTableNative(lua, lua.absIndex(-1), &theme);
    lua.pop(1);

    _ = lua.getField(table_idx, "syntax");
    if (lua.isTable(-1)) parseThemeSyntaxTableNative(lua, lua.absIndex(-1), &theme);
    lua.pop(1);

    return theme;
}

fn parseThemeAtStackIndex(lua: *zlua.Lua, idx: i32) LuaConfigError!?ThemeConfig {
    if (!lua.isTable(idx)) return null;
    return parseThemeFromTableNative(lua, idx);
}

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

fn parseKeybindsNative(allocator: std.mem.Allocator, lua: *zlua.Lua, idx: i32) ![]input_actions.BindSpec {
    var out = std.ArrayList(input_actions.BindSpec).empty;
    errdefer out.deinit(allocator);

    try parseKeybindScope(allocator, lua, idx, "global", .global, &out);
    try parseKeybindScope(allocator, lua, idx, "editor", .editor, &out);
    try parseKeybindScope(allocator, lua, idx, "terminal", .terminal, &out);
    return out.toOwnedSlice(allocator);
}

fn parseNativeScalarOverlay(allocator: std.mem.Allocator, lua: *zlua.Lua, table_index: i32) !Config {
    var out = lua_shared.emptyConfig();

    _ = lua.getField(table_index, "theme");
    if (try parseThemeAtStackIndex(lua, -1)) |parsed| out.theme = parsed;
    lua.pop(1);

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
                if (out.log_file_filter) |file_v| {
                    out.log_console_filter = try allocator.dupe(u8, file_v);
                }
            }
        }
        lua.pop(1);
    }
    lua.pop(1);

    _ = lua.getField(table_index, "editor_wrap");
    if (lua.isBoolean(-1)) out.editor_wrap = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_focus_report_window");
    if (lua.isBoolean(-1)) out.terminal_focus_report_window = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_focus_report_pane");
    if (lua.isBoolean(-1)) out.terminal_focus_report_pane = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(table_index, "editor_large_jump_rows");
    if (lua.isNumber(-1)) {
        if (lua.toInteger(-1)) |v| {
            if (v > 0) out.editor_large_jump_rows = @intCast(v);
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "editor_highlight_budget");
    if (lua.isNumber(-1)) {
        if (lua.toInteger(-1)) |v| {
            if (v > 0) out.editor_highlight_budget = @intCast(v);
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "editor_width_budget");
    if (lua.isNumber(-1)) {
        if (lua.toInteger(-1)) |v| {
            if (v > 0) out.editor_width_budget = @intCast(v);
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_scrollback_rows");
    if (lua.isNumber(-1)) {
        if (lua.toInteger(-1)) |v| {
            out.terminal_scrollback_rows = normalizeScrollback(v);
        } else |_| {}
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

    _ = lua.getField(table_index, "terminal_cursor_blink");
    if (lua.isBoolean(-1)) out.terminal_cursor_blink = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_tab_bar_show_single_tab");
    if (lua.isBoolean(-1)) out.terminal_tab_bar_show_single_tab = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(table_index, "keybinds_no_defaults");
    if (lua.isBoolean(-1)) out.keybinds_no_defaults = lua.toBoolean(-1);
    lua.pop(1);

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

    _ = lua.getField(table_index, "editor_tab_bar_width_mode");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseTabBarWidthModeFromString(v)) |mode| out.editor_tab_bar_width_mode = mode;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_tab_bar_width_mode");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseTabBarWidthModeFromString(v)) |mode| out.terminal_tab_bar_width_mode = mode;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_cursor_shape");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseCursorShapeFromString(v)) |shape| out.terminal_cursor_shape = shape;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_blink_style");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseBlinkStyleFromString(v)) |style| out.terminal_blink_style = style;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_disable_ligatures");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseLigatureStrategyFromString(v)) |strategy| out.terminal_disable_ligatures = strategy;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "editor_disable_ligatures");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseLigatureStrategyFromString(v)) |strategy| out.editor_disable_ligatures = strategy;
        } else |_| {}
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

    _ = lua.getField(table_index, "app");
    if (lua.isTable(-1)) {
        const app_idx = lua.absIndex(-1);
        _ = lua.getField(app_idx, "theme");
        if (try parseThemeAtStackIndex(lua, -1)) |parsed| out.app_theme = parsed;
        lua.pop(1);
        _ = lua.getField(app_idx, "font");
        try parseFontSetting(allocator, lua, -1, &out.app_font_path, &out.app_font_size);
        lua.pop(1);
    }
    lua.pop(1);

    _ = lua.getField(table_index, "editor");
    if (lua.isTable(-1)) {
        const editor_idx = lua.absIndex(-1);

        _ = lua.getField(editor_idx, "wrap");
        if (lua.isBoolean(-1)) out.editor_wrap = lua.toBoolean(-1);
        lua.pop(1);

        _ = lua.getField(editor_idx, "large_cursor_jump_rows");
        if (lua.isNumber(-1)) {
            if (lua.toInteger(-1)) |v| {
                if (v > 0) out.editor_large_jump_rows = @intCast(v);
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(editor_idx, "font");
        try parseFontSetting(allocator, lua, -1, &out.editor_font_path, &out.editor_font_size);
        lua.pop(1);

        _ = lua.getField(editor_idx, "theme");
        if (lua.isTable(-1)) {
            out.editor_theme = try capi_bridge.parseEditorThemeFromLuaState(lua, lua.absIndex(-1));
        }
        lua.pop(1);

        _ = lua.getField(editor_idx, "font_features");
        if (try parseFilterValueOwned(allocator, lua, -1)) |v| replaceOwnedString(allocator, &out.editor_font_features, v);
        lua.pop(1);

        _ = lua.getField(editor_idx, "disable_ligatures");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseLigatureStrategyFromString(v)) |strategy| {
                    out.editor_disable_ligatures = strategy;
                }
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(editor_idx, "render");
        if (lua.isTable(-1)) {
            const render_idx = lua.absIndex(-1);
            _ = lua.getField(render_idx, "highlight_budget");
            if (lua.isNumber(-1)) {
                if (lua.toInteger(-1)) |v| {
                    if (v >= 0) out.editor_highlight_budget = @intCast(v);
                } else |_| {}
            }
            lua.pop(1);
            _ = lua.getField(render_idx, "width_budget");
            if (lua.isNumber(-1)) {
                if (lua.toInteger(-1)) |v| {
                    if (v >= 0) out.editor_width_budget = @intCast(v);
                } else |_| {}
            }
            lua.pop(1);
        }
        lua.pop(1);

        _ = lua.getField(editor_idx, "tab_bar");
        if (lua.isTable(-1)) {
            const tab_idx = lua.absIndex(-1);
            _ = lua.getField(tab_idx, "width_mode");
            if (lua.isString(-1)) {
                if (lua.toString(-1)) |v| {
                    if (parseTabBarWidthModeFromString(v)) |mode| {
                        out.editor_tab_bar_width_mode = mode;
                    }
                } else |_| {}
            }
            lua.pop(1);
        }
        lua.pop(1);
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal");
    if (lua.isTable(-1)) {
        const terminal_idx = lua.absIndex(-1);

        _ = lua.getField(terminal_idx, "font");
        try parseFontSetting(allocator, lua, -1, &out.terminal_font_path, &out.terminal_font_size);
        lua.pop(1);

        _ = lua.getField(terminal_idx, "theme");
        if (try parseThemeAtStackIndex(lua, -1)) |parsed| out.terminal_theme = parsed;
        lua.pop(1);

        _ = lua.getField(terminal_idx, "font_features");
        if (try parseFilterValueOwned(allocator, lua, -1)) |v| replaceOwnedString(allocator, &out.terminal_font_features, v);
        lua.pop(1);

        _ = lua.getField(terminal_idx, "blink");
        if (lua.isBoolean(-1)) {
            out.terminal_blink_style = if (lua.toBoolean(-1)) .kitty else .off;
        } else if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseBlinkStyleFromString(v)) |style| {
                    out.terminal_blink_style = style;
                }
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(terminal_idx, "disable_ligatures");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseLigatureStrategyFromString(v)) |strategy| {
                    out.terminal_disable_ligatures = strategy;
                }
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(terminal_idx, "scrollback");
        if (lua.isNumber(-1)) {
            if (lua.toInteger(-1)) |v| out.terminal_scrollback_rows = normalizeScrollback(v) else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(terminal_idx, "cursor");
        if (lua.isTable(-1)) {
            const cursor_idx = lua.absIndex(-1);
            _ = lua.getField(cursor_idx, "shape");
            if (lua.isString(-1)) {
                if (lua.toString(-1)) |v| {
                    if (parseCursorShapeFromString(v)) |shape| {
                        out.terminal_cursor_shape = shape;
                    }
                } else |_| {}
            }
            lua.pop(1);
            _ = lua.getField(cursor_idx, "blink");
            if (lua.isBoolean(-1)) out.terminal_cursor_blink = lua.toBoolean(-1);
            lua.pop(1);
        }
        lua.pop(1);

        _ = lua.getField(terminal_idx, "tab_bar");
        if (lua.isTable(-1)) {
            const tab_idx = lua.absIndex(-1);
            _ = lua.getField(tab_idx, "show_single_tab");
            if (lua.isBoolean(-1)) out.terminal_tab_bar_show_single_tab = lua.toBoolean(-1);
            lua.pop(1);
            _ = lua.getField(tab_idx, "width_mode");
            if (lua.isString(-1)) {
                if (lua.toString(-1)) |v| {
                    if (parseTabBarWidthModeFromString(v)) |mode| {
                        out.terminal_tab_bar_width_mode = mode;
                    }
                } else |_| {}
            }
            lua.pop(1);
        }
        lua.pop(1);

        _ = lua.getField(terminal_idx, "focus_reporting");
        if (lua.isBoolean(-1)) {
            const enabled = lua.toBoolean(-1);
            out.terminal_focus_report_window = enabled;
            out.terminal_focus_report_pane = enabled;
        } else if (lua.isTable(-1)) {
            const focus_idx = lua.absIndex(-1);
            _ = lua.getField(focus_idx, "window");
            if (lua.isBoolean(-1)) out.terminal_focus_report_window = lua.toBoolean(-1);
            lua.pop(1);
            _ = lua.getField(focus_idx, "pane");
            if (lua.isBoolean(-1)) out.terminal_focus_report_pane = lua.toBoolean(-1);
            lua.pop(1);
        }
        lua.pop(1);
    }
    lua.pop(1);

    _ = lua.getField(table_index, "font_rendering");
    if (lua.isTable(-1)) {
        const fr_idx = lua.absIndex(-1);
        _ = lua.getField(fr_idx, "lcd");
        if (lua.isBoolean(-1)) out.font_lcd = lua.toBoolean(-1);
        lua.pop(1);
        _ = lua.getField(fr_idx, "autohint");
        if (lua.isBoolean(-1)) out.font_autohint = lua.toBoolean(-1);
        lua.pop(1);
        _ = lua.getField(fr_idx, "hinting");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseFontHintingFromString(v)) |hint| {
                    out.font_hinting = hint;
                }
            } else |_| {}
        }
        lua.pop(1);
        _ = lua.getField(fr_idx, "glyph_overflow");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseGlyphOverflowFromString(v)) |go| {
                    out.font_glyph_overflow = go;
                }
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
    lua.pop(1);

    _ = lua.getField(table_index, "keybinds");
    if (lua.isTable(-1)) {
        const keybinds_idx = lua.absIndex(-1);
        _ = lua.getField(keybinds_idx, "no_defaults");
        if (lua.isBoolean(-1)) out.keybinds_no_defaults = lua.toBoolean(-1);
        lua.pop(1);
        out.keybinds = try parseKeybindsNative(allocator, lua, keybinds_idx);
    }
    lua.pop(1);

    return out;
}

pub fn parseConfigFromLuaState(allocator: std.mem.Allocator, L: *anyopaque) LuaConfigError!Config {
    const lua: *zlua.Lua = @ptrCast(@alignCast(L));
    if (lua.isNil(-1)) {
        return lua_shared.emptyConfig();
    }
    if (!lua.isTable(-1)) {
        return LuaConfigError.InvalidConfig;
    }

    const table_index = lua.absIndex(-1);
    lua.pushNil();
    if (!lua.next(table_index)) {
        return lua_shared.emptyConfig();
    }
    lua.pop(2);

    return try parseNativeScalarOverlay(allocator, lua, table_index);
}
