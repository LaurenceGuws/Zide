const sdl_api = @import("../../platform/sdl_api.zig");

pub fn handleWindowEvent(event_type: c_uint, should_close: *bool, window_resized: *bool) void {
    if (sdl_api.isResizeEvent(event_type)) {
        window_resized.* = true;
        return;
    }
    if (sdl_api.isCloseEvent(event_type)) {
        should_close.* = true;
    }
}
