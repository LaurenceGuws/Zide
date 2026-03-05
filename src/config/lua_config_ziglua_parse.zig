const std = @import("std");
const zlua = @import("zlua");
const capi_bridge = @import("./lua_config_capi_bridge.zig");
const lua_shared = @import("./lua_config_shared.zig");

pub const LuaConfigError = capi_bridge.LuaConfigError;
pub const Config = capi_bridge.Config;
const SdlLogLevel = std.meta.Child(@TypeOf((@as(Config, undefined)).sdl_log_level));
const TabBarWidthMode = std.meta.Child(@TypeOf((@as(Config, undefined)).editor_tab_bar_width_mode));
const CursorShape = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_cursor_shape));
const FontHinting = std.meta.Child(@TypeOf((@as(Config, undefined)).font_hinting));
const GlyphOverflow = std.meta.Child(@TypeOf((@as(Config, undefined)).font_glyph_overflow));
const TerminalBlinkStyle = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_blink_style));
const LigatureStrategy = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_disable_ligatures));

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
    return null;
}

fn parseLigatureStrategyFromString(value: []const u8) ?LigatureStrategy {
    if (std.mem.eql(u8, value, "never")) return .never;
    if (std.mem.eql(u8, value, "cursor")) return .cursor;
    if (std.mem.eql(u8, value, "always")) return .always;
    return null;
}

fn parseNativeScalarOverlay(allocator: std.mem.Allocator, lua: *zlua.Lua, table_index: i32) !Config {
    var out = lua_shared.emptyConfig();

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

    _ = lua.getField(table_index, "terminal_scrollback_rows");
    if (lua.isNumber(-1)) {
        if (lua.toInteger(-1)) |v| {
            if (v > 0) out.terminal_scrollback_rows = @intCast(v);
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

    return out;
}

// Migration seam: replace this bridge call with native ziglua table parsing.
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

    var parsed = try capi_bridge.parseConfigFromLuaState(allocator, L);
    var native_overlay = try parseNativeScalarOverlay(allocator, lua, table_index);
    defer lua_shared.freeConfig(allocator, &native_overlay);
    lua_shared.mergeConfig(allocator, &parsed, native_overlay);
    return parsed;
}
