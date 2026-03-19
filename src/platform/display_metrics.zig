const iface = @import("../ui/renderer/interface.zig");
const gl = @import("../ui/renderer/gl.zig");
const sdl_api = @import("sdl_api.zig");

const sdl = gl.c;

pub const WindowSize = struct {
    w: i32,
    h: i32,
};

pub const DrawableSize = struct {
    w: i32,
    h: i32,
};

pub const DisplayMetrics = struct {
    window_w: i32,
    window_h: i32,
    drawable_w: i32,
    drawable_h: i32,
    display_index: i32,
    dpi: iface.MousePos,
    display_scale: f32,
    pixel_density: f32,
    render_scale: f32,
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

fn fallbackScale(window_size: WindowSize, drawable: DrawableSize) iface.MousePos {
    if (window_size.w <= 0 or window_size.h <= 0) return .{ .x = 1.0, .y = 1.0 };
    return .{
        .x = @as(f32, @floatFromInt(drawable.w)) / @as(f32, @floatFromInt(window_size.w)),
        .y = @as(f32, @floatFromInt(drawable.h)) / @as(f32, @floatFromInt(window_size.h)),
    };
}

pub fn collectDisplayMetrics(window: *sdl.SDL_Window) DisplayMetrics {
    const window_size = getWindowSize(window);
    const drawable = getDrawableSize(window);
    const display_index = sdl_api.getWindowDisplayIndex(window);
    const display_scale = sdl_api.getWindowDisplayScale(window);
    const pixel_density = sdl_api.getWindowPixelDensity(window);
    const fallback = fallbackScale(window_size, drawable);
    const dpi = if (display_scale > 0.0)
        iface.MousePos{ .x = display_scale, .y = display_scale }
    else if (pixel_density > 0.0)
        iface.MousePos{ .x = pixel_density, .y = pixel_density }
    else
        fallback;
    const render_scale = if (pixel_density > 0.0)
        pixel_density
    else
        fallback.x;

    return .{
        .window_w = window_size.w,
        .window_h = window_size.h,
        .drawable_w = drawable.w,
        .drawable_h = drawable.h,
        .display_index = display_index,
        .dpi = dpi,
        .display_scale = display_scale,
        .pixel_density = pixel_density,
        .render_scale = render_scale,
    };
}
