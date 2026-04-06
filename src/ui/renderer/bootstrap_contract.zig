const native_host = @import("../../platform/native_host.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const window_init = @import("window_init.zig");

pub const BackendBootstrapOps = struct {
    graphics_binding: native_host.RenderSurfaceBinding,
    configureWindowAttributes: *const fn () anyerror!void,
    createBackendContext: *const fn (*sdl_api.c.SDL_Window) anyerror!?sdl_api.c.SDL_GLContext,
    runStartupSmoke: *const fn (*sdl_api.c.SDL_Window, window_init.RenderSurfaceAttachment, i32, i32) anyerror!bool,
};
