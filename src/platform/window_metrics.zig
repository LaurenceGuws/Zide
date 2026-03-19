const app_logger = @import("../app_logger.zig");
const iface = @import("../ui/renderer/interface.zig");
const gl = @import("../ui/renderer/gl.zig");
const display_metrics = @import("display_metrics.zig");
const sdl_api = @import("sdl_api.zig");

const sdl = gl.c;
pub const DisplayMetrics = display_metrics.DisplayMetrics;
pub const WindowSize = display_metrics.WindowSize;
pub const DrawableSize = display_metrics.DrawableSize;

pub const WindowMetrics = struct {
    window_w: i32,
    window_h: i32,
    drawable_w: i32,
    drawable_h: i32,
    display_index: i32,
    display_w: i32,
    display_h: i32,
    dpi: iface.MousePos,
    display_scale: f32,
    pixel_density: f32,
    refresh_hz: i32,
};

pub fn getWindowSize(window: *sdl.SDL_Window) WindowSize {
    return display_metrics.getWindowSize(window);
}

pub fn getDrawableSize(window: *sdl.SDL_Window) DrawableSize {
    return display_metrics.getDrawableSize(window);
}

pub fn getDpiScale(window: *sdl.SDL_Window) iface.MousePos {
    return display_metrics.collectDisplayMetrics(window).dpi;
}

pub fn getRenderScale(window: *sdl.SDL_Window) f32 {
    return display_metrics.collectDisplayMetrics(window).render_scale;
}

pub fn collectDisplayMetrics(window: *sdl.SDL_Window) DisplayMetrics {
    return display_metrics.collectDisplayMetrics(window);
}

pub fn getScreenSize(window: *sdl.SDL_Window) iface.MousePos {
    const window_size = getWindowSize(window);
    return .{ .x = @floatFromInt(window_size.w), .y = @floatFromInt(window_size.h) };
}

pub fn getMonitorSize(window: *sdl.SDL_Window) iface.MousePos {
    const display = sdl_api.getWindowDisplayIndex(window);
    var rect: sdl.SDL_Rect = undefined;
    if (display >= 0 and sdl_api.getDisplayBounds(display, &rect)) {
        return .{ .x = @floatFromInt(rect.w), .y = @floatFromInt(rect.h) };
    }
    return getScreenSize(window);
}

pub fn collectWindowMetrics(window: *sdl.SDL_Window, reason: []const u8) WindowMetrics {
    const display = collectDisplayMetrics(window);
    var rect: sdl.SDL_Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 };
    var display_w: i32 = 0;
    var display_h: i32 = 0;
    if (display.display_index >= 0 and sdl_api.getDisplayBounds(display.display_index, &rect)) {
        display_w = rect.w;
        display_h = rect.h;
    }

    var refresh_hz: i32 = 0;
    var mode: sdl.SDL_DisplayMode = undefined;
    if (display.display_index >= 0 and sdl_api.getCurrentDisplayMode(display.display_index, &mode)) {
        refresh_hz = sdl_api.displayModeRefreshHz(&mode);
    }

    const log = app_logger.logger("sdl.window");
    log.logf(
        .info,
        "metrics reason={s} window={d}x{d} drawable={d}x{d} display={d} bounds={d}x{d} dpi_scale={d:.3},{d:.3} display_scale={d:.3} pixel_density={d:.3} refresh_hz={d}",
        .{
            reason,
            display.window_w,
            display.window_h,
            display.drawable_w,
            display.drawable_h,
            display.display_index,
            display_w,
            display_h,
            display.dpi.x,
            display.dpi.y,
            display.display_scale,
            display.pixel_density,
            refresh_hz,
        },
    );

    return .{
        .window_w = display.window_w,
        .window_h = display.window_h,
        .drawable_w = display.drawable_w,
        .drawable_h = display.drawable_h,
        .display_index = display.display_index,
        .display_w = display_w,
        .display_h = display_h,
        .dpi = display.dpi,
        .display_scale = display.display_scale,
        .pixel_density = display.pixel_density,
        .refresh_hz = refresh_hz,
    };
}
