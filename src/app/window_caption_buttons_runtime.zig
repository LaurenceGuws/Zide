const std = @import("std");
const app_shell = @import("../app_shell.zig");
const app_types = @import("app_state_types.zig");
const shared_types = @import("../types/mod.zig");

const Rect = shared_types.layout.Rect;
const Shell = app_shell.Shell;

pub const CaptionButton = app_types.WindowCaptionButton;

pub const Rects = struct {
    band: Rect,
    caption_rect: Rect,
    sink_rect: Rect,
    minimize_rect: Rect,
    maximize_rect: Rect,
    close_rect: Rect,
    resize_border_px: f32,
};

pub fn computeRects(shell: *Shell, band: Rect, leading_used_width: f32) Rects {
    const scale = shell.uiScaleFactor();
    const button_width = @max(46.0 * scale, band.height * 1.35);
    const button_total_width = button_width * 3.0;
    const drag_min_width = @max(56.0 * scale, band.height * 1.5);
    const leading_width = @min(@max(0.0, leading_used_width), @max(0.0, band.width - button_total_width));
    const buttons_x = band.x + band.width - button_total_width;
    const caption_x = band.x + leading_width;
    const caption_width = @max(0.0, buttons_x - caption_x);
    const enforced_caption_width = @max(caption_width, drag_min_width);
    const enforced_caption_x = @max(caption_x, buttons_x - enforced_caption_width);

    const caption_rect = Rect{
        .x = enforced_caption_x,
        .y = band.y,
        .width = @max(0.0, buttons_x - enforced_caption_x),
        .height = band.height,
    };

    return .{
        .band = band,
        .caption_rect = caption_rect,
        .sink_rect = Rect{
            .x = caption_rect.x,
            .y = band.y,
            .width = @max(0.0, (buttons_x + button_total_width) - caption_rect.x),
            .height = band.height,
        },
        .minimize_rect = .{
            .x = buttons_x,
            .y = band.y,
            .width = button_width,
            .height = band.height,
        },
        .maximize_rect = .{
            .x = buttons_x + button_width,
            .y = band.y,
            .width = button_width,
            .height = band.height,
        },
        .close_rect = .{
            .x = buttons_x + (button_width * 2.0),
            .y = band.y,
            .width = button_width,
            .height = band.height,
        },
        .resize_border_px = @max(6.0, 8.0 * scale),
    };
}

pub fn buttonAt(rects: anytype, x: f32, y: f32) ?CaptionButton {
    if (pointInRect(x, y, rects.minimize_rect)) return .minimize;
    if (pointInRect(x, y, rects.maximize_rect)) return .maximize_restore;
    if (pointInRect(x, y, rects.close_rect)) return .close;
    return null;
}

pub fn captionDragAt(rects: anytype, x: f32, y: f32) bool {
    return pointInRect(x, y, rects.caption_rect);
}

pub fn windowChromeContract(mode: app_shell.WindowChromeMode, rects: anytype) app_shell.WindowChromeContract {
    return .{
        .mode = mode,
        .caption_rect = rects.caption_rect,
        .sink_rect = rects.sink_rect,
        .minimize_rect = rects.minimize_rect,
        .maximize_rect = rects.maximize_rect,
        .close_rect = rects.close_rect,
        .resize_border_px = rects.resize_border_px,
    };
}

fn pointInRect(x: f32, y: f32, rect: Rect) bool {
    return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height;
}
