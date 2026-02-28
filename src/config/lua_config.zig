const std = @import("std");
const renderer = @import("../ui/renderer.zig");
const sdl_api = @import("../platform/sdl_api.zig");
const input_actions = @import("../input/input_actions.zig");
const input_types = @import("../types/input.zig");
const app_logger = @import("../app_logger.zig");
const term_types = @import("../terminal/model/types.zig");

const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lauxlib.h");
    @cInclude("lualib.h");
});

const sdl = sdl_api.c;

const Color = renderer.Color;
const Theme = renderer.Theme;

pub const LuaConfigError = error{
    LuaInitFailed,
    LuaLoadFailed,
    LuaRunFailed,
    InvalidConfig,
    OutOfMemory,
};

pub const Config = struct {
    log_file_filter: ?[]u8,
    log_console_filter: ?[]u8,
    sdl_log_level: ?c_int,
    editor_wrap: ?bool,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
    app_font_path: ?[]u8,
    app_font_size: ?f32,
    editor_font_path: ?[]u8,
    editor_font_size: ?f32,
    editor_font_features: ?[]u8,
    editor_disable_ligatures: ?TerminalDisableLigaturesStrategy,
    terminal_font_path: ?[]u8,
    terminal_font_size: ?f32,
    terminal_blink_style: ?TerminalBlinkStyle,
    terminal_disable_ligatures: ?TerminalDisableLigaturesStrategy,
    terminal_font_features: ?[]u8,
    terminal_scrollback_rows: ?usize,
    terminal_cursor_shape: ?term_types.CursorShape,
    terminal_cursor_blink: ?bool,
    terminal_focus_report_window: ?bool,
    terminal_focus_report_pane: ?bool,
    font_lcd: ?bool,
    font_hinting: ?FontHinting,
    font_autohint: ?bool,
    font_glyph_overflow: ?GlyphOverflowPolicy,
    text_gamma: ?f32,
    text_contrast: ?f32,
    text_linear_correction: ?bool,
    theme: ?ThemeConfig,
    app_theme: ?ThemeConfig,
    editor_theme: ?ThemeConfig,
    terminal_theme: ?ThemeConfig,
    keybinds_no_defaults: ?bool,
    keybinds: ?[]input_actions.BindSpec,
};

pub const FontHinting = enum {
    default,
    none,
    light,
    normal,
};

pub const GlyphOverflowPolicy = enum {
    when_followed_by_space,
    never,
    always,
};

pub const TerminalBlinkStyle = enum {
    kitty,
    off,
};

pub const TerminalDisableLigaturesStrategy = enum {
    never,
    cursor,
    always,
};

const terminal_scrollback_default: usize = 1000;
const terminal_scrollback_min: usize = 100;
const terminal_scrollback_max: usize = 100000;
const sdl_log_level_default: c_int = sdl.SDL_LOG_PRIORITY_INFO;
const font_hinting_default: FontHinting = .default;
const glyph_overflow_default: GlyphOverflowPolicy = .when_followed_by_space;
const ligature_strategy_default: TerminalDisableLigaturesStrategy = .never;
const terminal_blink_default: TerminalBlinkStyle = .kitty;
const text_gamma_default: f32 = 1.0;
const text_contrast_default: f32 = 1.0;
const text_linear_correction_default: bool = true;

pub const ThemeConfig = struct {
    background: ?Color = null,
    foreground: ?Color = null,
    selection: ?Color = null,
    cursor: ?Color = null,
    link: ?Color = null,
    line_number: ?Color = null,
    line_number_bg: ?Color = null,
    current_line: ?Color = null,
    ui_bar_bg: ?Color = null,
    ui_panel_bg: ?Color = null,
    ui_panel_overlay: ?Color = null,
    ui_hover: ?Color = null,
    ui_pressed: ?Color = null,
    ui_tab_inactive_bg: ?Color = null,
    ui_accent: ?Color = null,
    ui_border: ?Color = null,
    ui_modified: ?Color = null,
    ui_text: ?Color = null,
    ui_text_inactive: ?Color = null,
    comment_color: ?Color = null,
    string: ?Color = null,
    keyword: ?Color = null,
    number: ?Color = null,
    function: ?Color = null,
    variable: ?Color = null,
    type_name: ?Color = null,
    operator: ?Color = null,
    builtin_color: ?Color = null,
    punctuation: ?Color = null,
    constant: ?Color = null,
    attribute: ?Color = null,
    namespace: ?Color = null,
    label: ?Color = null,
    error_token: ?Color = null,
    ansi_colors: [16]?Color = .{null} ** 16,
};

