const active_renderer_runtime = @import("active_renderer_runtime.zig");
const input_state = @import("input_state.zig");
const time_utils = @import("time_utils.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

pub fn rendererActive(comptime RendererType: type) bool {
    return active_renderer_runtime.get(RendererType) != null;
}

pub fn getTime(comptime RendererType: type) f64 {
    if (active_renderer_runtime.get(RendererType)) |renderer| {
        return time_utils.getTime(renderer.start_counter, renderer.perf_freq);
    }
    return time_utils.getTime(null, null);
}

pub fn windowChanges(comptime RendererType: type) sdl_api.WindowChangeMask {
    if (active_renderer_runtime.get(RendererType)) |renderer| {
        return input_state.windowChanges(renderer.inputDomain());
    }
    return .{};
}

pub fn getScreenWidth(comptime RendererType: type) i32 {
    if (active_renderer_runtime.get(RendererType)) |renderer| return renderer.width;
    return 0;
}

pub fn getScreenHeight(comptime RendererType: type) i32 {
    if (active_renderer_runtime.get(RendererType)) |renderer| return renderer.height;
    return 0;
}
