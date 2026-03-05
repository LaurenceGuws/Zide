const std = @import("std");
const zlua = @import("zlua");
const iface = @import("./lua_config_iface.zig");
const capi = @import("./lua_config_capi.zig");
const lua_shared = @import("./lua_config_shared.zig");

comptime {
    _ = zlua.Lua;
}

pub const LuaConfigError = iface.LuaConfigError;
pub const Config = iface.Config;
pub const FontHinting = iface.FontHinting;
pub const GlyphOverflowPolicy = iface.GlyphOverflowPolicy;
pub const TerminalBlinkStyle = iface.TerminalBlinkStyle;
pub const TerminalDisableLigaturesStrategy = iface.TerminalDisableLigaturesStrategy;
pub const TabBarWidthMode = iface.TabBarWidthMode;
pub const ThemeConfig = iface.ThemeConfig;

pub fn loadConfig(allocator: std.mem.Allocator) LuaConfigError!Config {
    var config: Config = .{
        .log_file_filter = null,
        .log_console_filter = null,
        .sdl_log_level = null,
        .editor_wrap = null,
        .editor_large_jump_rows = null,
        .editor_highlight_budget = null,
        .editor_width_budget = null,
        .app_font_path = null,
        .app_font_size = null,
        .editor_font_path = null,
        .editor_font_size = null,
        .editor_font_features = null,
        .editor_disable_ligatures = null,
        .terminal_font_path = null,
        .terminal_font_size = null,
        .terminal_blink_style = null,
        .terminal_disable_ligatures = null,
        .terminal_font_features = null,
        .terminal_scrollback_rows = null,
        .terminal_cursor_shape = null,
        .terminal_cursor_blink = null,
        .editor_tab_bar_width_mode = null,
        .terminal_tab_bar_show_single_tab = null,
        .terminal_tab_bar_width_mode = null,
        .terminal_focus_report_window = null,
        .terminal_focus_report_pane = null,
        .font_lcd = null,
        .font_hinting = null,
        .font_autohint = null,
        .font_glyph_overflow = null,
        .text_gamma = null,
        .text_contrast = null,
        .text_linear_correction = null,
        .theme = null,
        .app_theme = null,
        .editor_theme = null,
        .terminal_theme = null,
        .keybinds_no_defaults = null,
        .keybinds = null,
    };

    if (capi.fileExists("assets/config/init.lua")) {
        config = try capi.loadConfigFromFile(allocator, "assets/config/init.lua");
    }

    if (try capi.findUserConfigPath(allocator)) |path| {
        defer allocator.free(path);
        var user_config = try capi.loadConfigFromFile(allocator, path);
        capi.mergeConfig(allocator, &config, user_config);
        lua_shared.freeConfig(allocator, &user_config);
    }

    if (capi.fileExists(".zide.lua")) {
        var project_config = try capi.loadConfigFromFile(allocator, ".zide.lua");
        capi.mergeConfig(allocator, &config, project_config);
        lua_shared.freeConfig(allocator, &project_config);
    }

    return config;
}

pub fn freeConfig(allocator: std.mem.Allocator, config: *Config) void {
    lua_shared.freeConfig(allocator, config);
}

pub fn applyThemeConfig(theme: *iface.Theme, overlay: ThemeConfig) void {
    lua_shared.applyThemeConfig(theme, overlay);
}
