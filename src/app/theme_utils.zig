const std = @import("std");
const app_shell = @import("../app_shell.zig");
const config_mod = @import("../config/lua_config.zig");

const min_active_tab_text_contrast: f64 = 7.0;

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
    theme.ui_text = ensureContrast(theme.ui_text, theme.background, min_active_tab_text_contrast);
    return theme;
}

fn ensureContrast(text: app_shell.Color, bg: app_shell.Color, min_ratio: f64) app_shell.Color {
    if (contrastRatio(text, bg) >= min_ratio) return text;
    return highContrastTextCandidate(bg, text.a);
}

fn highContrastTextCandidate(bg: app_shell.Color, alpha: u8) app_shell.Color {
    const black = app_shell.Color{ .r = 0, .g = 0, .b = 0, .a = alpha };
    const white = app_shell.Color{ .r = 255, .g = 255, .b = 255, .a = alpha };
    if (contrastRatio(black, bg) >= contrastRatio(white, bg)) return black;
    return white;
}

fn contrastRatio(a: app_shell.Color, b: app_shell.Color) f64 {
    const la = relativeLuminance(a);
    const lb = relativeLuminance(b);
    const lighter = @max(la, lb);
    const darker = @min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
}

fn relativeLuminance(color: app_shell.Color) f64 {
    const r = srgbChannelToLinear(color.r);
    const g = srgbChannelToLinear(color.g);
    const b = srgbChannelToLinear(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

fn srgbChannelToLinear(channel: u8) f64 {
    const c = @as(f64, @floatFromInt(channel)) / 255.0;
    if (c <= 0.04045) return c / 12.92;
    return std.math.pow(f64, (c + 0.055) / 1.055, 2.4);
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

test "terminal tab bar theme enforces stronger active tab text contrast" {
    const base = app_shell.Theme{};
    var terminal = app_shell.Theme{};
    terminal.ui_accent = .{ .r = 236, .g = 236, .b = 236 };
    terminal.ui_text = .{ .r = 220, .g = 220, .b = 220 };
    terminal.ui_tab_inactive_bg = .{ .r = 245, .g = 245, .b = 245 };
    terminal.ui_text_inactive = .{ .r = 229, .g = 229, .b = 229 };

    const out = terminalTabBarTheme(terminal, base);

    try std.testing.expectEqual(@as(u8, 0), out.ui_text.r);
    try std.testing.expectEqual(@as(u8, 0), out.ui_text.g);
    try std.testing.expectEqual(@as(u8, 0), out.ui_text.b);
    try std.testing.expect(contrastRatio(out.ui_text, out.background) >= min_active_tab_text_contrast);
    try std.testing.expectEqualDeep(terminal.ui_text_inactive, out.ui_text_inactive);
}

test "terminal tab bar theme preserves explicit tab text when contrast is already sufficient" {
    const base = app_shell.Theme{};
    var terminal = app_shell.Theme{};
    terminal.ui_accent = .{ .r = 24, .g = 28, .b = 38 };
    terminal.ui_text = .{ .r = 214, .g = 222, .b = 235 };
    terminal.ui_tab_inactive_bg = .{ .r = 40, .g = 45, .b = 58 };
    terminal.ui_text_inactive = .{ .r = 188, .g = 196, .b = 211 };

    const out = terminalTabBarTheme(terminal, base);

    try std.testing.expectEqualDeep(terminal.ui_text, out.ui_text);
    try std.testing.expectEqualDeep(terminal.ui_text_inactive, out.ui_text_inactive);
}
