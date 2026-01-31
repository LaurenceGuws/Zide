const gl = @import("gl.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

const sdl = gl.c;

pub fn initSdl() !void {
    sdl_api.setHint("SDL_APP_NAME", "Zide");
    sdl_api.setHint("SDL_AUDIO_DEVICE_APP_NAME", "Zide");
    sdl_api.setHint("SDL_APP_ID", "com.zide.ide");
    if (!sdl_api.init(sdl_api.defaultInitFlags())) {
        return error.SdlInitFailed;
    }
}

pub fn configureGlAttributes() void {
    sdl_api.glSetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    sdl_api.glSetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, 3);
    sdl_api.glSetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, sdl.SDL_GL_CONTEXT_PROFILE_CORE);
    sdl_api.glSetAttribute(sdl.SDL_GL_DOUBLEBUFFER, 1);
}

pub fn createWindow(width: i32, height: i32, title: [*:0]const u8) !*sdl.SDL_Window {
    const window = sdl_api.createWindow(title, @intCast(width), @intCast(height)) orelse return error.SdlWindowFailed;
    return window;
}

pub fn createGlContext(window: *sdl.SDL_Window) !sdl.SDL_GLContext {
    const gl_context = sdl_api.glCreateContext(window) orelse return error.SdlGlContextFailed;
    sdl_api.glMakeCurrent(window, gl_context);
    sdl_api.glSetSwapInterval(1);
    return gl_context;
}
