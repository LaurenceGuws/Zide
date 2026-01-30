const window_events = @import("../platform/window_events.zig");

pub fn handleWindowEvent(event_id: u8, should_close: *bool, window_resized: *bool) void {
    if (window_events.isResizeEvent(event_id)) {
        window_resized.* = true;
        return;
    }
    if (window_events.isCloseEvent(event_id)) {
        should_close.* = true;
    }
}
