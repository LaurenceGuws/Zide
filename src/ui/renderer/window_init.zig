const gl = @import("gl.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const windows_app_identity = @import("../../platform/windows_app_identity.zig");
const window_icon_runtime = @import("window_icon_runtime.zig");
const app_logger = @import("../../app_logger.zig");
const std = @import("std");

const sdl = gl.c;

fn glAttrName(attr: sdl_api.GlAttr) []const u8 {
    return switch (attr) {
        sdl.SDL_GL_CONTEXT_MAJOR_VERSION => "SDL_GL_CONTEXT_MAJOR_VERSION",
        sdl.SDL_GL_CONTEXT_MINOR_VERSION => "SDL_GL_CONTEXT_MINOR_VERSION",
        sdl.SDL_GL_CONTEXT_PROFILE_MASK => "SDL_GL_CONTEXT_PROFILE_MASK",
        sdl.SDL_GL_DOUBLEBUFFER => "SDL_GL_DOUBLEBUFFER",
        sdl.SDL_GL_RED_SIZE => "SDL_GL_RED_SIZE",
        sdl.SDL_GL_GREEN_SIZE => "SDL_GL_GREEN_SIZE",
        sdl.SDL_GL_BLUE_SIZE => "SDL_GL_BLUE_SIZE",
        sdl.SDL_GL_ALPHA_SIZE => "SDL_GL_ALPHA_SIZE",
        sdl.SDL_GL_DEPTH_SIZE => "SDL_GL_DEPTH_SIZE",
        sdl.SDL_GL_STENCIL_SIZE => "SDL_GL_STENCIL_SIZE",
        else => "SDL_GL_ATTR_UNKNOWN",
    };
}

fn requireGlAttribute(attr: sdl_api.GlAttr, value: c_int) !void {
    if (sdl_api.glSetAttribute(attr, value)) return;
    app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_GL_SetAttribute failed attr={s} value={d} err={s}", .{
        glAttrName(attr),
        value,
        sdl_api.getError(),
    });
    return error.SdlGlAttributeFailed;
}

pub fn initSdl() !void {
    windows_app_identity.applyCurrentProcess();

    if (std.c.getenv("SDL_APP_NAME")) |name| {
        sdl_api.setHint("SDL_APP_NAME", name);
        sdl_api.setHint("SDL_AUDIO_DEVICE_APP_NAME", name);
    } else {
        sdl_api.setHint("SDL_APP_NAME", windows_app_identity.displayNameZ());
        sdl_api.setHint("SDL_AUDIO_DEVICE_APP_NAME", windows_app_identity.displayNameZ());
    }

    if (std.c.getenv("SDL_APP_ID")) |app_id| {
        sdl_api.setHint("SDL_APP_ID", app_id);
    } else {
        sdl_api.setHint("SDL_APP_ID", windows_app_identity.appIdZ());
    }
    if (!sdl_api.init(sdl_api.defaultInitFlags())) {
        return error.SdlInitFailed;
    }
}

pub fn configureGlAttributes() !void {
    try requireGlAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    try requireGlAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, 3);
    try requireGlAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, sdl.SDL_GL_CONTEXT_PROFILE_CORE);
    try requireGlAttribute(sdl.SDL_GL_DOUBLEBUFFER, 1);
}

pub fn createWindow(width: i32, height: i32, title: [*:0]const u8) !*sdl.SDL_Window {
    const window = sdl_api.createWindow(title, @intCast(width), @intCast(height)) orelse return error.SdlWindowFailed;
    window_icon_runtime.applyWindowIcon(window);
    return window;
}

pub fn createGlContext(window: *sdl.SDL_Window) !sdl.SDL_GLContext {
    const gl_context = sdl_api.glCreateContext(window) orelse return error.SdlGlContextFailed;
    if (!sdl_api.glMakeCurrent(window, gl_context)) {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_GL_MakeCurrent failed err={s}", .{sdl_api.getError()});
        return error.SdlGlMakeCurrentFailed;
    }
    if (!sdl_api.glSetSwapInterval(1)) {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_GL_SetSwapInterval failed interval=1 err={s}", .{sdl_api.getError()});
        return error.SdlSwapIntervalFailed;
    }
    return gl_context;
}
