const sdl_api = @import("sdl_api.zig");

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
    return .{ .x = 1.0, .y = 1.0 };
}
