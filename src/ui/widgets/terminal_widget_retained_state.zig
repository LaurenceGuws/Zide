const std = @import("std");
const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");

pub const RetainedState = struct {
    partial_draw_rows: std.ArrayList(bool),
    partial_draw_span_counts: std.ArrayList(u8),
    partial_draw_spans: std.ArrayList([render_cache_mod.max_row_dirty_spans]render_cache_mod.RowDirtySpan),
    partial_draw_cols_start: std.ArrayList(u16),
    partial_draw_cols_end: std.ArrayList(u16),
    terminal_texture_ready: bool = false,
    last_render_generation: u64 = 0,
    last_render_clear_generation: u64 = 0,
    last_alt_active: bool = false,
    last_cell_w_i: i32 = 0,
    last_cell_h_i: i32 = 0,
    last_render_scale: f32 = 0,

    pub fn init() RetainedState {
        return .{
            .partial_draw_rows = std.ArrayList(bool).empty,
            .partial_draw_span_counts = std.ArrayList(u8).empty,
            .partial_draw_spans = std.ArrayList([render_cache_mod.max_row_dirty_spans]render_cache_mod.RowDirtySpan).empty,
            .partial_draw_cols_start = std.ArrayList(u16).empty,
            .partial_draw_cols_end = std.ArrayList(u16).empty,
        };
    }

    pub fn deinit(self: *RetainedState, allocator: std.mem.Allocator) void {
        self.partial_draw_rows.deinit(allocator);
        self.partial_draw_span_counts.deinit(allocator);
        self.partial_draw_spans.deinit(allocator);
        self.partial_draw_cols_start.deinit(allocator);
        self.partial_draw_cols_end.deinit(allocator);
    }

    pub fn invalidateTextureCache(self: *RetainedState) void {
        self.terminal_texture_ready = false;
    }
};
