const session_rendering = @import("session_rendering.zig");

pub const PresentedRenderCache = session_rendering.PresentedRenderCache;

pub const AltExitPresentationInfo = struct {
    draw_ms: f64,
    rows: usize,
    cols: usize,
    history_len: usize,
    scroll_offset: usize,
};

pub const PresentationFeedback = struct {
    presented: ?PresentedRenderCache = null,
    texture_updated: bool = false,
    alt_exit_info: ?AltExitPresentationInfo = null,
};
