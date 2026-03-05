const std = @import("std");
const zlua = @import("zlua");
const capi_bridge = @import("./lua_config_capi_bridge.zig");
const lua_shared = @import("./lua_config_shared.zig");

pub const LuaConfigError = capi_bridge.LuaConfigError;
pub const Config = capi_bridge.Config;
const SdlLogLevel = std.meta.Child(@TypeOf((@as(Config, undefined)).sdl_log_level));
const TabBarWidthMode = std.meta.Child(@TypeOf((@as(Config, undefined)).editor_tab_bar_width_mode));
const CursorShape = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_cursor_shape));

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

fn parseNativeScalarOverlay(lua: *zlua.Lua, table_index: i32) Config {
    var out = lua_shared.emptyConfig();

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
    const native_overlay = parseNativeScalarOverlay(lua, table_index);
    lua_shared.mergeConfig(allocator, &parsed, native_overlay);
    return parsed;
}
