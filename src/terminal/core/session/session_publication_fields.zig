const std = @import("std");
const render_cache_mod = @import("../render_cache.zig");

pub const Fields = struct {
    output_pending: std.atomic.Value(bool),
    pending_generation: std.atomic.Value(u64),
    presented_generation: std.atomic.Value(u64),
    alt_exit_pending: std.atomic.Value(bool),
    alt_exit_time_ms: std.atomic.Value(i64),
    render_caches: [2]render_cache_mod.RenderCache,
    render_cache_index: std.atomic.Value(u8),
    view_cache_pending: std.atomic.Value(bool),
    view_cache_request_offset: std.atomic.Value(u64),
};
