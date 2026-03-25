const std = @import("std");
const sdl_api = @import("../../platform/sdl_api.zig");
const shared_types = @import("../../types/mod.zig");

const Rect = shared_types.layout.Rect;

pub const WindowChromeMode = enum {
    native,
    terminal_integrated,
    top_bar_integrated,
};

pub const WindowChromeContract = struct {
    mode: WindowChromeMode = .native,
    caption_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    sink_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    minimize_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    maximize_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    close_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    resize_border_px: f32 = 8.0,
};

pub fn hitTest(
    contract: WindowChromeContract,
    window_width: i32,
    window_height: i32,
    maximized: bool,
    x: f32,
    y: f32,
) sdl_api.HitTestResult {
    if (contract.mode == .native) return sdl_api.c.SDL_HITTEST_NORMAL;

    const border = @max(@as(f32, 1.0), contract.resize_border_px);
    const width_f = @as(f32, @floatFromInt(window_width));
    const height_f = @as(f32, @floatFromInt(window_height));

    const left = x < border;
    const right = x >= width_f - border;
    const top = y < border;
    const bottom = y >= height_f - border;

    if (!maximized) {
        if (top and left) return sdl_api.c.SDL_HITTEST_RESIZE_TOPLEFT;
        if (top and right) return sdl_api.c.SDL_HITTEST_RESIZE_TOPRIGHT;
        if (bottom and left) return sdl_api.c.SDL_HITTEST_RESIZE_BOTTOMLEFT;
        if (bottom and right) return sdl_api.c.SDL_HITTEST_RESIZE_BOTTOMRIGHT;
        if (top) return sdl_api.c.SDL_HITTEST_RESIZE_TOP;
        if (right) return sdl_api.c.SDL_HITTEST_RESIZE_RIGHT;
        if (bottom) return sdl_api.c.SDL_HITTEST_RESIZE_BOTTOM;
        if (left) return sdl_api.c.SDL_HITTEST_RESIZE_LEFT;
    }

    if (pointInRect(x, y, contract.caption_rect)) return sdl_api.c.SDL_HITTEST_DRAGGABLE;
    return sdl_api.c.SDL_HITTEST_NORMAL;
}

fn pointInRect(x: f32, y: f32, rect: Rect) bool {
    return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height;
}

test "integrated hit test uses resize borders before caption drag" {
    const contract = WindowChromeContract{
        .mode = .terminal_integrated,
        .caption_rect = .{ .x = 80, .y = 0, .width = 120, .height = 30 },
        .resize_border_px = 8,
    };

    try std.testing.expectEqual(sdl_api.c.SDL_HITTEST_RESIZE_TOPLEFT, hitTest(contract, 800, 600, false, 2, 2));
    try std.testing.expectEqual(sdl_api.c.SDL_HITTEST_DRAGGABLE, hitTest(contract, 800, 600, false, 120, 10));
    try std.testing.expectEqual(sdl_api.c.SDL_HITTEST_NORMAL, hitTest(contract, 800, 600, false, 250, 40));
}

test "maximized integrated hit test disables resize edges" {
    const contract = WindowChromeContract{
        .mode = .terminal_integrated,
        .caption_rect = .{ .x = 0, .y = 0, .width = 200, .height = 30 },
        .resize_border_px = 8,
    };

    try std.testing.expectEqual(sdl_api.c.SDL_HITTEST_DRAGGABLE, hitTest(contract, 800, 600, true, 10, 4));
}
