const app_modes = @import("../modes/mod.zig");
const app_shell = @import("../../app_shell.zig");
const app_terminal_window_chrome_runtime = @import("../terminal/window_chrome_runtime.zig");
const app_theme_utils = @import("../theme_utils.zig");
const widgets_common = @import("../../ui/widgets/common.zig");
const shared_types = @import("../../types/mod.zig");
const std = @import("std");

const layout_types = shared_types.layout;
const Color = app_shell.Color;

pub const Hooks = struct {
    apply_current_tab_bar_width_mode: *const fn (*anyopaque) void,
};

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout, ctx: *anyopaque, hooks: Hooks) ?widgets_common.Tooltip {
    var tab_tooltip: ?widgets_common.Tooltip = null;

    if (app_modes.ide.supportsEditorSurface(state.app_mode)) {
        hooks.apply_current_tab_bar_width_mode(ctx);
        shell.setTheme(state.app_theme);
        if (layout.tab_bar.height > 0) {
            tab_tooltip = state.tab_bar.draw(shell, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
        }
    } else if (app_modes.ide.useTerminalTabBarWidthMode(state.app_mode)) {
        hooks.apply_current_tab_bar_width_mode(ctx);
        const tab_theme = app_theme_utils.terminalTabBarTheme(state.terminal_theme, state.shell_base_theme);
        shell.setTheme(tab_theme);
        if (app_terminal_window_chrome_runtime.barVisible(
            state.app_mode,
            state.terminal_window_chrome_mode,
            state.terminal_tab_bar_show_single_tab,
            state.terminal_workspace,
            state.terminals.items.len,
        )) {
            const chrome = app_terminal_window_chrome_runtime.computeGeometry(
                shell,
                &state.tab_bar,
                layout.tab_bar,
                state.app_mode,
                state.terminal_window_chrome_mode,
            );
            if (chrome.enabled) {
                drawIntegratedBackground(shell, chrome.band, tab_theme.ui_bar_bg);
                tab_tooltip = state.tab_bar.drawWithIconProvider(
                    shell,
                    chrome.band.x,
                    chrome.band.y,
                    chrome.tab_strip_width,
                    state.terminal_shell_icon_cache.iconProvider(),
                );
                drawIntegratedButtons(state, shell, chrome);
            } else {
                tab_tooltip = state.tab_bar.drawWithIconProvider(
                    shell,
                    layout.tab_bar.x,
                    layout.tab_bar.y,
                    layout.tab_bar.width,
                    state.terminal_shell_icon_cache.iconProvider(),
                );
            }
        }
    }

    return tab_tooltip;
}

fn drawIntegratedBackground(shell: anytype, band: layout_types.Rect, color: Color) void {
    shell.drawRect(
        @intFromFloat(band.x),
        @intFromFloat(band.y),
        @intFromFloat(band.width),
        @intFromFloat(band.height),
        color,
    );
}

fn drawIntegratedButtons(state: anytype, shell: anytype, chrome: app_terminal_window_chrome_runtime.Geometry) void {
    const mouse = shell.getMousePos();
    const focused = shell.windowFocused();
    const pressed_button = state.pressed_terminal_window_button;
    const minimize_hovered = focused and widgets_common.pointInRect(mouse.x, mouse.y, chrome.minimize_rect.x, chrome.minimize_rect.y, chrome.minimize_rect.width, chrome.minimize_rect.height);
    const maximize_hovered = focused and widgets_common.pointInRect(mouse.x, mouse.y, chrome.maximize_rect.x, chrome.maximize_rect.y, chrome.maximize_rect.width, chrome.maximize_rect.height);
    const close_hovered = focused and widgets_common.pointInRect(mouse.x, mouse.y, chrome.close_rect.x, chrome.close_rect.y, chrome.close_rect.width, chrome.close_rect.height);
    drawCaptionButton(shell, chrome.minimize_rect, minimize_hovered, pressed_button == .minimize and minimize_hovered, .minimize);
    drawCaptionButton(shell, chrome.maximize_rect, maximize_hovered, pressed_button == .maximize_restore and maximize_hovered, .maximize_restore);
    drawCaptionButton(shell, chrome.close_rect, close_hovered, pressed_button == .close and close_hovered, .close);
}

fn drawCaptionButton(shell: anytype, rect: layout_types.Rect, hovered: bool, pressed: bool, kind: app_terminal_window_chrome_runtime.CaptionButton) void {
    const theme = shell.theme();
    const bg = switch (kind) {
        .close => if (pressed)
            Color{ .r = 196, .g = 52, .b = 49, .a = 255 }
        else if (hovered)
            Color{ .r = 232, .g = 69, .b = 64, .a = 255 }
        else
            theme.ui_bar_bg,
        else => if (pressed)
            theme.ui_pressed
        else if (hovered)
            theme.ui_hover
        else
            theme.ui_bar_bg,
    };
    const fg = if (kind == .close and (hovered or pressed))
        Color{ .r = 255, .g = 255, .b = 255, .a = 255 }
    else
        theme.ui_window_control_fg;

    shell.drawRect(
        @intFromFloat(rect.x),
        @intFromFloat(rect.y),
        @intFromFloat(rect.width),
        @intFromFloat(rect.height),
        bg,
    );

    const scale = shell.uiScaleFactor();
    const stroke = @max(@as(i32, 1), @as(i32, @intFromFloat(std.math.ceil(scale))));
    const icon_size = @max(10.0 * scale, @min(rect.width, rect.height) * 0.38);
    const icon_left_f = rect.x + ((rect.width - icon_size) * 0.5);
    const icon_top_f = rect.y + ((rect.height - icon_size) * 0.5);
    const left = @as(i32, @intFromFloat(std.math.round(icon_left_f)));
    const top = @as(i32, @intFromFloat(std.math.round(icon_top_f)));
    const size = @max(@as(i32, 1), @as(i32, @intFromFloat(std.math.round(icon_size))));
    const right = left + size - 1;
    const bottom = top + size - 1;
    const mid_y = top + @divTrunc(size, 2);
    const line_len = @max(@as(i32, 1), size - (stroke * 2));
    const line_left = left + stroke;
    const restore_offset = @max(@as(i32, 1), stroke * 2);

    switch (kind) {
        .minimize => shell.drawRect(line_left, mid_y, line_len, stroke, fg),
        .maximize_restore => {
            if (shell.windowIsMaximized()) {
                const back_w = @max(1, size - restore_offset);
                const back_h = @max(1, size - restore_offset);
                shell.drawRectOutline(left + restore_offset, top, back_w, back_h, fg);
                shell.drawRectOutline(left, top + restore_offset, back_w, back_h, fg);
            } else {
                shell.drawRectOutline(left, top, size, size, fg);
            }
        },
        .close => {
            drawDiagonalLine(shell, left, top, right, bottom, stroke, fg);
            drawDiagonalLine(shell, left, bottom, right, top, stroke, fg);
        },
    }
}

fn drawDiagonalLine(shell: anytype, x1: i32, y1: i32, x2: i32, y2: i32, stroke: i32, color: Color) void {
    var x = x1;
    var y = y1;
    const dx: i32 = @intCast(@abs(x2 - x1));
    const sx: i32 = if (x1 < x2) 1 else -1;
    const dy: i32 = -@as(i32, @intCast(@abs(y2 - y1)));
    const sy: i32 = if (y1 < y2) 1 else -1;
    var err: i32 = dx + dy;

    while (true) {
        const half = @divTrunc(stroke, 2);
        shell.drawRect(x - half, y - half, stroke, stroke, color);
        if (x == x2 and y == y2) break;
        const e2 = err * 2;
        if (e2 >= dy) {
            err += dy;
            x += sx;
        }
        if (e2 <= dx) {
            err += dx;
            y += sy;
        }
    }
}
