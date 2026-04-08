const android_host = @import("android_host.zig");
const native_host = @import("native_host.zig");
const sdl_api = @import("sdl_api.zig");
const sdl_native_host = @import("sdl_native_host.zig");

pub fn noteWindowRefresh(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
    window: *sdl_api.c.SDL_Window,
) bool {
    if (!android_host.usesAndroidActivityHost(app_host.*)) return false;
    render_host.noteSurfaceAvailable(sdl_native_host.captureWindowSurfaceMetrics(window));
    render_host.noteRedrawRequested();
    return true;
}
