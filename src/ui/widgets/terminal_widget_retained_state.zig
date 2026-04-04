const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");

const RowDirtySpan = render_cache_mod.RowDirtySpan;
const max_row_dirty_spans = render_cache_mod.max_row_dirty_spans;

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

    pub const PartialDrawPlan = struct {
        rows: []bool,
        span_counts: []u8,
        spans: [][max_row_dirty_spans]RowDirtySpan,
        cols_start: []u16,
        cols_end: []u16,
    };

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

    pub fn ensurePartialDrawPlan(self: *RetainedState, allocator: std.mem.Allocator, rows: usize) ?PartialDrawPlan {
        self.partial_draw_rows.resize(allocator, rows) catch |err| {
            const log = app_logger.logger("terminal.ui.redraw");
            log.logf(.warning, "partial row plan resize failed field=rows rows={d} err={s}", .{ rows, @errorName(err) });
            return null;
        };
        self.partial_draw_cols_start.resize(allocator, rows) catch |err| {
            const log = app_logger.logger("terminal.ui.redraw");
            log.logf(.warning, "partial row plan resize failed field=cols_start rows={d} err={s}", .{ rows, @errorName(err) });
            return null;
        };
        self.partial_draw_cols_end.resize(allocator, rows) catch |err| {
            const log = app_logger.logger("terminal.ui.redraw");
            log.logf(.warning, "partial row plan resize failed field=cols_end rows={d} err={s}", .{ rows, @errorName(err) });
            return null;
        };
        self.partial_draw_span_counts.resize(allocator, rows) catch |err| {
            const log = app_logger.logger("terminal.ui.redraw");
            log.logf(.warning, "partial row plan resize failed field=span_counts rows={d} err={s}", .{ rows, @errorName(err) });
            return null;
        };
        self.partial_draw_spans.resize(allocator, rows) catch |err| {
            const log = app_logger.logger("terminal.ui.redraw");
            log.logf(.warning, "partial row plan resize failed field=spans rows={d} err={s}", .{ rows, @errorName(err) });
            return null;
        };

        return .{
            .rows = self.partial_draw_rows.items,
            .span_counts = self.partial_draw_span_counts.items,
            .spans = self.partial_draw_spans.items,
            .cols_start = self.partial_draw_cols_start.items,
            .cols_end = self.partial_draw_cols_end.items,
        };
    }
};
