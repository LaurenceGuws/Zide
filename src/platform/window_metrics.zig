const app_logger = @import("../app_logger.zig");
const iface = @import("../ui/renderer/interface.zig");
const gl = @import("../ui/renderer/gl.zig");
const sdl_api = @import("sdl_api.zig");

const sdl = gl.c;

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

pub const WindowSize = struct {
    w: i32,
    h: i32,
};

pub const DrawableSize = struct {
    w: i32,
    h: i32,
};

pub fn getWindowSize(window: *sdl.SDL_Window) WindowSize {
    var w: c_int = 0;
    var h: c_int = 0;
    sdl_api.getWindowSize(window, &w, &h);
    return .{ .w = w, .h = h };
}

pub fn getDrawableSize(window: *sdl.SDL_Window) DrawableSize {
    var w: c_int = 0;
    var h: c_int = 0;
    sdl_api.getDrawableSize(window, &w, &h);
    return .{ .w = w, .h = h };
}

pub fn getDpiScale(window: *sdl.SDL_Window) iface.MousePos {
    const display_scale = sdl_api.getWindowDisplayScale(window);
    if (display_scale > 0.0) return .{ .x = display_scale, .y = display_scale };
    const density = sdl_api.getWindowPixelDensity(window);
    if (density > 0.0) return .{ .x = density, .y = density };
    const window_size = getWindowSize(window);
    const drawable = getDrawableSize(window);
    if (window_size.w <= 0 or window_size.h <= 0) return .{ .x = 1.0, .y = 1.0 };
    return .{
        .x = @as(f32, @floatFromInt(drawable.w)) / @as(f32, @floatFromInt(window_size.w)),
        .y = @as(f32, @floatFromInt(drawable.h)) / @as(f32, @floatFromInt(window_size.h)),
    };
}

pub fn getRenderScale(window: *sdl.SDL_Window) f32 {
    const display_scale = sdl_api.getWindowDisplayScale(window);
    if (display_scale > 0.0) return display_scale;
    const density = sdl_api.getWindowPixelDensity(window);
    if (density > 0.0) return density;
    const window_size = getWindowSize(window);
    const drawable = getDrawableSize(window);
    if (window_size.w <= 0 or window_size.h <= 0) return 1.0;
    return @as(f32, @floatFromInt(drawable.w)) / @as(f32, @floatFromInt(window_size.w));
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
    const window_size = getWindowSize(window);
    const drawable = getDrawableSize(window);
    const display = sdl_api.getWindowDisplayIndex(window);
    var rect: sdl.SDL_Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 };
    var display_w: i32 = 0;
    var display_h: i32 = 0;
    if (display >= 0 and sdl_api.getDisplayBounds(display, &rect)) {
        display_w = rect.w;
        display_h = rect.h;
    }

    const dpi = getDpiScale(window);
    const display_scale = sdl_api.getWindowDisplayScale(window);
    const pixel_density = sdl_api.getWindowPixelDensity(window);

    var refresh_hz: i32 = 0;
    var mode: sdl.SDL_DisplayMode = undefined;
    if (display >= 0 and sdl_api.getCurrentDisplayMode(display, &mode)) {
        refresh_hz = sdl_api.displayModeRefreshHz(&mode);
    }

    const log = app_logger.logger("sdl.window");
    if (log.enabled_file or log.enabled_console) {
        log.logf(
            "metrics reason={s} window={d}x{d} drawable={d}x{d} display={d} bounds={d}x{d} dpi_scale={d:.3},{d:.3} display_scale={d:.3} pixel_density={d:.3} refresh_hz={d}",
            .{
                reason,
                window_size.w,
                window_size.h,
                drawable.w,
                drawable.h,
                display,
                display_w,
                display_h,
                dpi.x,
                dpi.y,
                display_scale,
                pixel_density,
                refresh_hz,
            },
        );
    }

    return .{
        .window_w = window_size.w,
        .window_h = window_size.h,
        .drawable_w = drawable.w,
        .drawable_h = drawable.h,
        .display_index = display,
        .display_w = display_w,
        .display_h = display_h,
        .dpi = dpi,
        .display_scale = display_scale,
        .pixel_density = pixel_density,
        .refresh_hz = refresh_hz,
    };
}
