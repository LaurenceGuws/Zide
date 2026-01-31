const sdl_api = @import("../../platform/sdl_api.zig");

pub fn handleWindowEvent(event_type: c_uint, event_id: u8, should_close: *bool, window_resized: *bool) void {
    if (sdl_api.isResizeEvent(event_type, event_id)) {
        window_resized.* = true;
        return;
    }
    if (sdl_api.isCloseEvent(event_type, event_id)) {
        should_close.* = true;
    }
}
