const gl = @import("gl.zig");
const sdl_input = @import("sdl_input.zig");

const sdl = gl.c;

pub fn drain(input: *sdl_input.SdlInput) []const sdl.SDL_Event {
    input.drainEvents();
    return input.drain.items;
}
