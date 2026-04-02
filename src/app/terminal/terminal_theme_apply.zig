const std = @import("std");
const app_theme_utils = @import("../theme_utils.zig");
const app_shell = @import("../../app_shell.zig");
const session_config = @import("../../terminal/core/session/config.zig");
const session_input = @import("../../terminal/core/session/input.zig");
const term_types = @import("../../terminal/model/types.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");
const widgets = @import("../../ui/widgets.zig");

const PtyTerminalRuntime = terminal_runtime.PtyTerminalRuntime;
const TerminalWidget = widgets.TerminalWidget;

pub fn setSessionPalette(term: *PtyTerminalRuntime, theme: *const app_shell.Theme) void {
    const fg = term_types.Color{
        .r = theme.foreground.r,
        .g = theme.foreground.g,
        .b = theme.foreground.b,
    };
    const bg = term_types.Color{
        .r = theme.background.r,
        .g = theme.background.g,
        .b = theme.background.b,
    };
    const ansi_colors = if (theme.ansi_colors) |ansi| blk: {
        var colors: [16]term_types.Color = undefined;
        for (ansi, 0..) |c, i| {
            colors[i] = term_types.Color{ .r = c.r, .g = c.g, .b = c.b };
        }
        break :blk colors;
    } else null;
    session_config.applyThemePalette(term, fg, bg, ansi_colors);
}

pub fn notifyColorSchemeChanged(
    terminal_widgets: *std.ArrayList(TerminalWidget),
    theme: *const app_shell.Theme,
) !void {
    const dark = app_theme_utils.isDarkTheme(theme);
    for (terminal_widgets.items) |*widget| {
        _ = try session_input.reportColorSchemeChanged(widget.session, dark);
    }
}

pub fn applyThemeToWidgets(
    terminal_widgets: *std.ArrayList(TerminalWidget),
    theme: *const app_shell.Theme,
) void {
    for (terminal_widgets.items) |*widget| {
        setSessionPalette(widget.session, theme);
    }
}
