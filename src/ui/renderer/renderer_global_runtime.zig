const active_renderer_runtime = @import("active_renderer_runtime.zig");
const input_state = @import("input_state.zig");
const time_utils = @import("time_utils.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

pub fn activeRenderer(comptime RendererType: type) ?*RendererType {
    return active_renderer_runtime.get(RendererType);
}

pub fn rendererActive(comptime RendererType: type) bool {
    return activeRenderer(RendererType) != null;
}

pub fn getTime(comptime RendererType: type) f64 {
    if (activeRenderer(RendererType)) |renderer| {
        return time_utils.getTime(renderer.start_counter, renderer.perf_freq);
    }
    return time_utils.getTime(null, null);
}

pub fn windowChanges(comptime RendererType: type) sdl_api.WindowChangeMask {
    if (activeRenderer(RendererType)) |renderer| {
        return input_state.windowChanges(renderer.inputDomain());
    }
    return .{};
}

pub fn getScreenWidth(comptime RendererType: type) i32 {
    if (activeRenderer(RendererType)) |renderer| return renderer.width;
    return 0;
}

pub fn getScreenHeight(comptime RendererType: type) i32 {
    if (activeRenderer(RendererType)) |renderer| return renderer.height;
    return 0;
}

pub fn waitForWakeOrTimeout(comptime RendererType: type, seconds: f64) void {
    if (seconds <= 0) return;
    if (activeRenderer(RendererType)) |renderer| {
        if (input_state.hasPendingWaitEvent(renderer.inputDomain())) return;
        const timeout_ms: c_int = @intFromFloat(@ceil(seconds * 1000.0));
        if (timeout_ms <= 0) return;
        var event: sdl_api.c.SDL_Event = undefined;
        if (sdl_api.waitEventTimeout(&event, timeout_ms)) {
            input_state.stagePendingWaitEvent(renderer.inputDomain(), event);
            return;
        }
    }
    time_utils.waitTime(seconds);
}
