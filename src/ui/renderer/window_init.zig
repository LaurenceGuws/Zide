const gl = @import("gl.zig");

const sdl = gl.c;

pub fn initSdl() !void {
    _ = sdl.SDL_SetHint("SDL_APP_NAME", "Zide");
    _ = sdl.SDL_SetHint("SDL_AUDIO_DEVICE_APP_NAME", "Zide");
    _ = sdl.SDL_SetHint("SDL_APP_ID", "com.zide.ide");
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_TIMER) != 0) {
        return error.SdlInitFailed;
    }
}

pub fn configureGlAttributes() void {
    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, 3);
    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, sdl.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_DOUBLEBUFFER, 1);
}

pub fn createWindow(width: i32, height: i32, title: [*:0]const u8) !*sdl.SDL_Window {
    const window = sdl.SDL_CreateWindow(
        title,
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        width,
        height,
        sdl.SDL_WINDOW_OPENGL | sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_ALLOW_HIGHDPI,
    ) orelse return error.SdlWindowFailed;
    return window;
}

pub fn createGlContext(window: *sdl.SDL_Window) !sdl.SDL_GLContext {
    const gl_context = sdl.SDL_GL_CreateContext(window) orelse return error.SdlGlContextFailed;
    _ = sdl.SDL_GL_MakeCurrent(window, gl_context);
    _ = sdl.SDL_GL_SetSwapInterval(1);
    return gl_context;
}
