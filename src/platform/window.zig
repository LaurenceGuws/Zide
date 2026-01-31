const iface = @import("../ui/renderer/interface.zig");
const gl = @import("../ui/renderer/gl.zig");
const window_metrics = @import("window_metrics.zig");

const sdl = gl.c;

pub const WindowMetrics = window_metrics.WindowMetrics;

pub fn getWindowSize(window: *sdl.SDL_Window) window_metrics.WindowSize {
    return window_metrics.getWindowSize(window);
}

pub fn getDrawableSize(window: *sdl.SDL_Window) window_metrics.DrawableSize {
    return window_metrics.getDrawableSize(window);
}

pub fn getDpiScale(window: *sdl.SDL_Window) iface.MousePos {
    return window_metrics.getDpiScale(window);
}

pub fn getRenderScale(window: *sdl.SDL_Window) f32 {
    return window_metrics.getRenderScale(window);
}

pub fn getScreenSize(window: *sdl.SDL_Window) iface.MousePos {
    return window_metrics.getScreenSize(window);
}

pub fn getMonitorSize(window: *sdl.SDL_Window) iface.MousePos {
    return window_metrics.getMonitorSize(window);
}

pub fn collectWindowMetrics(window: *sdl.SDL_Window, reason: []const u8) WindowMetrics {
    return window_metrics.collectWindowMetrics(window, reason);
}
