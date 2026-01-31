const compositor = @import("compositor.zig");
const platform_window = @import("window.zig");
const sdl_api = @import("sdl_api.zig");
const std = @import("std");

const sdl = sdl_api.c;

pub const MouseScale = struct {
    x: f32,
    y: f32,
};

pub const MousePos = struct {
    x: f32,
    y: f32,
};

pub fn getMousePosRaw() MousePos {
    var x: c_int = 0;
    var y: c_int = 0;
    sdl_api.getMouseState(&x, &y);
    return .{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
}

pub fn getScaledPos(scale: MouseScale) MousePos {
    const pos = getMousePosRaw();
    return .{ .x = pos.x * scale.x, .y = pos.y * scale.y };
}

pub fn getScaledPosWithFactor(scale: f32) MousePos {
    const pos = getMousePosRaw();
    return .{ .x = pos.x * scale, .y = pos.y * scale };
}

pub fn computeMouseScale(window: *sdl.SDL_Window) MouseScale {
    if (sdl_api.is_sdl3) {
        const density = sdl_api.getWindowPixelDensity(window);
        if (density > 0.0) return .{ .x = density, .y = density };
    }
    const window_size = platform_window.getWindowSize(window);
    const drawable = platform_window.getDrawableSize(window);
    var sx: f32 = if (window_size.w > 0) @as(f32, @floatFromInt(drawable.w)) / @as(f32, @floatFromInt(window_size.w)) else 1.0;
    var sy: f32 = if (window_size.h > 0) @as(f32, @floatFromInt(drawable.h)) / @as(f32, @floatFromInt(window_size.h)) else 1.0;

    if (compositor.isWayland()) {
        // SDL already reports logical mouse coords; drawable/window ratio matches render scale.
        // Avoid double-applying compositor scale here.
    }

    if (std.c.getenv("ZIDE_MOUSE_SCALE")) |raw| {
        const s = std.mem.sliceTo(raw, 0);
        const env_scale = std.fmt.parseFloat(f32, s) catch 1.0;
        sx *= env_scale;
        sy *= env_scale;
    }

    return .{ .x = sx, .y = sy };
}
