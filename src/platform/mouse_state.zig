const compositor = @import("compositor.zig");
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
    var x: f32 = 0;
    var y: f32 = 0;
    sdl_api.getMouseState(&x, &y);
    return .{ .x = x, .y = y };
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
    _ = window;
    var sx: f32 = 1.0;
    var sy: f32 = 1.0;

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
