const std = @import("std");
const app_theme_utils = @import("theme_utils.zig");
const app_shell = @import("../app_shell.zig");
const term_types = @import("../terminal/model/types.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");
const widgets = @import("../ui/widgets.zig");

const TerminalSession = terminal_mod.TerminalSession;
const TerminalWidget = widgets.TerminalWidget;

pub fn setSessionPalette(term: *TerminalSession, theme: *const app_shell.Theme) void {
    term.setDefaultColors(
        term_types.Color{
            .r = theme.foreground.r,
            .g = theme.foreground.g,
            .b = theme.foreground.b,
        },
        term_types.Color{
            .r = theme.background.r,
            .g = theme.background.g,
            .b = theme.background.b,
        },
    );
    if (theme.ansi_colors) |ansi| {
        var colors: [16]term_types.Color = undefined;
        for (ansi, 0..) |c, i| {
            colors[i] = term_types.Color{ .r = c.r, .g = c.g, .b = c.b };
        }
        term.setAnsiColors(colors);
    }
}

pub fn notifyColorSchemeChanged(
    terminal_widgets: *std.ArrayList(TerminalWidget),
    theme: *const app_shell.Theme,
) !void {
    const dark = app_theme_utils.isDarkTheme(theme);
    for (terminal_widgets.items) |*widget| {
        _ = try widget.session.reportColorSchemeChanged(dark);
    }
}

pub fn applyThemeToWidgets(
    terminal_widgets: *std.ArrayList(TerminalWidget),
    theme: *const app_shell.Theme,
) void {
    for (terminal_widgets.items) |*widget| {
        const term = widget.session;
        var old_ansi: [16]term_types.Color = undefined;
        for (0..16) |i| {
            old_ansi[i] = term.paletteColor(@intCast(i));
        }
        setSessionPalette(term, theme);
        if (theme.ansi_colors) |ansi| {
            var new_ansi: [16]term_types.Color = undefined;
            for (ansi, 0..) |c, i| {
                new_ansi[i] = term_types.Color{ .r = c.r, .g = c.g, .b = c.b };
            }
            term.remapAnsiColors(old_ansi, new_ansi);
        }
    }
}
