//! Cached terminal **presentation draw** state: partial row plans plus the last
//! generations recorded for the terminal surface draw (see `surface_contract`
//! composite helpers).
//!
//! **Vocabulary lock (`CZH-S18`, alias reduction `CZH-B25`):**
//! - **Generation (surface cache):** `last_render_generation`, `last_render_clear_generation`.
//! - **Pipeline leg:** `terminal_presentable_pipeline_ready` (not full attachment alone).
//! - **Host target leg:** `host_surface_target_available` (drawable target exists for the attachment).
//! - **Full attachment:** `hostSharedSurfaceAttachmentReady(pipeline, target)` in
//!   `surface_attachment_contract` — not stored as a single bool here.
const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");

const RowDirtySpan = render_cache_mod.RowDirtySpan;
const max_row_dirty_spans = render_cache_mod.max_row_dirty_spans;

pub const PresentationState = struct {
    pub const InvalidationFlags = packed struct(u8) {
        geometry: bool = false,
        content: bool = false,
        overlay: bool = false,
        availability: bool = false,
        _reserved: u4 = 0,
    };

    partial_draw_rows: std.ArrayList(bool),
    partial_draw_span_counts: std.ArrayList(u8),
    partial_draw_spans: std.ArrayList([render_cache_mod.max_row_dirty_spans]render_cache_mod.RowDirtySpan),
    partial_draw_cols_start: std.ArrayList(u16),
    partial_draw_cols_end: std.ArrayList(u16),
    /// Terminal presentable **pipeline** is ready to accept draws (one leg of
    /// `hostSharedSurfaceAttachmentReady`; not implied alone).
    terminal_presentable_ready: bool = false,
    /// Host reports a drawable **target** for the shared attachment (other leg).
    target_available: bool = false,
    /// Last **publication generation** applied to the terminal surface draw cache.
    last_render_generation: u64 = 0,
    /// Last **clear generation** applied to the terminal surface draw cache.
    last_render_clear_generation: u64 = 0,
    last_alt_active: bool = false,
    last_cell_w_i: i32 = 0,
    last_cell_h_i: i32 = 0,
    last_render_scale: f32 = 0,

    last_cursor_visible: bool = false,
    last_cursor_row: u16 = 0,
    last_cursor_col: u16 = 0,
    last_cursor_shape: u8 = 0,

    last_hover_link_id: u32 = 0,
    last_composing_active: bool = false,
    last_composing_hash: u64 = 0,
    invalidation_flags: InvalidationFlags = .{},

    pub const PresentationPartialDrawPlan = struct {
        rows: []bool,
        span_counts: []u8,
        spans: [][max_row_dirty_spans]RowDirtySpan,
        cols_start: []u16,
        cols_end: []u16,
    };

    pub fn init() PresentationState {
        return .{
            .partial_draw_rows = std.ArrayList(bool).empty,
            .partial_draw_span_counts = std.ArrayList(u8).empty,
            .partial_draw_spans = std.ArrayList([render_cache_mod.max_row_dirty_spans]render_cache_mod.RowDirtySpan).empty,
            .partial_draw_cols_start = std.ArrayList(u16).empty,
            .partial_draw_cols_end = std.ArrayList(u16).empty,
        };
    }

    pub fn deinit(self: *PresentationState, allocator: std.mem.Allocator) void {
        self.partial_draw_rows.deinit(allocator);
        self.partial_draw_span_counts.deinit(allocator);
        self.partial_draw_spans.deinit(allocator);
        self.partial_draw_cols_start.deinit(allocator);
        self.partial_draw_cols_end.deinit(allocator);
    }

    pub fn invalidatePresentationCache(self: *PresentationState, flags: InvalidationFlags) void {
        if (flags.geometry or flags.content or flags.overlay) {
            self.terminal_presentable_ready = false;
        }
        if (flags.availability) {
            self.target_available = false;
        }
        self.invalidation_flags.geometry = self.invalidation_flags.geometry or flags.geometry;
        self.invalidation_flags.content = self.invalidation_flags.content or flags.content;
        self.invalidation_flags.overlay = self.invalidation_flags.overlay or flags.overlay;
        self.invalidation_flags.availability = self.invalidation_flags.availability or flags.availability;
    }

    pub fn clearInvalidationFlags(self: *PresentationState) void {
        self.invalidation_flags = .{};
    }

    pub fn ensurePartialDrawPlan(self: *PresentationState, allocator: std.mem.Allocator, rows: usize) ?PresentationPartialDrawPlan {
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

test "availability invalidation does not discard cached presentation content" {
    var state = PresentationState.init();
    defer state.deinit(std.testing.allocator);

    state.terminal_presentable_ready = true;
    state.target_available = true;

    state.invalidatePresentationCache(.{ .availability = true });

    try std.testing.expect(state.terminal_presentable_ready);
    try std.testing.expect(!state.target_available);
    try std.testing.expect(state.invalidation_flags.availability);
}

test "geometry content and overlay invalidation discard cached presentation content" {
    inline for (.{ PresentationState.InvalidationFlags{ .geometry = true }, .{ .content = true }, .{ .overlay = true } }) |flags| {
        var state = PresentationState.init();
        defer state.deinit(std.testing.allocator);

        state.terminal_presentable_ready = true;
        state.target_available = true;

        state.invalidatePresentationCache(flags);

        try std.testing.expect(!state.terminal_presentable_ready);
        try std.testing.expect(state.target_available);
    }
}
