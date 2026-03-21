const std = @import("std");
const app_shell = @import("../app_shell.zig");
const widgets_common = @import("../ui/widgets/common.zig");
const window_caption_buttons_runtime = @import("window_caption_buttons_runtime.zig");

const Color = app_shell.Color;
const CaptionButton = window_caption_buttons_runtime.CaptionButton;

pub fn drawButtons(shell: anytype, rects: anytype, pressed_button: ?CaptionButton) void {
    const mouse = shell.getMousePos();
    const focused = shell.windowFocused();
    const native_sink_active = shell.integratedWindowChromeSinkActive();
    const minimize_hovered = if (native_sink_active)
        focused and shell.integratedWindowChromeMinimizeHovered()
    else
        focused and widgets_common.pointInRect(mouse.x, mouse.y, rects.minimize_rect.x, rects.minimize_rect.y, rects.minimize_rect.width, rects.minimize_rect.height);
    const maximize_hovered = if (native_sink_active)
        focused and shell.integratedWindowChromeMaximizeHovered()
    else
        focused and widgets_common.pointInRect(mouse.x, mouse.y, rects.maximize_rect.x, rects.maximize_rect.y, rects.maximize_rect.width, rects.maximize_rect.height);
    const close_hovered = if (native_sink_active)
        focused and shell.integratedWindowChromeCloseHovered()
    else
        focused and widgets_common.pointInRect(mouse.x, mouse.y, rects.close_rect.x, rects.close_rect.y, rects.close_rect.width, rects.close_rect.height);
    const minimize_pressed = if (native_sink_active)
        shell.integratedWindowChromeMinimizePressed() and minimize_hovered
    else
        pressed_button == .minimize and minimize_hovered;
    const maximize_pressed = if (native_sink_active)
        shell.integratedWindowChromeMaximizePressed() and maximize_hovered
    else
        pressed_button == .maximize_restore and maximize_hovered;
    const close_pressed = if (native_sink_active)
        shell.integratedWindowChromeClosePressed() and close_hovered
    else
        pressed_button == .close and close_hovered;
    drawCaptionButton(shell, rects.minimize_rect, minimize_hovered, minimize_pressed, .minimize);
    drawCaptionButton(shell, rects.maximize_rect, maximize_hovered, maximize_pressed, .maximize_restore);
    drawCaptionButton(shell, rects.close_rect, close_hovered, close_pressed, .close);
}

fn drawCaptionButton(shell: anytype, rect: anytype, hovered: bool, pressed: bool, kind: CaptionButton) void {
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
