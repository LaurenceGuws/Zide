const std = @import("std");
const app_shell = @import("../app_shell.zig");
const renderer_chrome_band_host = @import("../ui/renderer/renderer_chrome_band_host.zig");
const widgets_common = @import("../ui/widgets/common.zig");
const window_caption_buttons_runtime = @import("window_caption_buttons_runtime.zig");

const Color = app_shell.Color;
const Band = renderer_chrome_band_host.Band;
const CaptionButton = window_caption_buttons_runtime.CaptionButton;

pub fn drawButtons(shell: anytype, rects: anytype, pressed_button: ?CaptionButton, base_bg: Color) void {
    var band = Band.init(shell, base_bg);
    defer band.flush();

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
    drawCaptionButton(&band, shell, rects.minimize_rect, minimize_hovered, minimize_pressed, .minimize, base_bg);
    drawCaptionButton(&band, shell, rects.maximize_rect, maximize_hovered, maximize_pressed, .maximize_restore, base_bg);
    drawCaptionButton(&band, shell, rects.close_rect, close_hovered, close_pressed, .close, base_bg);
}

fn drawCaptionButton(band: *Band, shell: anytype, rect: anytype, hovered: bool, pressed: bool, kind: CaptionButton, base_bg: Color) void {
    const theme = shell.theme();
    const bg = switch (kind) {
        .close => if (pressed)
            Color{ .r = 196, .g = 52, .b = 49, .a = 255 }
        else if (hovered)
            Color{ .r = 232, .g = 69, .b = 64, .a = 255 }
        else
            base_bg,
        else => if (pressed)
            theme.ui_pressed
        else if (hovered)
            theme.ui_hover
        else
            base_bg,
    };
    const fg = if (kind == .close and (hovered or pressed))
        Color{ .r = 255, .g = 255, .b = 255, .a = 255 }
    else
        theme.ui_window_control_fg;

    band.fillRect(
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
        .minimize => band.fillRect(line_left, mid_y, line_len, stroke, fg),
        .maximize_restore => {
            if (shell.windowIsMaximized()) {
                const back_w = @max(1, size - restore_offset);
                const back_h = @max(1, size - restore_offset);
                band.drawRectOutline(left + restore_offset, top, back_w, back_h, fg);
                band.drawRectOutline(left, top + restore_offset, back_w, back_h, fg);
            } else {
                band.drawRectOutline(left, top, size, size, fg);
            }
        },
        .close => {
            drawDiagonalLine(band, left, top, right, bottom, stroke, fg);
            drawDiagonalLine(band, left, bottom, right, top, stroke, fg);
        },
    }
}

fn drawDiagonalLine(band: *Band, x1: i32, y1: i32, x2: i32, y2: i32, stroke: i32, color: Color) void {
    var x = x1;
    var y = y1;
    const dx: i32 = @intCast(@abs(x2 - x1));
    const sx: i32 = if (x1 < x2) 1 else -1;
    const dy: i32 = -@as(i32, @intCast(@abs(y2 - y1)));
    const sy: i32 = if (y1 < y2) 1 else -1;
    var err: i32 = dx + dy;

    while (true) {
        const half = @divTrunc(stroke, 2);
        band.fillRect(x - half, y - half, stroke, stroke, color);
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
