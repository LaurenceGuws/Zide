const std = @import("std");
const zlua = @import("zlua");
const iface = @import("./lua_config_iface.zig");
const lua_font_parse = @import("./lua_config_font_parse.zig");
const lua_keybind_parse = @import("./lua_config_keybind_parse.zig");
const lua_log_parse = @import("./lua_config_log_parse.zig");
const lua_runtime_parse = @import("./lua_config_runtime_parse.zig");
const lua_shared = @import("./lua_config_shared.zig");
const lua_theme_parse = @import("./lua_config_theme_parse.zig");
const app_logger = @import("../app_logger.zig");

pub const LuaConfigError = iface.LuaConfigError;
pub const Config = iface.Config;
const ThemeConfig = iface.ThemeConfig;

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

fn parseNativeScalarOverlay(allocator: std.mem.Allocator, lua: *zlua.Lua, table_index: i32) !Config {
    var out = lua_shared.emptyConfig();

    _ = lua.getField(table_index, "theme");
    if (try lua_theme_parse.parseThemeAtStackIndex(lua, -1)) |parsed| out.theme = parsed;
    lua.pop(1);
    try lua_log_parse.parseLogSettings(allocator, lua, table_index, &out);

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
    if (lua_runtime_parse.parsePositiveF32(lua, -1)) |v| out.selection_overlay_corner_px = v;
    lua.pop(1);

    _ = lua.getField(table_index, "selection_overlay_pad_px");
    if (lua_runtime_parse.parsePositiveF32(lua, -1)) |v| out.selection_overlay_pad_px = v;
    lua.pop(1);

    _ = lua.getField(table_index, "selection_overlay");
    lua_runtime_parse.parseSelectionOverlayTable(lua, -1, &out, .global);
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_scrollback_rows");
    if (lua.isNumber(-1)) {
        if (lua.toInteger(-1)) |v| {
            out.terminal_scrollback_rows = lua_runtime_parse.normalizeScrollback(v);
        } else |_| {}
    }
    lua.pop(1);

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

    try lua_font_parse.parseRootFontSettings(allocator, lua, table_index, &out);

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
            if (lua_runtime_parse.parseTerminalNewTabStartLocationModeFromString(v)) |mode| {
                out.terminal_new_tab_start_location = mode;
            }
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "editor_tab_bar_width_mode");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (lua_runtime_parse.parseTabBarWidthModeFromString(v)) |mode| out.editor_tab_bar_width_mode = mode;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_tab_bar_width_mode");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (lua_runtime_parse.parseTabBarWidthModeFromString(v)) |mode| out.terminal_tab_bar_width_mode = mode;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_cursor_shape");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (lua_runtime_parse.parseCursorShapeFromString(v)) |shape| out.terminal_cursor_shape = shape;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_blink_style");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (lua_runtime_parse.parseBlinkStyleFromString(v)) |style| out.terminal_blink_style = style;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal_disable_ligatures");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (lua_runtime_parse.parseLigatureStrategyFromString(v)) |strategy| out.terminal_disable_ligatures = strategy;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "editor_disable_ligatures");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |v| {
            if (lua_runtime_parse.parseLigatureStrategyFromString(v)) |strategy| out.editor_disable_ligatures = strategy;
        } else |_| {}
    }
    lua.pop(1);

    _ = lua.getField(table_index, "app");
    if (lua.isTable(-1)) {
        const app_idx = lua.absIndex(-1);
        _ = lua.getField(app_idx, "theme");
        if (try lua_theme_parse.parseThemeAtStackIndex(lua, -1)) |parsed| out.app_theme = parsed;
        lua.pop(1);
        try lua_font_parse.parseAppFontTable(allocator, lua, app_idx, &out);
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

        _ = lua.getField(editor_idx, "theme");
        if (lua.isTable(-1)) {
            if (lua_theme_parse.parseEditorThemeAtStackIndex(lua, -1)) |parsed| out.editor_theme = parsed;
        }
        lua.pop(1);
        try lua_font_parse.parseEditorFontTable(
            allocator,
            lua,
            editor_idx,
            &out,
            parseFilterValueOwned,
            replaceOwnedString,
            lua_runtime_parse.parseLigatureStrategyFromString,
        );

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
                    if (lua_runtime_parse.parseTabBarWidthModeFromString(v)) |mode| {
                        out.editor_tab_bar_width_mode = mode;
                    }
                } else |_| {}
            }
            lua.pop(1);
        }
        lua.pop(1);

        _ = lua.getField(editor_idx, "selection_overlay");
        lua_runtime_parse.parseSelectionOverlayTable(lua, -1, &out, .editor);
        lua.pop(1);
    }
    lua.pop(1);

    _ = lua.getField(table_index, "terminal");
    if (lua.isTable(-1)) {
        const terminal_idx = lua.absIndex(-1);

        _ = lua.getField(terminal_idx, "theme");
        if (try lua_theme_parse.parseThemeAtStackIndex(lua, -1)) |parsed| out.terminal_theme = parsed;
        lua.pop(1);
        try lua_font_parse.parseTerminalFontTable(
            allocator,
            lua,
            terminal_idx,
            &out,
            parseFilterValueOwned,
            replaceOwnedString,
            lua_runtime_parse.parseLigatureStrategyFromString,
        );

        _ = lua.getField(terminal_idx, "blink");
        if (lua.isBoolean(-1)) {
            out.terminal_blink_style = if (lua.toBoolean(-1)) .kitty else .off;
        } else if (lua.isString(-1)) {
            if (lua.toString(-1)) |v| {
                if (lua_runtime_parse.parseBlinkStyleFromString(v)) |style| {
                    out.terminal_blink_style = style;
                }
            } else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(terminal_idx, "scrollback");
        if (lua.isNumber(-1)) {
            if (lua.toInteger(-1)) |v| out.terminal_scrollback_rows = lua_runtime_parse.normalizeScrollback(v) else |_| {}
        }
        lua.pop(1);

        _ = lua.getField(terminal_idx, "cursor");
        if (lua.isTable(-1)) {
            const cursor_idx = lua.absIndex(-1);
            _ = lua.getField(cursor_idx, "shape");
            if (lua.isString(-1)) {
                if (lua.toString(-1)) |v| {
                    if (lua_runtime_parse.parseCursorShapeFromString(v)) |shape| {
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
                    if (lua_runtime_parse.parseTabBarWidthModeFromString(v)) |mode| {
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
                    if (lua_runtime_parse.parseTerminalNewTabStartLocationModeFromString(v)) |mode| {
                        out.terminal_new_tab_start_location = mode;
                    }
                } else |_| {}
            }
            lua.pop(1);
        }
        lua.pop(1);

        _ = lua.getField(terminal_idx, "selection_overlay");
        lua_runtime_parse.parseSelectionOverlayTable(lua, -1, &out, .terminal);
        lua.pop(1);
    }
    lua.pop(1);

    _ = lua.getField(table_index, "font_rendering");
    lua_font_parse.parseFontRenderingTable(lua, -1, &out);
    lua.pop(1);

    _ = lua.getField(table_index, "keybinds");
    if (lua.isTable(-1)) {
        const keybinds_idx = lua.absIndex(-1);
        _ = lua.getField(keybinds_idx, "no_defaults");
        if (lua.isBoolean(-1)) out.keybinds_no_defaults = lua.toBoolean(-1);
        lua.pop(1);
        out.keybinds = try lua_keybind_parse.parseKeybindsNative(allocator, lua, keybinds_idx);
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

test "parseConfigFromLuaState parses per-tag log level overrides" {
    const allocator = std.testing.allocator;
    const lua = try zlua.Lua.init(allocator);
    defer lua.deinit();
    lua.openLibs();

    try lua.loadString(
        \\return {
        \\    logs = {
        \\        file_level = "warning",
        \\        console_level = "error",
        \\        file_levels = {
        \\            ["terminal.ui.redraw"] = "debug",
        \\            ["terminal.ui.perf"] = "info",
        \\        },
        \\        console_levels = {
        \\            ["terminal.ui.lifecycle"] = "info",
        \\        },
        \\    },
        \\}
    );
    try lua.protectedCall(.{ .args = 0, .results = 1 });

    var config = try parseConfigFromLuaState(allocator, @ptrCast(lua));
    defer lua_shared.freeConfig(allocator, &config);
    defer app_logger.deinit();

    try std.testing.expectEqual(@as(?app_logger.Level, .warning), config.log_file_level);
    try std.testing.expectEqual(@as(?app_logger.Level, .@"error"), config.log_console_level);
    try std.testing.expect(config.log_file_level_overrides != null);
    try std.testing.expect(config.log_console_level_overrides != null);

    app_logger.resetConfig();
    app_logger.setFileLevel(config.log_file_level.?);
    app_logger.setConsoleLevel(config.log_console_level.?);
    try app_logger.setFileLevelOverrideString(config.log_file_level_overrides.?);
    try app_logger.setConsoleLevelOverrideString(config.log_console_level_overrides.?);

    try std.testing.expectEqual(app_logger.Level.debug, app_logger.logger("terminal.ui.redraw").file_level);
    try std.testing.expectEqual(app_logger.Level.info, app_logger.logger("terminal.ui.perf").file_level);
    try std.testing.expectEqual(app_logger.Level.warning, app_logger.logger("terminal.env").file_level);
    try std.testing.expectEqual(app_logger.Level.info, app_logger.logger("terminal.ui.lifecycle").console_level);
    try std.testing.expectEqual(app_logger.Level.@"error", app_logger.logger("terminal.ui.redraw").console_level);
}
