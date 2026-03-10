const std = @import("std");
const zlua = @import("zlua");
const iface = @import("./lua_config_iface.zig");
const lua_shared = @import("./lua_config_shared.zig");
const lua_theme_parse = @import("./lua_config_theme_parse.zig");
const app_logger = @import("../app_logger.zig");
const input_actions = @import("../input/input_actions.zig");
const input_types = @import("../types/input.zig");

pub const LuaConfigError = iface.LuaConfigError;
pub const Config = iface.Config;
const ThemeConfig = iface.ThemeConfig;
const LogLevel = std.meta.Child(@TypeOf((@as(Config, undefined)).log_file_level));
const SdlLogLevel = std.meta.Child(@TypeOf((@as(Config, undefined)).sdl_log_level));
const TabBarWidthMode = std.meta.Child(@TypeOf((@as(Config, undefined)).editor_tab_bar_width_mode));
const CursorShape = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_cursor_shape));
const FontHinting = std.meta.Child(@TypeOf((@as(Config, undefined)).font_hinting));
const GlyphOverflow = std.meta.Child(@TypeOf((@as(Config, undefined)).font_glyph_overflow));
const TerminalBlinkStyle = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_blink_style));
const LigatureStrategy = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_disable_ligatures));
const TerminalNewTabStartLocationMode = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_new_tab_start_location));
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

fn parseLoggerLevelFromString(value: []const u8) ?LogLevel {
    return app_logger.levelFromString(value);
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

fn parseTerminalNewTabStartLocationModeFromString(value: []const u8) ?TerminalNewTabStartLocationMode {
    if (std.mem.eql(u8, value, "current")) return .current;
    if (std.mem.eql(u8, value, "default")) return .default;
    return null;
}

fn normalizeScrollback(value: i64) usize {
    if (value < @as(i64, @intCast(terminal_scrollback_min)) or value > @as(i64, @intCast(terminal_scrollback_max))) {
        return terminal_scrollback_default;
    }
    return @intCast(value);
}

fn parsePositiveF32(lua: *zlua.Lua, idx: i32) ?f32 {
    if (!lua.isNumber(idx)) return null;
    if (lua.toNumber(idx)) |v| {
        if (v > 0) return @floatCast(v);
    } else |_| {}
    return null;
}

const SelectionOverlayPrefix = enum {
    global,
    editor,
    terminal,
};

fn parseSelectionOverlayTable(
    lua: *zlua.Lua,
    idx: i32,
    out: *Config,
    prefix: SelectionOverlayPrefix,
) void {
    if (!lua.isTable(idx)) return;
    const table_idx = lua.absIndex(idx);

    _ = lua.getField(table_idx, "smooth");
    if (lua.isBoolean(-1)) {
        const value = lua.toBoolean(-1);
        switch (prefix) {
            .global => out.selection_overlay_smooth = value,
            .editor => out.editor_selection_overlay_smooth = value,
            .terminal => out.terminal_selection_overlay_smooth = value,
        }
    }
    lua.pop(1);

    _ = lua.getField(table_idx, "corner_px");
    if (parsePositiveF32(lua, -1)) |value| {
        switch (prefix) {
            .global => out.selection_overlay_corner_px = value,
            .editor => out.editor_selection_overlay_corner_px = value,
            .terminal => out.terminal_selection_overlay_corner_px = value,
        }
    }
    lua.pop(1);

    _ = lua.getField(table_idx, "pad_px");
    if (parsePositiveF32(lua, -1)) |value| {
        switch (prefix) {
            .global => out.selection_overlay_pad_px = value,
            .editor => out.editor_selection_overlay_pad_px = value,
            .terminal => out.terminal_selection_overlay_pad_px = value,
        }
    }
    lua.pop(1);
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
    if (try lua_theme_parse.parseThemeAtStackIndex(lua, -1)) |parsed| out.theme = parsed;
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

        _ = lua.getField(logs_idx, "file_level");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseLoggerLevelFromString(v)) |level| out.log_file_level = level;
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(logs_idx, "console_level");
        if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (parseLoggerLevelFromString(v)) |level| out.log_console_level = level;
            } else |_| {}
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

    _ = lua.getField(table_index, "selection_overlay_smooth");
    if (lua.isBoolean(-1)) out.selection_overlay_smooth = lua.toBoolean(-1);
    lua.pop(1);

    _ = lua.getField(table_index, "selection_overlay_corner_px");
    if (parsePositiveF32(lua, -1)) |v| out.selection_overlay_corner_px = v;
    lua.pop(1);

    _ = lua.getField(table_index, "selection_overlay_pad_px");
    if (parsePositiveF32(lua, -1)) |v| out.selection_overlay_pad_px = v;
    lua.pop(1);

    _ = lua.getField(table_index, "selection_overlay");
    parseSelectionOverlayTable(lua, -1, &out, .global);
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

    _ = lua.getField(table_index, "terminal_texture_shift");
    if (lua.isBoolean(-1)) out.terminal_texture_shift = lua.toBoolean(-1);
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

    _ = lua.getField(table_index, "terminal_default_start_location");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            replaceOwnedString(allocator, &out.terminal_default_start_location, try allocator.dupe(u8, v));
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_new_tab_start_location");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (parseTerminalNewTabStartLocationModeFromString(v)) |mode| {
                out.terminal_new_tab_start_location = mode;
            }
        } else |_| {}
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
        if (try lua_theme_parse.parseThemeAtStackIndex(lua, -1)) |parsed| out.app_theme = parsed;
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
            if (lua_theme_parse.parseEditorThemeAtStackIndex(lua, -1)) |parsed| out.editor_theme = parsed;
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

        _ = lua.getField(editor_idx, "selection_overlay");
        parseSelectionOverlayTable(lua, -1, &out, .editor);
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
        if (try lua_theme_parse.parseThemeAtStackIndex(lua, -1)) |parsed| out.terminal_theme = parsed;
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

        _ = lua.getField(terminal_idx, "texture_shift");
        if (lua.isBoolean(-1)) out.terminal_texture_shift = lua.toBoolean(-1);
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

        _ = lua.getField(terminal_idx, "start_location");
        if (lua.isTable(-1)) {
            const start_location_idx = lua.absIndex(-1);
            _ = lua.getField(start_location_idx, "default");
            if (lua.isString(-1)) {
                if (lua.toString(-1)) |v| {
                    replaceOwnedString(allocator, &out.terminal_default_start_location, try allocator.dupe(u8, v));
                } else |_| {}
            }
            lua.pop(1);

            _ = lua.getField(start_location_idx, "new_tab");
            if (lua.isString(-1)) {
                if (lua.toString(-1)) |v| {
                    if (parseTerminalNewTabStartLocationModeFromString(v)) |mode| {
                        out.terminal_new_tab_start_location = mode;
                    }
                } else |_| {}
            }
            lua.pop(1);
        }
        lua.pop(1);

        _ = lua.getField(terminal_idx, "selection_overlay");
        parseSelectionOverlayTable(lua, -1, &out, .terminal);
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
