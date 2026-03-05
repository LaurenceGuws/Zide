const std = @import("std");
const iface = @import("./lua_config_iface.zig");

pub const Config = iface.Config;
pub const Theme = iface.Theme;
pub const ThemeConfig = iface.ThemeConfig;

pub fn emptyConfig() Config {
    return .{
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
    if (overlay.preproc) |color| theme.preproc = color;
    if (overlay.macro) |color| theme.macro = color;
    if (overlay.escape) |color| theme.escape = color;
    if (overlay.keyword_control) |color| theme.keyword_control = color;
    if (overlay.function_method) |color| theme.function_method = color;
    if (overlay.type_builtin) |color| theme.type_builtin = color;
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
            var colors = [_]iface.Color{.{ .r = 0, .g = 0, .b = 0 }} ** 16;
            for (0..16) |i| {
                if (overlay.ansi_colors[i]) |color| colors[i] = color;
            }
            theme.ansi_colors = colors;
        }
    }
}
