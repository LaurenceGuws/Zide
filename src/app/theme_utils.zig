const std = @import("std");
const app_shell = @import("../app_shell.zig");
const config_mod = @import("../config/lua_config.zig");

pub const ResolvedThemes = struct {
    app: app_shell.Theme,
    editor: app_shell.Theme,
    terminal: app_shell.Theme,
};

pub fn isDarkTheme(theme: *const app_shell.Theme) bool {
    const r = @as(u32, theme.background.r);
    const g = @as(u32, theme.background.g);
    const b = @as(u32, theme.background.b);
    const luma = r * 299 + g * 587 + b * 114;
    return luma < 128000;
}

pub fn terminalTabBarTheme(terminal_theme: app_shell.Theme, shell_base_theme: app_shell.Theme) app_shell.Theme {
    var theme = terminal_theme;
    const base = shell_base_theme;

    var fallback_active_tab_bg = terminal_theme.background;
    var fallback_inactive_tab_bg = terminal_theme.background;
    var fallback_inactive_text = terminal_theme.foreground;
    var fallback_border = terminal_theme.foreground;

    if (terminal_theme.ansi_colors) |ansi| {
        fallback_active_tab_bg = ansi[4];
        fallback_inactive_tab_bg = ansi[8];
        fallback_inactive_text = ansi[7];
        fallback_border = ansi[8];
    }

    if (std.meta.eql(theme.ui_bar_bg, base.ui_bar_bg)) {
        theme.ui_bar_bg = terminal_theme.background;
    }
    if (std.meta.eql(theme.ui_tab_inactive_bg, base.ui_tab_inactive_bg)) {
        theme.ui_tab_inactive_bg = fallback_inactive_tab_bg;
    }
    if (std.meta.eql(theme.ui_text, base.ui_text)) {
        theme.ui_text = terminal_theme.foreground;
    }
    if (std.meta.eql(theme.ui_text_inactive, base.ui_text_inactive)) {
        theme.ui_text_inactive = fallback_inactive_text;
    }
    if (std.meta.eql(theme.ui_border, base.ui_border)) {
        theme.ui_border = fallback_border;
    }

    if (std.meta.eql(theme.ui_accent, base.ui_accent)) {
        theme.ui_accent = fallback_active_tab_bg;
    }

    theme.background = theme.ui_accent;
    return theme;
}

pub fn resolveConfigThemes(shell_base_theme: app_shell.Theme, config: *const config_mod.Config) ResolvedThemes {
    var base_theme = shell_base_theme;
    if (config.theme) |global_theme| {
        config_mod.applyThemeConfig(&base_theme, global_theme);
    }

    var app_theme = base_theme;
    if (config.app_theme) |t| config_mod.applyThemeConfig(&app_theme, t);

    var editor_theme = base_theme;
    if (config.editor_theme) |t| config_mod.applyThemeConfig(&editor_theme, t);

    var terminal_theme = base_theme;
    if (config.terminal_theme) |t| config_mod.applyThemeConfig(&terminal_theme, t);

    return .{
        .app = app_theme,
        .editor = editor_theme,
        .terminal = terminal_theme,
    };
}
