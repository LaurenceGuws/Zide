const host_lifecycle_runtime = @import("host_lifecycle_runtime.zig");
const native_host = @import("native_host.zig");
const sdl_api = @import("sdl_api.zig");

pub fn noteWindowRefresh(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
    window: *sdl_api.c.SDL_Window,
) bool {
    return host_lifecycle_runtime.noteSdlWindowRefresh(app_host, render_host, window);
}