pub fn loadConfig(allocator: std.mem.Allocator) LuaConfigError!Config {
    var config: Config = .{
        .log_file_filter = null,
        .log_console_filter = null,
        .sdl_log_level = null,
        .editor_wrap = null,
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
    if (fileExists("assets/config/init.lua")) {
        config = try loadConfigFromFile(allocator, "assets/config/init.lua");
    }

    if (try findUserConfigPath(allocator)) |path| {
        defer allocator.free(path);
        var user_config = try loadConfigFromFile(allocator, path);
        mergeConfig(allocator, &config, user_config);
        freeConfig(allocator, &user_config);
    }

    if (fileExists(".zide.lua")) {
        var project_config = try loadConfigFromFile(allocator, ".zide.lua");
        mergeConfig(allocator, &config, project_config);
        freeConfig(allocator, &project_config);
    }

    return config;
}

pub fn freeConfig(allocator: std.mem.Allocator, config: *Config) void {
    if (config.log_file_filter) |filter| {
        allocator.free(filter);
        config.log_file_filter = null;
    }
    if (config.log_console_filter) |filter| {
        allocator.free(filter);
        config.log_console_filter = null;
    }
    if (config.app_font_path) |path| {
        allocator.free(path);
        config.app_font_path = null;
    }
    if (config.editor_font_path) |path| {
        allocator.free(path);
        config.editor_font_path = null;
    }
    if (config.editor_font_features) |features| {
        allocator.free(features);
        config.editor_font_features = null;
    }
    if (config.terminal_font_path) |path| {
        allocator.free(path);
        config.terminal_font_path = null;
    }
    if (config.terminal_font_features) |features| {
        allocator.free(features);
        config.terminal_font_features = null;
    }
    if (config.keybinds) |binds| {
        allocator.free(binds);
        config.keybinds = null;
    }

    config.keybinds_no_defaults = null;

    config.font_lcd = null;
    config.font_hinting = null;
    config.font_autohint = null;
    config.font_glyph_overflow = null;
    config.text_gamma = null;
    config.text_contrast = null;
    config.text_linear_correction = null;
}

fn mergeConfig(allocator: std.mem.Allocator, base: *Config, overlay: Config) void {
    if (overlay.log_file_filter) |filter| {
        if (base.log_file_filter) |old| allocator.free(old);
        base.log_file_filter = allocator.dupe(u8, filter) catch base.log_file_filter;
    }
    if (overlay.log_console_filter) |filter| {
        if (base.log_console_filter) |old| allocator.free(old);
        base.log_console_filter = allocator.dupe(u8, filter) catch base.log_console_filter;
    }
    if (overlay.sdl_log_level) |level| {
        base.sdl_log_level = level;
    }
    if (overlay.editor_wrap != null) {
        base.editor_wrap = overlay.editor_wrap;
    }
    if (overlay.editor_highlight_budget != null) {
        base.editor_highlight_budget = overlay.editor_highlight_budget;
    }
    if (overlay.editor_width_budget != null) {
        base.editor_width_budget = overlay.editor_width_budget;
    }
    if (overlay.app_font_path) |path| {
        if (base.app_font_path) |old| allocator.free(old);
        base.app_font_path = allocator.dupe(u8, path) catch base.app_font_path;
    }
    if (overlay.app_font_size != null) {
        base.app_font_size = overlay.app_font_size;
    }
    if (overlay.editor_font_path) |path| {
        if (base.editor_font_path) |old| allocator.free(old);
        base.editor_font_path = allocator.dupe(u8, path) catch base.editor_font_path;
    }
    if (overlay.editor_font_size != null) {
        base.editor_font_size = overlay.editor_font_size;
    }
    if (overlay.editor_font_features) |features| {
        if (base.editor_font_features) |old| allocator.free(old);
        base.editor_font_features = allocator.dupe(u8, features) catch base.editor_font_features;
    }
    if (overlay.editor_disable_ligatures != null) {
        base.editor_disable_ligatures = overlay.editor_disable_ligatures;
    }
    if (overlay.terminal_font_path) |path| {
        if (base.terminal_font_path) |old| allocator.free(old);
        base.terminal_font_path = allocator.dupe(u8, path) catch base.terminal_font_path;
    }
    if (overlay.terminal_font_size != null) {
        base.terminal_font_size = overlay.terminal_font_size;
    }
    if (overlay.terminal_blink_style != null) {
        base.terminal_blink_style = overlay.terminal_blink_style;
    }
    if (overlay.terminal_disable_ligatures != null) {
        base.terminal_disable_ligatures = overlay.terminal_disable_ligatures;
    }
    if (overlay.terminal_font_features) |features| {
        if (base.terminal_font_features) |old| allocator.free(old);
        base.terminal_font_features = allocator.dupe(u8, features) catch base.terminal_font_features;
    }
    if (overlay.terminal_scrollback_rows != null) {
        base.terminal_scrollback_rows = overlay.terminal_scrollback_rows;
    }
    if (overlay.terminal_cursor_shape != null) {
        base.terminal_cursor_shape = overlay.terminal_cursor_shape;
    }
    if (overlay.terminal_cursor_blink != null) {
        base.terminal_cursor_blink = overlay.terminal_cursor_blink;
    }
    if (overlay.terminal_focus_report_window != null) {
        base.terminal_focus_report_window = overlay.terminal_focus_report_window;
    }
    if (overlay.terminal_focus_report_pane != null) {
        base.terminal_focus_report_pane = overlay.terminal_focus_report_pane;
    }
    if (overlay.font_lcd != null) {
        base.font_lcd = overlay.font_lcd;
    }
    if (overlay.font_hinting != null) {
        base.font_hinting = overlay.font_hinting;
    }
    if (overlay.font_autohint != null) {
        base.font_autohint = overlay.font_autohint;
    }
    if (overlay.font_glyph_overflow != null) {
        base.font_glyph_overflow = overlay.font_glyph_overflow;
    }
    if (overlay.text_gamma != null) {
        base.text_gamma = overlay.text_gamma;
    }
    if (overlay.text_contrast != null) {
        base.text_contrast = overlay.text_contrast;
    }
    if (overlay.text_linear_correction != null) {
        base.text_linear_correction = overlay.text_linear_correction;
    }
    if (overlay.theme) |overlay_theme| {
        if (base.theme) |base_theme| {
            var merged = base_theme;
            mergeThemeConfig(&merged, overlay_theme);
            base.theme = merged;
        } else {
            base.theme = overlay_theme;
        }
    }
    if (overlay.app_theme) |overlay_theme| {
        if (base.app_theme) |base_theme| {
            var merged = base_theme;
            mergeThemeConfig(&merged, overlay_theme);
            base.app_theme = merged;
        } else {
            base.app_theme = overlay_theme;
        }
    }
    if (overlay.editor_theme) |overlay_theme| {
        if (base.editor_theme) |base_theme| {
            var merged = base_theme;
            mergeThemeConfig(&merged, overlay_theme);
            base.editor_theme = merged;
        } else {
            base.editor_theme = overlay_theme;
        }
    }
    if (overlay.terminal_theme) |overlay_theme| {
        if (base.terminal_theme) |base_theme| {
            var merged = base_theme;
            mergeThemeConfig(&merged, overlay_theme);
            base.terminal_theme = merged;
        } else {
            base.terminal_theme = overlay_theme;
        }
    }
    if (overlay.keybinds) |binds| {
        if (overlay.keybinds_no_defaults == true or base.keybinds == null) {
            if (base.keybinds) |old| allocator.free(old);
            base.keybinds = allocator.dupe(input_actions.BindSpec, binds) catch base.keybinds;
        } else if (base.keybinds) |base_binds| {
            const merged = mergeKeybinds(allocator, base_binds, binds) catch base_binds;
            if (merged.ptr != base_binds.ptr) {
                allocator.free(base_binds);
            }
            base.keybinds = merged;
        }
    }
    if (overlay.keybinds_no_defaults != null) {
        base.keybinds_no_defaults = overlay.keybinds_no_defaults;
    }
}

fn loadConfigFromFile(allocator: std.mem.Allocator, path: []const u8) LuaConfigError!Config {
    const L = c.luaL_newstate() orelse return LuaConfigError.LuaInitFailed;
    defer c.lua_close(L);
    c.luaL_openlibs(L);

    if (c.luaL_loadfilex(L, path.ptr, null) != 0) {
        return LuaConfigError.LuaLoadFailed;
    }
    if (c.lua_pcallk(L, 0, 1, 0, 0, null) != 0) {
        return LuaConfigError.LuaRunFailed;
    }

    return parseConfigFromStack(allocator, L);
}

fn parseConfigFromStack(allocator: std.mem.Allocator, L: *c.lua_State) LuaConfigError!Config {
    if (c.lua_isnil(L, -1)) {
        return .{
            .log_file_filter = null,
            .log_console_filter = null,
            .sdl_log_level = null,
            .editor_wrap = null,
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
    }
    if (!c.lua_istable(L, -1)) {
        return LuaConfigError.InvalidConfig;
    }

    var log_file_filter: ?[]u8 = null;
    var log_console_filter: ?[]u8 = null;
    var sdl_log_level: ?c_int = null;
    var editor_wrap: ?bool = null;
    var editor_highlight_budget: ?usize = null;
    var editor_width_budget: ?usize = null;
    var app_font_path: ?[]u8 = null;
    var app_font_size: ?f32 = null;
    var editor_font_path: ?[]u8 = null;
    var editor_font_size: ?f32 = null;
    var editor_font_features: ?[]u8 = null;
    var editor_disable_ligatures: ?TerminalDisableLigaturesStrategy = null;
    var terminal_font_path: ?[]u8 = null;
    var terminal_font_size: ?f32 = null;
    var terminal_blink_style: ?TerminalBlinkStyle = null;
    var terminal_disable_ligatures: ?TerminalDisableLigaturesStrategy = null;
    var terminal_font_features: ?[]u8 = null;
    var terminal_scrollback_rows: ?usize = null;
    var terminal_cursor_shape: ?term_types.CursorShape = null;
    var terminal_cursor_blink: ?bool = null;
    var terminal_focus_report_window: ?bool = null;
    var terminal_focus_report_pane: ?bool = null;
    var font_lcd: ?bool = null;
    var font_hinting: ?FontHinting = null;
    var font_autohint: ?bool = null;
    var font_glyph_overflow: ?GlyphOverflowPolicy = null;
    var text_gamma: ?f32 = null;
    var text_contrast: ?f32 = null;
    var text_linear_correction: ?bool = null;
    var theme: ?ThemeConfig = null;
    var app_theme: ?ThemeConfig = null;
    var editor_theme: ?ThemeConfig = null;
    var terminal_theme: ?ThemeConfig = null;
    var keybinds_no_defaults: ?bool = null;
    var keybinds: ?[]input_actions.BindSpec = null;

    _ = c.lua_getfield(L, -1, "log");
    if (c.lua_isstring(L, -1) != 0) {
        const value = try luaStringToOwned(allocator, L, -1);
        log_file_filter = value;
        log_console_filter = try allocator.dupe(u8, value);
    } else if (c.lua_istable(L, -1)) {
        if (parseLogFiltersFromTable(allocator, L, -1, &log_file_filter, &log_console_filter)) |_| {} else |_| {}
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, -1, "sdl");
    if (c.lua_isstring(L, -1) != 0) {
        sdl_log_level = parseSdlLogLevel(L, -1);
        if (sdl_log_level == null) {
            warnInvalidValue("sdl.log_level", "info");
            sdl_log_level = sdl_log_level_default;
        }
    } else if (c.lua_istable(L, -1)) {
        _ = c.lua_getfield(L, -1, "log_level");
        if (c.lua_isstring(L, -1) != 0) {
            sdl_log_level = parseSdlLogLevel(L, -1);
            if (sdl_log_level == null) {
                warnInvalidValue("sdl.log_level", "info");
                sdl_log_level = sdl_log_level_default;
            }
        } else if (!c.lua_isnil(L, -1)) {
            warnInvalidValue("sdl.log_level", "info");
            sdl_log_level = sdl_log_level_default;
        }
        c.lua_pop(L, 1);
    } else if (!c.lua_isnil(L, -1)) {
        warnInvalidValue("sdl.log_level", "info");
        sdl_log_level = sdl_log_level_default;
    }
    c.lua_pop(L, 1);

    if (sdl_log_level == null) {
        _ = c.lua_getfield(L, -1, "raylib");
        if (c.lua_isstring(L, -1) != 0) {
            sdl_log_level = parseSdlLogLevel(L, -1);
            if (sdl_log_level == null) {
                warnInvalidValue("raylib.log_level", "info");
                sdl_log_level = sdl_log_level_default;
            }
        } else if (c.lua_istable(L, -1)) {
            _ = c.lua_getfield(L, -1, "log_level");
            if (c.lua_isstring(L, -1) != 0) {
                sdl_log_level = parseSdlLogLevel(L, -1);
                if (sdl_log_level == null) {
                    warnInvalidValue("raylib.log_level", "info");
                    sdl_log_level = sdl_log_level_default;
                }
            } else if (!c.lua_isnil(L, -1)) {
                warnInvalidValue("raylib.log_level", "info");
                sdl_log_level = sdl_log_level_default;
            }
            c.lua_pop(L, 1);
        }
        c.lua_pop(L, 1);
    }

    _ = c.lua_getfield(L, -1, "editor");
    if (c.lua_istable(L, -1)) {
        _ = c.lua_getfield(L, -1, "theme");
        if (c.lua_istable(L, -1)) {
            editor_theme = try parseThemeFromTable(L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "font");
        if (c.lua_isstring(L, -1) != 0) {
            editor_font_path = try luaStringToOwned(allocator, L, -1);
        } else if (c.lua_istable(L, -1)) {
            parseFontTable(allocator, L, -1, &editor_font_path, &editor_font_size);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "font_features");
        if (c.lua_isstring(L, -1) != 0) {
            editor_font_features = try luaStringToOwned(allocator, L, -1);
        } else if (c.lua_istable(L, -1)) {
            editor_font_features = try luaStringListToOwned(allocator, L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "disable_ligatures");
        if (c.lua_isstring(L, -1) != 0) {
            editor_disable_ligatures = parseTerminalDisableLigatures(L, -1);
            if (editor_disable_ligatures == null) {
                warnInvalidValue("editor.disable_ligatures", "never");
                editor_disable_ligatures = ligature_strategy_default;
            }
        } else if (!c.lua_isnil(L, -1)) {
            warnInvalidValue("editor.disable_ligatures", "never");
            editor_disable_ligatures = ligature_strategy_default;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "wrap");
        if (c.lua_isboolean(L, -1)) {
            editor_wrap = c.lua_toboolean(L, -1) != 0;
        } else if (!c.lua_isnil(L, -1)) {
            warnInvalidValue("editor.wrap", "false");
            editor_wrap = false;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "render");
        if (c.lua_istable(L, -1)) {
            _ = c.lua_getfield(L, -1, "highlight_budget");
            if (c.lua_isnumber(L, -1) != 0) {
                var is_num: c_int = 0;
                const value = c.lua_tointegerx(L, -1, &is_num);
                if (is_num != 0 and value >= 0) {
                    editor_highlight_budget = @intCast(value);
                } else {
                    warnInvalidValue("editor.render.highlight_budget", "0");
                    editor_highlight_budget = 0;
                }
            } else if (!c.lua_isnil(L, -1)) {
                warnInvalidValue("editor.render.highlight_budget", "0");
                editor_highlight_budget = 0;
            }
            c.lua_pop(L, 1);

            _ = c.lua_getfield(L, -1, "width_budget");
            if (c.lua_isnumber(L, -1) != 0) {
                var is_num: c_int = 0;
                const value = c.lua_tointegerx(L, -1, &is_num);
                if (is_num != 0 and value >= 0) {
                    editor_width_budget = @intCast(value);
                } else {
                    warnInvalidValue("editor.render.width_budget", "0");
                    editor_width_budget = 0;
                }
            } else if (!c.lua_isnil(L, -1)) {
                warnInvalidValue("editor.render.width_budget", "0");
                editor_width_budget = 0;
            }
            c.lua_pop(L, 1);
        }
        c.lua_pop(L, 1);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, -1, "app");
    if (c.lua_istable(L, -1)) {
        _ = c.lua_getfield(L, -1, "theme");
        if (c.lua_istable(L, -1)) {
            app_theme = try parseThemeFromTable(L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "font");
        if (c.lua_isstring(L, -1) != 0) {
            app_font_path = try luaStringToOwned(allocator, L, -1);
        } else if (c.lua_istable(L, -1)) {
            parseFontTable(allocator, L, -1, &app_font_path, &app_font_size);
        }
        c.lua_pop(L, 1);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, -1, "terminal");
    if (c.lua_istable(L, -1)) {
        _ = c.lua_getfield(L, -1, "theme");
        if (c.lua_istable(L, -1)) {
            terminal_theme = try parseThemeFromTable(L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "font");
        if (c.lua_isstring(L, -1) != 0) {
            terminal_font_path = try luaStringToOwned(allocator, L, -1);
        } else if (c.lua_istable(L, -1)) {
            parseFontTable(allocator, L, -1, &terminal_font_path, &terminal_font_size);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "blink");
        if (c.lua_isstring(L, -1) != 0) {
            terminal_blink_style = parseTerminalBlink(L, -1);
            if (terminal_blink_style == null) {
                warnInvalidValue("terminal.blink", "kitty");
                terminal_blink_style = terminal_blink_default;
            }
        } else if (c.lua_isboolean(L, -1)) {
            terminal_blink_style = if (c.lua_toboolean(L, -1) != 0) .kitty else .off;
        } else if (!c.lua_isnil(L, -1)) {
            warnInvalidValue("terminal.blink", "kitty");
            terminal_blink_style = terminal_blink_default;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "disable_ligatures");
        if (c.lua_isstring(L, -1) != 0) {
            terminal_disable_ligatures = parseTerminalDisableLigatures(L, -1);
            if (terminal_disable_ligatures == null) {
                warnInvalidValue("terminal.disable_ligatures", "never");
                terminal_disable_ligatures = ligature_strategy_default;
            }
        } else if (!c.lua_isnil(L, -1)) {
            warnInvalidValue("terminal.disable_ligatures", "never");
            terminal_disable_ligatures = ligature_strategy_default;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "font_features");
        if (c.lua_isstring(L, -1) != 0) {
            terminal_font_features = try luaStringToOwned(allocator, L, -1);
        } else if (c.lua_istable(L, -1)) {
            terminal_font_features = try luaStringListToOwned(allocator, L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "scrollback");
        if (c.lua_isnumber(L, -1) != 0) {
            const value = c.lua_tointegerx(L, -1, null);
            if (value < @as(isize, @intCast(terminal_scrollback_min)) or value > @as(isize, @intCast(terminal_scrollback_max))) {
                std.debug.print("config warning: terminal.scrollback out of range, using {d}\n", .{terminal_scrollback_default});
                terminal_scrollback_rows = terminal_scrollback_default;
            } else {
                terminal_scrollback_rows = @intCast(value);
            }
        } else if (!c.lua_isnil(L, -1)) {
            std.debug.print("config warning: terminal.scrollback invalid, using {d}\n", .{terminal_scrollback_default});
            terminal_scrollback_rows = terminal_scrollback_default;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "cursor");
        if (c.lua_istable(L, -1)) {
            _ = c.lua_getfield(L, -1, "shape");
            if (c.lua_isstring(L, -1) != 0) {
                terminal_cursor_shape = parseCursorShape(L, -1);
                if (terminal_cursor_shape == null) {
                    std.debug.print("config warning: terminal.cursor.shape invalid, using block\n", .{});
                    terminal_cursor_shape = .block;
                }
            } else if (!c.lua_isnil(L, -1)) {
                std.debug.print("config warning: terminal.cursor.shape invalid, using block\n", .{});
                terminal_cursor_shape = .block;
            }
            c.lua_pop(L, 1);

            _ = c.lua_getfield(L, -1, "blink");
            if (c.lua_isboolean(L, -1)) {
                terminal_cursor_blink = c.lua_toboolean(L, -1) != 0;
            } else if (!c.lua_isnil(L, -1)) {
                std.debug.print("config warning: terminal.cursor.blink invalid, using true\n", .{});
                terminal_cursor_blink = true;
            }
            c.lua_pop(L, 1);
        } else if (!c.lua_isnil(L, -1)) {
            std.debug.print("config warning: terminal.cursor invalid, using defaults\n", .{});
            terminal_cursor_shape = .block;
            terminal_cursor_blink = true;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "focus_reporting");
        if (c.lua_isboolean(L, -1)) {
            const enabled = c.lua_toboolean(L, -1) != 0;
            terminal_focus_report_window = enabled;
            terminal_focus_report_pane = enabled;
        } else if (c.lua_istable(L, -1)) {
            _ = c.lua_getfield(L, -1, "window");
            if (c.lua_isboolean(L, -1)) {
                terminal_focus_report_window = c.lua_toboolean(L, -1) != 0;
            } else if (!c.lua_isnil(L, -1)) {
                warnInvalidValue("terminal.focus_reporting.window", "true");
                terminal_focus_report_window = true;
            }
            c.lua_pop(L, 1);

            _ = c.lua_getfield(L, -1, "pane");
            if (c.lua_isboolean(L, -1)) {
                terminal_focus_report_pane = c.lua_toboolean(L, -1) != 0;
            } else if (!c.lua_isnil(L, -1)) {
                warnInvalidValue("terminal.focus_reporting.pane", "false");
                terminal_focus_report_pane = false;
            }
            c.lua_pop(L, 1);
        } else if (!c.lua_isnil(L, -1)) {
            warnInvalidValue("terminal.focus_reporting", "{ window = true, pane = false }");
            terminal_focus_report_window = true;
            terminal_focus_report_pane = false;
        }
        c.lua_pop(L, 1);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, -1, "font_rendering");
    if (c.lua_istable(L, -1)) {
        _ = c.lua_getfield(L, -1, "lcd");
        if (c.lua_isboolean(L, -1)) {
            font_lcd = c.lua_toboolean(L, -1) != 0;
        } else if (!c.lua_isnil(L, -1)) {
            warnInvalidValue("font_rendering.lcd", "false");
            font_lcd = false;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "hinting");
        if (c.lua_isstring(L, -1) != 0) {
            font_hinting = parseFontHinting(L, -1);
            if (font_hinting == null) {
                warnInvalidValue("font_rendering.hinting", "default");
                font_hinting = font_hinting_default;
            }
        } else if (!c.lua_isnil(L, -1)) {
            warnInvalidValue("font_rendering.hinting", "default");
            font_hinting = font_hinting_default;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "autohint");
        if (c.lua_isboolean(L, -1)) {
            font_autohint = c.lua_toboolean(L, -1) != 0;
        } else if (!c.lua_isnil(L, -1)) {
            warnInvalidValue("font_rendering.autohint", "false");
            font_autohint = false;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "glyph_overflow");
        if (c.lua_isstring(L, -1) != 0) {
            font_glyph_overflow = parseGlyphOverflowPolicy(L, -1);
            if (font_glyph_overflow == null) {
                warnInvalidValue("font_rendering.glyph_overflow", "when_followed_by_space");
                font_glyph_overflow = glyph_overflow_default;
            }
        } else if (!c.lua_isnil(L, -1)) {
            warnInvalidValue("font_rendering.glyph_overflow", "when_followed_by_space");
            font_glyph_overflow = glyph_overflow_default;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "text");
        if (c.lua_istable(L, -1)) {
            _ = c.lua_getfield(L, -1, "gamma");
            if (c.lua_isnumber(L, -1) != 0) {
                const v = c.lua_tonumberx(L, -1, null);
                if (v > 0) {
                    text_gamma = @floatCast(v);
                } else {
                    warnInvalidValue("font_rendering.text.gamma", "1.0");
                    text_gamma = text_gamma_default;
                }
            } else if (!c.lua_isnil(L, -1)) {
                warnInvalidValue("font_rendering.text.gamma", "1.0");
                text_gamma = text_gamma_default;
            }
            c.lua_pop(L, 1);

            _ = c.lua_getfield(L, -1, "contrast");
            if (c.lua_isnumber(L, -1) != 0) {
                const v = c.lua_tonumberx(L, -1, null);
                if (v > 0) {
                    text_contrast = @floatCast(v);
                } else {
                    warnInvalidValue("font_rendering.text.contrast", "1.0");
                    text_contrast = text_contrast_default;
                }
            } else if (!c.lua_isnil(L, -1)) {
                warnInvalidValue("font_rendering.text.contrast", "1.0");
                text_contrast = text_contrast_default;
            }
            c.lua_pop(L, 1);

            _ = c.lua_getfield(L, -1, "linear_correction");
            if (c.lua_isboolean(L, -1)) {
                text_linear_correction = c.lua_toboolean(L, -1) != 0;
            } else if (!c.lua_isnil(L, -1)) {
                warnInvalidValue("font_rendering.text.linear_correction", "true");
                text_linear_correction = text_linear_correction_default;
            }
            c.lua_pop(L, 1);
        }
        c.lua_pop(L, 1);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, -1, "theme");
    if (c.lua_istable(L, -1)) {
        theme = try parseThemeFromTable(L, -1);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, -1, "keybinds");
    if (c.lua_istable(L, -1)) {
        _ = c.lua_getfield(L, -1, "no_defaults");
        if (c.lua_isboolean(L, -1)) {
            keybinds_no_defaults = c.lua_toboolean(L, -1) != 0;
        }
        c.lua_pop(L, 1);
        keybinds = try parseKeybinds(allocator, L, -1);
    }
    c.lua_pop(L, 1);

    return .{
        .log_file_filter = log_file_filter,
        .log_console_filter = log_console_filter,
        .sdl_log_level = sdl_log_level,
        .editor_wrap = editor_wrap,
        .editor_highlight_budget = editor_highlight_budget,
        .editor_width_budget = editor_width_budget,
        .app_font_path = app_font_path,
        .app_font_size = app_font_size,
        .editor_font_path = editor_font_path,
        .editor_font_size = editor_font_size,
        .editor_font_features = editor_font_features,
        .editor_disable_ligatures = editor_disable_ligatures,
        .terminal_font_path = terminal_font_path,
        .terminal_font_size = terminal_font_size,
        .terminal_blink_style = terminal_blink_style,
        .terminal_disable_ligatures = terminal_disable_ligatures,
        .terminal_font_features = terminal_font_features,
        .terminal_scrollback_rows = terminal_scrollback_rows,
        .terminal_cursor_shape = terminal_cursor_shape,
        .terminal_cursor_blink = terminal_cursor_blink,
        .terminal_focus_report_window = terminal_focus_report_window,
        .terminal_focus_report_pane = terminal_focus_report_pane,
        .font_lcd = font_lcd,
        .font_hinting = font_hinting,
        .font_autohint = font_autohint,
        .font_glyph_overflow = font_glyph_overflow,
        .text_gamma = text_gamma,
        .text_contrast = text_contrast,
        .text_linear_correction = text_linear_correction,
        .theme = theme,
        .app_theme = app_theme,
        .editor_theme = editor_theme,
        .terminal_theme = terminal_theme,
        .keybinds_no_defaults = keybinds_no_defaults,
        .keybinds = keybinds,
    };
}

fn sameBindingIdentity(a: input_actions.BindSpec, b: input_actions.BindSpec) bool {
    return a.scope == b.scope and
        a.key == b.key and
        a.mods.shift == b.mods.shift and
        a.mods.alt == b.mods.alt and
        a.mods.ctrl == b.mods.ctrl and
        a.mods.super == b.mods.super and
        a.mods.altgr == b.mods.altgr;
}

fn mergeKeybinds(
    allocator: std.mem.Allocator,
    base: []const input_actions.BindSpec,
    overlay: []const input_actions.BindSpec,
) ![]input_actions.BindSpec {
    var merged = std.ArrayList(input_actions.BindSpec).empty;
    errdefer merged.deinit(allocator);
    try merged.appendSlice(allocator, base);

    for (overlay) |binding| {
        var replaced = false;
        for (merged.items, 0..) |existing, idx| {
            if (!sameBindingIdentity(existing, binding)) continue;
            merged.items[idx] = binding;
            replaced = true;
            break;
        }
        if (!replaced) {
            try merged.append(allocator, binding);
        }
    }

    return merged.toOwnedSlice(allocator);
}

fn parseFontHinting(L: *c.lua_State, idx: c_int) ?FontHinting {
    const value = luaStringToSlice(L, idx);
    if (value.len == 0) return null;
    if (std.mem.eql(u8, value, "default")) return .default;
    if (std.mem.eql(u8, value, "none")) return .none;
    if (std.mem.eql(u8, value, "light")) return .light;
    if (std.mem.eql(u8, value, "normal")) return .normal;
    return null;
}

fn parseGlyphOverflowPolicy(L: *c.lua_State, idx: c_int) ?GlyphOverflowPolicy {
    const value = luaStringToSlice(L, idx);
    if (value.len == 0) return null;
    if (std.mem.eql(u8, value, "when_followed_by_space")) return .when_followed_by_space;
    if (std.mem.eql(u8, value, "never")) return .never;
    if (std.mem.eql(u8, value, "always")) return .always;
    return null;
}

fn parseTerminalBlink(L: *c.lua_State, idx: c_int) ?TerminalBlinkStyle {
    const value = luaStringToSlice(L, idx);
    if (value.len == 0) return null;
    if (std.mem.eql(u8, value, "kitty")) return .kitty;
    if (std.mem.eql(u8, value, "off")) return .off;
    if (std.mem.eql(u8, value, "ghostty")) return .off;
    return null;
}

fn parseTerminalDisableLigatures(L: *c.lua_State, idx: c_int) ?TerminalDisableLigaturesStrategy {
    const value = luaStringToSlice(L, idx);
    if (value.len == 0) return null;
    if (std.mem.eql(u8, value, "never")) return .never;
    if (std.mem.eql(u8, value, "cursor")) return .cursor;
    if (std.mem.eql(u8, value, "always")) return .always;
    return null;
}

fn parseCursorShape(L: *c.lua_State, idx: c_int) ?term_types.CursorShape {
    const value = luaStringToSlice(L, idx);
    if (value.len == 0) return null;
    if (std.mem.eql(u8, value, "block")) return .block;
    if (std.mem.eql(u8, value, "underline")) return .underline;
    if (std.mem.eql(u8, value, "bar")) return .bar;
    return null;
}

fn parseFontTable(
    allocator: std.mem.Allocator,
    L: *c.lua_State,
    idx: c_int,
    path_out: *?[]u8,
    size_out: *?f32,
) void {
    _ = c.lua_getfield(L, idx, "path");
    if (c.lua_isstring(L, -1) != 0) {
        path_out.* = luaStringToOwned(allocator, L, -1) catch path_out.*;
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, idx, "size");
    if (c.lua_isnumber(L, -1) != 0) {
        const value = c.lua_tonumberx(L, -1, null);
        if (value > 0) {
            size_out.* = @floatCast(value);
        }
    }
    c.lua_pop(L, 1);
}

fn parseKeybinds(allocator: std.mem.Allocator, L: *c.lua_State, idx: c_int) LuaConfigError![]input_actions.BindSpec {
    var out = std.ArrayList(input_actions.BindSpec).empty;
    errdefer out.deinit(allocator);

    try parseKeybindScope(allocator, L, idx, "global", .global, &out);
    try parseKeybindScope(allocator, L, idx, "editor", .editor, &out);
    try parseKeybindScope(allocator, L, idx, "terminal", .terminal, &out);

    return out.toOwnedSlice(allocator);
}

fn parseKeybindScope(
    allocator: std.mem.Allocator,
    L: *c.lua_State,
    idx: c_int,
    field: [:0]const u8,
    scope: input_actions.BindScope,
    out: *std.ArrayList(input_actions.BindSpec),
) LuaConfigError!void {
    const log = app_logger.logger("config.keybinds");
    _ = c.lua_getfield(L, idx, field);
    defer c.lua_pop(L, 1);
    if (!c.lua_istable(L, -1)) return;
    const len = c.lua_rawlen(L, -1);
    var i: c_int = 1;
    while (i <= @as(c_int, @intCast(len))) : (i += 1) {
        _ = c.lua_rawgeti(L, -1, i);
        defer c.lua_pop(L, 1);
        if (!c.lua_istable(L, -1)) continue;

        const key = parseKeyField(L, -1) orelse {
            if (log.enabled_file or log.enabled_console) {
                log.logf("skip keybind scope={s} index={d} reason=invalid_key", .{ field, i });
            }
            continue;
        };
        const mods = parseModsField(L, -1);
        const action = parseActionField(L, -1) orelse {
            if (log.enabled_file or log.enabled_console) {
                log.logf("skip keybind scope={s} index={d} reason=invalid_action", .{ field, i });
            }
            continue;
        };
        const repeat = parseRepeatField(L, -1);

        try out.append(allocator, .{
            .scope = scope,
            .key = key,
            .mods = mods,
            .action = action,
            .repeat = repeat,
        });
    }
}

fn parseKeyField(L: *c.lua_State, idx: c_int) ?input_types.Key {
    _ = c.lua_getfield(L, idx, "key");
    defer c.lua_pop(L, 1);
    if (c.lua_isstring(L, -1) == 0) return null;
    var len: usize = 0;
    const ptr = c.lua_tolstring(L, -1, &len) orelse return null;
    const slice = @as([*]const u8, @ptrCast(ptr))[0..len];
    return std.meta.stringToEnum(input_types.Key, slice);
}

fn parseModsField(L: *c.lua_State, idx: c_int) input_types.Modifiers {
    var mods: input_types.Modifiers = .{};
    _ = c.lua_getfield(L, idx, "mods");
    defer c.lua_pop(L, 1);
    if (c.lua_isstring(L, -1) != 0) {
        if (readModString(L, -1)) |mod_flag| applyMod(&mods, mod_flag);
        return mods;
    }
    if (!c.lua_istable(L, -1)) return mods;
    const len = c.lua_rawlen(L, -1);
    var i: c_int = 1;
    while (i <= @as(c_int, @intCast(len))) : (i += 1) {
        _ = c.lua_rawgeti(L, -1, i);
        if (c.lua_isstring(L, -1) != 0) {
            if (readModString(L, -1)) |mod_flag| applyMod(&mods, mod_flag);
        }
        c.lua_pop(L, 1);
    }
    return mods;
}

fn parseActionField(L: *c.lua_State, idx: c_int) ?input_actions.ActionKind {
    _ = c.lua_getfield(L, idx, "action");
    defer c.lua_pop(L, 1);
    if (c.lua_isstring(L, -1) == 0) return null;
    var len: usize = 0;
    const ptr = c.lua_tolstring(L, -1, &len) orelse return null;
    const slice = @as([*]const u8, @ptrCast(ptr))[0..len];
    return std.meta.stringToEnum(input_actions.ActionKind, slice);
}

fn parseRepeatField(L: *c.lua_State, idx: c_int) bool {
    _ = c.lua_getfield(L, idx, "repeat");
    defer c.lua_pop(L, 1);
    if (!c.lua_isboolean(L, -1)) return false;
    return c.lua_toboolean(L, -1) != 0;
}

const ModFlag = enum { ctrl, shift, alt, super, altgr };

fn readModString(L: *c.lua_State, idx: c_int) ?ModFlag {
    var len: usize = 0;
    const ptr = c.lua_tolstring(L, idx, &len) orelse return null;
    const slice = @as([*]const u8, @ptrCast(ptr))[0..len];
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

fn warnInvalidValue(path: []const u8, fallback: []const u8) void {
    std.debug.print("config warning: {s} invalid, using {s}\n", .{ path, fallback });
}

fn parseConfigFromSnippet(allocator: std.mem.Allocator, source: []const u8) !Config {
    const L = c.luaL_newstate() orelse return LuaConfigError.LuaInitFailed;
    defer c.lua_close(L);
    c.luaL_openlibs(L);

    if (c.luaL_loadbufferx(L, source.ptr, source.len, "config_test", null) != 0) {
        return LuaConfigError.LuaLoadFailed;
    }
    if (c.lua_pcallk(L, 0, 1, 0, 0, null) != 0) {
        return LuaConfigError.LuaRunFailed;
    }

    return parseConfigFromStack(allocator, L);
}

test "mergeKeybinds fills gaps and preserves unmatched defaults" {
    const allocator = std.testing.allocator;
    const defaults = [_]input_actions.BindSpec{
        .{
            .scope = .editor,
            .key = .c,
            .mods = .{ .ctrl = true },
            .action = .copy,
            .repeat = false,
        },
        .{
            .scope = .editor,
            .key = .up,
            .mods = .{ .shift = true, .alt = true },
            .action = .editor_add_caret_up,
            .repeat = false,
        },
    };
    const overlay = [_]input_actions.BindSpec{
        .{
            .scope = .editor,
            .key = .v,
            .mods = .{ .ctrl = true },
            .action = .paste,
            .repeat = false,
        },
    };

    const merged = try mergeKeybinds(allocator, &defaults, &overlay);
    defer allocator.free(merged);

    try std.testing.expectEqual(@as(usize, 3), merged.len);
    try std.testing.expectEqual(input_actions.ActionKind.copy, merged[0].action);
    try std.testing.expectEqual(input_actions.ActionKind.editor_add_caret_up, merged[1].action);
    try std.testing.expectEqual(input_actions.ActionKind.paste, merged[2].action);
}

test "mergeKeybinds overrides by scope key and exact mods" {
    const allocator = std.testing.allocator;
    const defaults = [_]input_actions.BindSpec{
        .{
            .scope = .editor,
            .key = .c,
            .mods = .{ .ctrl = true },
            .action = .copy,
            .repeat = false,
        },
    };
    const overlay = [_]input_actions.BindSpec{
        .{
            .scope = .editor,
            .key = .c,
            .mods = .{ .ctrl = true },
            .action = .cut,
            .repeat = false,
        },
    };

    const merged = try mergeKeybinds(allocator, &defaults, &overlay);
    defer allocator.free(merged);

    try std.testing.expectEqual(@as(usize, 1), merged.len);
    try std.testing.expectEqual(input_actions.ActionKind.cut, merged[0].action);
}

test "mergeKeybinds treats altgr as part of binding identity" {
    const allocator = std.testing.allocator;
    const defaults = [_]input_actions.BindSpec{
        .{
            .scope = .editor,
            .key = .e,
            .mods = .{ .ctrl = true, .alt = true, .altgr = true },
            .action = .copy,
            .repeat = false,
        },
    };
    const overlay = [_]input_actions.BindSpec{
        .{
            .scope = .editor,
            .key = .e,
            .mods = .{ .ctrl = true, .alt = true, .altgr = false },
            .action = .cut,
            .repeat = false,
        },
    };

    const merged = try mergeKeybinds(allocator, &defaults, &overlay);
    defer allocator.free(merged);

    try std.testing.expectEqual(@as(usize, 2), merged.len);
    try std.testing.expectEqual(input_actions.ActionKind.copy, merged[0].action);
    try std.testing.expectEqual(input_actions.ActionKind.cut, merged[1].action);
}

test "parseConfigFromSnippet warns-and-defaults invalid font rendering values" {
    const allocator = std.testing.allocator;
    var config = try parseConfigFromSnippet(allocator,
        \\return {
        \\  font_rendering = {
        \\    lcd = "bad",
        \\    hinting = "weird",
        \\    autohint = "bad",
        \\    glyph_overflow = "bad",
        \\    text = {
        \\      gamma = -1,
        \\      contrast = 0,
        \\      linear_correction = "bad",
        \\    },
        \\  },
        \\}
    );
    defer freeConfig(allocator, &config);

    try std.testing.expectEqual(false, config.font_lcd.?);
    try std.testing.expectEqual(FontHinting.default, config.font_hinting.?);
    try std.testing.expectEqual(false, config.font_autohint.?);
    try std.testing.expectEqual(GlyphOverflowPolicy.when_followed_by_space, config.font_glyph_overflow.?);
    try std.testing.expectEqual(@as(f32, 1.0), config.text_gamma.?);
    try std.testing.expectEqual(@as(f32, 1.0), config.text_contrast.?);
    try std.testing.expectEqual(true, config.text_linear_correction.?);
}

test "parseConfigFromSnippet parses altgr keybind modifiers" {
    const allocator = std.testing.allocator;
    var config = try parseConfigFromSnippet(allocator,
        \\return {
        \\  keybinds = {
        \\    editor = {
        \\      { key = "e", mods = { "ctrl", "alt", "altgr" }, action = "copy" },
        \\    },
        \\  },
        \\}
    );
    defer freeConfig(allocator, &config);

    try std.testing.expect(config.keybinds != null);
    try std.testing.expectEqual(@as(usize, 1), config.keybinds.?.len);
    try std.testing.expect(config.keybinds.?[0].mods.ctrl);
    try std.testing.expect(config.keybinds.?[0].mods.alt);
    try std.testing.expect(config.keybinds.?[0].mods.altgr);
}

test "parseConfigFromSnippet defaults invalid focus reporting and budgets" {
    const allocator = std.testing.allocator;
    var config = try parseConfigFromSnippet(allocator,
        \\return {
        \\  editor = {
        \\    render = {
        \\      highlight_budget = -10,
        \\      width_budget = "bad",
        \\    },
        \\  },
        \\  terminal = {
        \\    focus_reporting = {
        \\      window = "bad",
        \\      pane = "bad",
        \\    },
        \\  },
        \\}
    );
    defer freeConfig(allocator, &config);

    try std.testing.expectEqual(@as(usize, 0), config.editor_highlight_budget.?);
    try std.testing.expectEqual(@as(usize, 0), config.editor_width_budget.?);
    try std.testing.expectEqual(true, config.terminal_focus_report_window.?);
    try std.testing.expectEqual(false, config.terminal_focus_report_pane.?);
}

fn findUserConfigPath(allocator: std.mem.Allocator) LuaConfigError!?[]u8 {
    const builtin = @import("builtin");
    switch (builtin.os.tag) {
        .windows => {
            const appdata = std.c.getenv("APPDATA") orelse return null;
            const base = std.mem.sliceTo(appdata, 0);
            const path = try std.fs.path.join(allocator, &.{ base, "Zide", "init.lua" });
            if (!fileExists(path)) {
                allocator.free(path);
                return null;
            }
            return path;
        },
        .macos => {
            const home = std.c.getenv("HOME") orelse return null;
            const base = std.mem.sliceTo(home, 0);
            const path = try std.fs.path.join(allocator, &.{ base, "Library", "Application Support", "Zide", "init.lua" });
            if (!fileExists(path)) {
                allocator.free(path);
                return null;
            }
            return path;
        },
        else => {
            const xdg = std.c.getenv("XDG_CONFIG_HOME");
            const home = std.c.getenv("HOME");
            if (xdg == null and home == null) return null;

            const base = if (xdg) |val| std.mem.sliceTo(val, 0) else blk: {
                const home_slice = std.mem.sliceTo(home.?, 0);
                break :blk try std.fs.path.join(allocator, &.{ home_slice, ".config" });
            };
            defer if (xdg == null and home != null) allocator.free(base);

            const path = try std.fs.path.join(allocator, &.{ base, "zide", "init.lua" });
            if (!fileExists(path)) {
                allocator.free(path);
                return null;
            }
            return path;
        },
    }
}

fn fileExists(path: []const u8) bool {
    if (std.fs.cwd().openFile(path, .{})) |file| {
        file.close();
        return true;
    } else |_| {
        return false;
    }
}

fn luaStringToOwned(allocator: std.mem.Allocator, L: *c.lua_State, idx: c_int) LuaConfigError![]u8 {
    var len: usize = 0;
    const ptr = c.lua_tolstring(L, idx, &len) orelse return LuaConfigError.InvalidConfig;
    const slice = @as([*]const u8, @ptrCast(ptr))[0..len];
    return allocator.dupe(u8, slice);
}

fn luaStringToSlice(L: *c.lua_State, idx: c_int) []const u8 {
    var len: usize = 0;
    const ptr = c.lua_tolstring(L, idx, &len) orelse return "";
    return @as([*]const u8, @ptrCast(ptr))[0..len];
}

fn luaStringListToOwned(allocator: std.mem.Allocator, L: *c.lua_State, idx: c_int) LuaConfigError![]u8 {
    const len = c.lua_rawlen(L, idx);
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var i: c_int = 1;
    while (i <= @as(c_int, @intCast(len))) : (i += 1) {
        _ = c.lua_rawgeti(L, idx, i);
        if (c.lua_isstring(L, -1) != 0) {
            var s_len: usize = 0;
            const s_ptr = c.lua_tolstring(L, -1, &s_len) orelse {
                c.lua_pop(L, 1);
                continue;
            };
            const s_slice = @as([*]const u8, @ptrCast(s_ptr))[0..s_len];
            if (out.items.len > 0) {
                try out.append(allocator, ',');
            }
            try out.appendSlice(allocator, s_slice);
        }
        c.lua_pop(L, 1);
    }

    return out.toOwnedSlice(allocator);
}

fn parseLogFiltersFromTable(
    allocator: std.mem.Allocator,
    L: *c.lua_State,
    idx: c_int,
    file_out: *?[]u8,
    console_out: *?[]u8,
) LuaConfigError!void {
    _ = c.lua_getfield(L, idx, "file");
    if (c.lua_isstring(L, -1) != 0) {
        file_out.* = try luaStringToOwned(allocator, L, -1);
    } else if (c.lua_istable(L, -1)) {
        file_out.* = try luaStringListToOwned(allocator, L, -1);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, idx, "console");
    if (c.lua_isstring(L, -1) != 0) {
        console_out.* = try luaStringToOwned(allocator, L, -1);
    } else if (c.lua_istable(L, -1)) {
        console_out.* = try luaStringListToOwned(allocator, L, -1);
    }
    c.lua_pop(L, 1);

    if (file_out.* == null or console_out.* == null) {
        _ = c.lua_getfield(L, idx, "enable");
        if (c.lua_isstring(L, -1) != 0) {
            const value = try luaStringToOwned(allocator, L, -1);
            if (file_out.* == null) file_out.* = value else allocator.free(value);
            if (console_out.* == null) console_out.* = try allocator.dupe(u8, value);
        } else if (c.lua_istable(L, -1)) {
            const value = try luaStringListToOwned(allocator, L, -1);
            if (file_out.* == null) file_out.* = value else allocator.free(value);
            if (console_out.* == null) console_out.* = try allocator.dupe(u8, value);
        }
        c.lua_pop(L, 1);
    }
}

fn parseSdlLogLevel(L: *c.lua_State, idx: c_int) ?c_int {
    var len: usize = 0;
    const ptr = c.lua_tolstring(L, idx, &len) orelse return null;
    const value = @as([*]const u8, @ptrCast(ptr))[0..len];
    if (std.mem.eql(u8, value, "none")) return sdl.SDL_LOG_PRIORITY_CRITICAL;
    if (std.mem.eql(u8, value, "critical")) return sdl.SDL_LOG_PRIORITY_CRITICAL;
    if (std.mem.eql(u8, value, "error")) return sdl.SDL_LOG_PRIORITY_ERROR;
    if (std.mem.eql(u8, value, "warning")) return sdl.SDL_LOG_PRIORITY_WARN;
    if (std.mem.eql(u8, value, "warn")) return sdl.SDL_LOG_PRIORITY_WARN;
    if (std.mem.eql(u8, value, "info")) return sdl.SDL_LOG_PRIORITY_INFO;
    if (std.mem.eql(u8, value, "debug")) return sdl.SDL_LOG_PRIORITY_DEBUG;
    if (std.mem.eql(u8, value, "trace")) return sdl.SDL_LOG_PRIORITY_VERBOSE;
    return null;
}

fn mergeThemeConfig(base: *ThemeConfig, overlay: ThemeConfig) void {
    if (overlay.background) |color| base.background = color;
    if (overlay.foreground) |color| base.foreground = color;
    if (overlay.selection) |color| base.selection = color;
    if (overlay.cursor) |color| base.cursor = color;
    if (overlay.link) |color| base.link = color;
    if (overlay.line_number) |color| base.line_number = color;
    if (overlay.line_number_bg) |color| base.line_number_bg = color;
    if (overlay.current_line) |color| base.current_line = color;
    if (overlay.ui_bar_bg) |color| base.ui_bar_bg = color;
    if (overlay.ui_panel_bg) |color| base.ui_panel_bg = color;
    if (overlay.ui_panel_overlay) |color| base.ui_panel_overlay = color;
    if (overlay.ui_hover) |color| base.ui_hover = color;
    if (overlay.ui_pressed) |color| base.ui_pressed = color;
    if (overlay.ui_tab_inactive_bg) |color| base.ui_tab_inactive_bg = color;
    if (overlay.ui_accent) |color| base.ui_accent = color;
    if (overlay.ui_border) |color| base.ui_border = color;
    if (overlay.ui_modified) |color| base.ui_modified = color;
    if (overlay.ui_text) |color| base.ui_text = color;
    if (overlay.ui_text_inactive) |color| base.ui_text_inactive = color;
    if (overlay.comment_color) |color| base.comment_color = color;
    if (overlay.string) |color| base.string = color;
    if (overlay.keyword) |color| base.keyword = color;
    if (overlay.number) |color| base.number = color;
    if (overlay.function) |color| base.function = color;
    if (overlay.variable) |color| base.variable = color;
    if (overlay.type_name) |color| base.type_name = color;
    if (overlay.operator) |color| base.operator = color;
    if (overlay.builtin_color) |color| base.builtin_color = color;
    if (overlay.punctuation) |color| base.punctuation = color;
    if (overlay.constant) |color| base.constant = color;
    if (overlay.attribute) |color| base.attribute = color;
    if (overlay.namespace) |color| base.namespace = color;
    if (overlay.label) |color| base.label = color;
    if (overlay.error_token) |color| base.error_token = color;
    for (0..16) |i| {
        if (overlay.ansi_colors[i]) |color| base.ansi_colors[i] = color;
    }
}

pub fn applyThemeConfig(theme: *Theme, overlay: ThemeConfig) void {
    if (overlay.background) |color| theme.background = color;
    if (overlay.foreground) |color| theme.foreground = color;
    if (overlay.selection) |color| theme.selection = color;
    if (overlay.cursor) |color| theme.cursor = color;
    if (overlay.link) |color| theme.link = color;
    if (overlay.line_number) |color| theme.line_number = color;
    if (overlay.line_number_bg) |color| theme.line_number_bg = color;
    if (overlay.current_line) |color| theme.current_line = color;
    if (overlay.ui_bar_bg) |color| theme.ui_bar_bg = color;
    if (overlay.ui_panel_bg) |color| theme.ui_panel_bg = color;
    if (overlay.ui_panel_overlay) |color| theme.ui_panel_overlay = color;
    if (overlay.ui_hover) |color| theme.ui_hover = color;
    if (overlay.ui_pressed) |color| theme.ui_pressed = color;
    if (overlay.ui_tab_inactive_bg) |color| theme.ui_tab_inactive_bg = color;
    if (overlay.ui_accent) |color| theme.ui_accent = color;
    if (overlay.ui_border) |color| theme.ui_border = color;
    if (overlay.ui_modified) |color| theme.ui_modified = color;
    if (overlay.ui_text) |color| theme.ui_text = color;
    if (overlay.ui_text_inactive) |color| theme.ui_text_inactive = color;
    if (overlay.comment_color) |color| theme.comment_color = color;
    if (overlay.string) |color| theme.string = color;
    if (overlay.keyword) |color| theme.keyword = color;
    if (overlay.number) |color| theme.number = color;
    if (overlay.function) |color| theme.function = color;
    if (overlay.variable) |color| theme.variable = color;
    if (overlay.type_name) |color| theme.type_name = color;
    if (overlay.operator) |color| theme.operator = color;
    if (overlay.builtin_color) |color| theme.builtin_color = color;
    if (overlay.punctuation) |color| theme.punctuation = color;
    if (overlay.constant) |color| theme.constant = color;
    if (overlay.attribute) |color| theme.attribute = color;
    if (overlay.namespace) |color| theme.namespace = color;
    if (overlay.label) |color| theme.label = color;
    if (overlay.error_token) |color| theme.error_token = color;
    if (theme.ansi_colors) |*colors| {
        for (0..16) |i| {
            if (overlay.ansi_colors[i]) |color| colors[i] = color;
        }
    } else {
        var has_any = false;
        for (0..16) |i| {
            if (overlay.ansi_colors[i] != null) has_any = true;
        }
        if (has_any) {
            var colors = [_]Color{.{ .r = 0, .g = 0, .b = 0 }} ** 16;
            for (0..16) |i| {
                if (overlay.ansi_colors[i]) |color| colors[i] = color;
            }
            theme.ansi_colors = colors;
        }
    }
}

fn parseThemeFromTable(L: *c.lua_State, idx: c_int) LuaConfigError!ThemeConfig {
    var theme: ThemeConfig = .{};
    parseThemePaletteTable(L, idx, &theme);
    parseThemeSyntaxTable(L, idx, &theme);

    _ = c.lua_getfield(L, idx, "palette");
    if (c.lua_istable(L, -1)) {
        parseThemePaletteTable(L, -1, &theme);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, idx, "syntax");
    if (c.lua_istable(L, -1)) {
        parseThemeSyntaxTable(L, -1, &theme);
    }
    c.lua_pop(L, 1);

    return theme;
}

fn parseThemePaletteTable(L: *c.lua_State, idx: c_int, theme: *ThemeConfig) void {
    parseColorField(L, idx, "background", &theme.background);
    parseColorField(L, idx, "foreground", &theme.foreground);
    parseColorField(L, idx, "selection", &theme.selection);
    parseColorField(L, idx, "cursor", &theme.cursor);
    parseColorField(L, idx, "link", &theme.link);
    parseColorField(L, idx, "line_number", &theme.line_number);
    parseColorField(L, idx, "line_number_bg", &theme.line_number_bg);
    parseColorField(L, idx, "current_line", &theme.current_line);
    parseColorField(L, idx, "ui_bar_bg", &theme.ui_bar_bg);
    parseColorField(L, idx, "ui_panel_bg", &theme.ui_panel_bg);
    parseColorField(L, idx, "ui_panel_overlay", &theme.ui_panel_overlay);
    parseColorField(L, idx, "ui_hover", &theme.ui_hover);
    parseColorField(L, idx, "ui_pressed", &theme.ui_pressed);
    parseColorField(L, idx, "ui_tab_inactive_bg", &theme.ui_tab_inactive_bg);
    parseColorField(L, idx, "ui_accent", &theme.ui_accent);
    parseColorField(L, idx, "ui_border", &theme.ui_border);
    parseColorField(L, idx, "ui_modified", &theme.ui_modified);
    parseColorField(L, idx, "ui_text", &theme.ui_text);
    parseColorField(L, idx, "ui_text_inactive", &theme.ui_text_inactive);

    inline for (0..16) |i| {
        const key = std.fmt.comptimePrint("color{d}", .{i});
        parseColorField(L, idx, key, &theme.ansi_colors[i]);
    }
}

fn parseThemeSyntaxTable(L: *c.lua_State, idx: c_int, theme: *ThemeConfig) void {
    parseColorField(L, idx, "comment", &theme.comment_color);
    parseColorField(L, idx, "comment_color", &theme.comment_color);
    parseColorField(L, idx, "string", &theme.string);
    parseColorField(L, idx, "keyword", &theme.keyword);
    parseColorField(L, idx, "number", &theme.number);
    parseColorField(L, idx, "function", &theme.function);
    parseColorField(L, idx, "variable", &theme.variable);
    parseColorField(L, idx, "type_name", &theme.type_name);
    parseColorField(L, idx, "operator", &theme.operator);
    parseColorField(L, idx, "builtin", &theme.builtin_color);
    parseColorField(L, idx, "builtin_color", &theme.builtin_color);
    parseColorField(L, idx, "punctuation", &theme.punctuation);
    parseColorField(L, idx, "constant", &theme.constant);
    parseColorField(L, idx, "attribute", &theme.attribute);
    parseColorField(L, idx, "namespace", &theme.namespace);
    parseColorField(L, idx, "label", &theme.label);
    parseColorField(L, idx, "error", &theme.error_token);
    parseColorField(L, idx, "error_token", &theme.error_token);
}

fn parseColorField(L: *c.lua_State, idx: c_int, field: [:0]const u8, out: *?Color) void {
    _ = c.lua_getfield(L, idx, field.ptr);
    const color = parseColorFromValue(L, -1);
    if (color != null) {
        out.* = color.?;
    }
    c.lua_pop(L, 1);
}

fn parseColorFromValue(L: *c.lua_State, idx: c_int) ?Color {
    if (c.lua_isstring(L, idx) != 0) {
        var len: usize = 0;
        const ptr = c.lua_tolstring(L, idx, &len) orelse return null;
        const value = @as([*]const u8, @ptrCast(ptr))[0..len];
        return parseHexColor(value);
    }
    if (c.lua_istable(L, idx)) {
        var r: ?u8 = null;
        var g: ?u8 = null;
        var b: ?u8 = null;
        var a: ?u8 = null;

        _ = c.lua_getfield(L, idx, "r");
        if (c.lua_isnumber(L, -1) != 0) {
            r = parseColorChannel(L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, idx, "g");
        if (c.lua_isnumber(L, -1) != 0) {
            g = parseColorChannel(L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, idx, "b");
        if (c.lua_isnumber(L, -1) != 0) {
            b = parseColorChannel(L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, idx, "a");
        if (c.lua_isnumber(L, -1) != 0) {
            a = parseColorChannel(L, -1);
        }
        c.lua_pop(L, 1);

        if (r != null and g != null and b != null) {
            return Color{ .r = r.?, .g = g.?, .b = b.?, .a = a orelse 255 };
        }
    }
    return null;
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

fn parseHexByte(slice: []const u8) ?u8 {
    return std.fmt.parseInt(u8, slice, 16) catch null;
}

fn parseColorChannel(L: *c.lua_State, idx: c_int) ?u8 {
    var is_num: c_int = 0;
    const value = c.lua_tointegerx(L, idx, &is_num);
    if (is_num == 0) return null;
    if (value < 0 or value > 255) return null;
    return @intCast(value);
}
