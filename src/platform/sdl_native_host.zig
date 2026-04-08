const native_host = @import("native_host.zig");
const sdl_api = @import("sdl_api.zig");

pub fn captureWindowSurfaceMetrics(window: *sdl_api.c.SDL_Window) native_host.RenderSurfaceMetrics {
    var logical_width: c_int = 0;
    var logical_height: c_int = 0;
    var drawable_width: c_int = 0;
    var drawable_height: c_int = 0;
    sdl_api.getWindowSize(window, &logical_width, &logical_height);
    sdl_api.getDrawableSize(window, &drawable_width, &drawable_height);
    return .{
        .logical_width = logical_width,
        .logical_height = logical_height,
        .drawable_width = drawable_width,
        .drawable_height = drawable_height,
        .display_scale = sdl_api.getWindowDisplayScale(window),
        .pixel_density = sdl_api.getWindowPixelDensity(window),
    };
}

pub fn captureRenderHost(
    window: *sdl_api.c.SDL_Window,
    binding: native_host.RenderSurfaceBinding,
) native_host.PlatformRenderHost {
    return .{
        .binding = binding,
        .surface_availability = .available,
        .surface_metrics = captureWindowSurfaceMetrics(window),
        .native_handles = .{
            .cocoa_window = sdl_api.getWindowCocoaWindow(window),
            .cocoa_view = sdl_api.getWindowCocoaView(window),
            .win32_hwnd = sdl_api.getWindowWin32Hwnd(window),
        },
    };
}
