const gl = @import("gl.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
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

fn glAttrValue(attr: sdl_api.GlAttr) i32 {
    return if (sdl_api.glGetAttribute(attr)) |value| @intCast(value) else -1;
}

fn pointerValue(ptr: ?*anyopaque) usize {
    return if (ptr) |value| @intFromPtr(value) else 0;
}

fn eglRenderBufferName(value: c_int) []const u8 {
    return switch (value) {
        0x3084 => "EGL_BACK_BUFFER",
        0x3085 => "EGL_SINGLE_BUFFER",
        else => "EGL_RENDER_BUFFER_UNKNOWN",
    };
}

fn eglSwapBehaviorName(value: c_int) []const u8 {
    return switch (value) {
        0x3094 => "EGL_BUFFER_PRESERVED",
        0x3095 => "EGL_BUFFER_DESTROYED",
        else => "EGL_SWAP_BEHAVIOR_UNKNOWN",
    };
}

fn functionFromEglProc(comptime Fn: type, name: [*:0]const u8) ?Fn {
    const raw = sdl_api.eglGetProcAddress(name) orelse return null;
    return @ptrCast(raw);
}

fn queryEglSurfaceAttribute(
    egl_query_surface: *const fn (display: sdl_api.EglDisplay, surface: sdl_api.EglSurface, attribute: c_int, value: *c_int) callconv(.c) c_uint,
    egl_get_error: ?*const fn () callconv(.c) c_int,
    display: sdl_api.EglDisplay,
    surface: sdl_api.EglSurface,
    attribute: c_int,
    label: []const u8,
) ?c_int {
    var value: c_int = 0;
    if (egl_query_surface(display, surface, attribute, &value) != 0) return value;
    app_logger.logger("sdl.gl").logStdout(.@"error", "eglQuerySurface failed attr={s} attr_hex=0x{x} egl_error=0x{x}", .{
        label,
        attribute,
        if (egl_get_error) |func| func() else @as(c_int, -1),
    });
    return null;
}

fn queryEglConfigAttribute(
    egl_get_config_attrib: *const fn (display: sdl_api.EglDisplay, config: sdl_api.EglConfig, attribute: c_int, value: *c_int) callconv(.c) c_uint,
    egl_get_error: ?*const fn () callconv(.c) c_int,
    display: sdl_api.EglDisplay,
    config: sdl_api.EglConfig,
    attribute: c_int,
    label: []const u8,
) ?c_int {
    var value: c_int = 0;
    if (egl_get_config_attrib(display, config, attribute, &value) != 0) return value;
    app_logger.logger("sdl.gl").logStdout(.@"error", "eglGetConfigAttrib failed attr={s} attr_hex=0x{x} egl_error=0x{x}", .{
        label,
        attribute,
        if (egl_get_error) |func| func() else @as(c_int, -1),
    });
    return null;
}

fn logWaylandNativeHandles(window: *sdl.SDL_Window) void {
    const driver = sdl_api.getCurrentVideoDriver() orelse return;
    if (!std.mem.eql(u8, driver, "wayland")) return;

    const props = sdl_api.getWindowProperties(window) orelse {
        app_logger.logger("sdl.window").logStdout(.@"error", "SDL_GetWindowProperties failed err={s}", .{sdl_api.getError()});
        return;
    };
    app_logger.logger("sdl.window").logStdout(.info, "event=wayland_handles wl_display=0x{x} wl_surface=0x{x} wl_egl_window=0x{x} xdg_surface=0x{x} xdg_toplevel=0x{x}", .{
        pointerValue(sdl_api.getPointerProperty(props, "SDL.window.wayland.display")),
        pointerValue(sdl_api.getPointerProperty(props, "SDL.window.wayland.surface")),
        pointerValue(sdl_api.getPointerProperty(props, "SDL.window.wayland.egl_window")),
        pointerValue(sdl_api.getPointerProperty(props, "SDL.window.wayland.xdg_surface")),
        pointerValue(sdl_api.getPointerProperty(props, "SDL.window.wayland.xdg_toplevel")),
    });
}

fn logRealizedGlContext() void {
    app_logger.logger("sdl.gl").logStdout(.info, "SDL GL realized major={d} minor={d} profile_mask={d} doublebuffer={d} red={d} green={d} blue={d} alpha={d} depth={d} stencil={d} swap_interval={d}", .{
        glAttrValue(sdl.SDL_GL_CONTEXT_MAJOR_VERSION),
        glAttrValue(sdl.SDL_GL_CONTEXT_MINOR_VERSION),
        glAttrValue(sdl.SDL_GL_CONTEXT_PROFILE_MASK),
        glAttrValue(sdl.SDL_GL_DOUBLEBUFFER),
        glAttrValue(sdl.SDL_GL_RED_SIZE),
        glAttrValue(sdl.SDL_GL_GREEN_SIZE),
        glAttrValue(sdl.SDL_GL_BLUE_SIZE),
        glAttrValue(sdl.SDL_GL_ALPHA_SIZE),
        glAttrValue(sdl.SDL_GL_DEPTH_SIZE),
        glAttrValue(sdl.SDL_GL_STENCIL_SIZE),
        sdl_api.glGetSwapInterval(),
    });
}

fn logEglSurfaceContract(window: *sdl.SDL_Window) void {
    const driver = sdl_api.getCurrentVideoDriver() orelse return;
    if (!std.mem.eql(u8, driver, "wayland")) return;

    const display = sdl_api.eglGetCurrentDisplay() orelse {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_EGL_GetCurrentDisplay failed err={s}", .{sdl_api.getError()});
        return;
    };
    const config = sdl_api.eglGetCurrentConfig() orelse {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_EGL_GetCurrentConfig failed err={s}", .{sdl_api.getError()});
        return;
    };
    const surface = sdl_api.eglGetWindowSurface(window) orelse {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_EGL_GetWindowSurface failed err={s}", .{sdl_api.getError()});
        return;
    };

    const EglQuerySurfaceFn = *const fn (display: sdl_api.EglDisplay, surface: sdl_api.EglSurface, attribute: c_int, value: *c_int) callconv(.c) c_uint;
    const EglGetConfigAttribFn = *const fn (display: sdl_api.EglDisplay, config: sdl_api.EglConfig, attribute: c_int, value: *c_int) callconv(.c) c_uint;
    const EglGetErrorFn = *const fn () callconv(.c) c_int;
    const EglQueryStringFn = *const fn (display: sdl_api.EglDisplay, name: c_int) callconv(.c) ?[*:0]const u8;

    const egl_query_surface = functionFromEglProc(EglQuerySurfaceFn, "eglQuerySurface") orelse {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_EGL_GetProcAddress failed proc=eglQuerySurface", .{});
        return;
    };
    const egl_get_config_attrib = functionFromEglProc(EglGetConfigAttribFn, "eglGetConfigAttrib") orelse {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_EGL_GetProcAddress failed proc=eglGetConfigAttrib", .{});
        return;
    };
    const egl_get_error = functionFromEglProc(EglGetErrorFn, "eglGetError");
    const egl_query_string = functionFromEglProc(EglQueryStringFn, "eglQueryString");

    const EGL_SURFACE_TYPE: c_int = 0x3033;
    const EGL_WIDTH: c_int = 0x3057;
    const EGL_HEIGHT: c_int = 0x3056;
    const EGL_VENDOR: c_int = 0x3053;
    const EGL_VERSION: c_int = 0x3054;
    const EGL_CLIENT_APIS: c_int = 0x308D;
    const EGL_RENDER_BUFFER: c_int = 0x3086;
    const EGL_SWAP_BEHAVIOR: c_int = 0x3093;
    const EGL_SWAP_BEHAVIOR_PRESERVED_BIT: c_int = 0x0400;
    const EGL_CONFIG_ID: c_int = 0x3028;

    const render_buffer = queryEglSurfaceAttribute(egl_query_surface, egl_get_error, display, surface, EGL_RENDER_BUFFER, "EGL_RENDER_BUFFER") orelse return;
    const swap_behavior = queryEglSurfaceAttribute(egl_query_surface, egl_get_error, display, surface, EGL_SWAP_BEHAVIOR, "EGL_SWAP_BEHAVIOR") orelse return;
    const width = queryEglSurfaceAttribute(egl_query_surface, egl_get_error, display, surface, EGL_WIDTH, "EGL_WIDTH") orelse return;
    const height = queryEglSurfaceAttribute(egl_query_surface, egl_get_error, display, surface, EGL_HEIGHT, "EGL_HEIGHT") orelse return;
    const surface_type = queryEglConfigAttribute(egl_get_config_attrib, egl_get_error, display, config, EGL_SURFACE_TYPE, "EGL_SURFACE_TYPE") orelse return;
    const config_id = queryEglConfigAttribute(egl_get_config_attrib, egl_get_error, display, config, EGL_CONFIG_ID, "EGL_CONFIG_ID") orelse return;

    app_logger.logger("sdl.gl").logStdout(.info, "SDL EGL contract display=0x{x} config=0x{x} surface=0x{x} config_id={d} render_buffer={s}({d}) swap_behavior={s}({d}) surface_type=0x{x} preserved_bit={d} width={d} height={d} vendor={s} version={s} client_apis={s}", .{
        @intFromPtr(display),
        @intFromPtr(config),
        @intFromPtr(surface),
        config_id,
        eglRenderBufferName(render_buffer),
        render_buffer,
        eglSwapBehaviorName(swap_behavior),
        swap_behavior,
        surface_type,
        @intFromBool((surface_type & EGL_SWAP_BEHAVIOR_PRESERVED_BIT) != 0),
        width,
        height,
        if (egl_query_string) |func|
            std.mem.span(func(display, EGL_VENDOR) orelse "")
        else
            "unavailable",
        if (egl_query_string) |func|
            std.mem.span(func(display, EGL_VERSION) orelse "")
        else
            "unavailable",
        if (egl_query_string) |func|
            std.mem.span(func(display, EGL_CLIENT_APIS) orelse "")
        else
            "unavailable",
    });
}

pub fn initSdl() !void {
    if (std.c.getenv("SDL_APP_NAME")) |name| {
        sdl_api.setHint("SDL_APP_NAME", name);
        sdl_api.setHint("SDL_AUDIO_DEVICE_APP_NAME", name);
    } else {
        sdl_api.setHint("SDL_APP_NAME", "Zide");
        sdl_api.setHint("SDL_AUDIO_DEVICE_APP_NAME", "Zide");
    }

    if (std.c.getenv("SDL_APP_ID") == null) {
        sdl_api.setHint("SDL_APP_ID", "com.zide.ide");
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
    logRealizedGlContext();
    logWaylandNativeHandles(window);
    logEglSurfaceContract(window);
    return gl_context;
}
