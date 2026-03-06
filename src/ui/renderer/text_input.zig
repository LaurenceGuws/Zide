const app_logger = @import("../../app_logger.zig");
const gl = @import("gl.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

const sdl = gl.c;

pub const TextInputState = struct {
    rect: sdl.SDL_Rect,
    valid: bool,
};

pub fn initState() TextInputState {
    return .{
        .rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
        .valid = false,
    };
}

pub fn setRect(state: *TextInputState, window: ?*sdl.SDL_Window, x: i32, y: i32, w: i32, h: i32) void {
    if (w <= 0 or h <= 0) return;
    const rect = sdl.SDL_Rect{ .x = x, .y = y, .w = w, .h = h };
    if (state.valid and
        rect.x == state.rect.x and
        rect.y == state.rect.y and
        rect.w == state.rect.w and
        rect.h == state.rect.h)
    {
        return;
    }
    state.rect = rect;
    state.valid = true;
    sdl_api.setTextInputRect(window, &state.rect);
    const log = app_logger.logger("sdl.ime");
            log.logf(.info, "text_input_rect x={d} y={d} w={d} h={d}", .{ rect.x, rect.y, rect.w, rect.h });
}

pub fn reapplyRect(state: *TextInputState, window: ?*sdl.SDL_Window) void {
    if (!state.valid) return;
    sdl_api.setTextInputRect(window, &state.rect);
}
