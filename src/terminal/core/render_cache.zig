const std = @import("std");
const screen_mod = @import("../model/screen.zig");
const snapshot_mod = @import("snapshot.zig");
const types = @import("../model/types.zig");

const Cell = types.Cell;
const Dirty = screen_mod.Dirty;
const Damage = screen_mod.Damage;
const FullDirtyReason = screen_mod.FullDirtyReason;
pub const RowDirtySpan = screen_mod.RowDirtySpan;
pub const max_row_dirty_spans = screen_mod.max_row_dirty_spans;

pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

pub const RenderCache = struct {
    cells: std.ArrayList(Cell),
    dirty_rows: std.ArrayList(bool),
    row_dirty_span_counts: std.ArrayList(u8),
    row_dirty_span_overflow: std.ArrayList(bool),
    row_dirty_spans: std.ArrayList([max_row_dirty_spans]RowDirtySpan),
    dirty_cols_start: std.ArrayList(u16),
    dirty_cols_end: std.ArrayList(u16),
    selection_rows: std.ArrayList(bool),
    selection_cols_start: std.ArrayList(u16),
    selection_cols_end: std.ArrayList(u16),
    row_hashes: std.ArrayList(u64),
    kitty_images: std.ArrayList(KittyImage),
    kitty_placements: std.ArrayList(KittyPlacement),
    rows: usize,
    cols: usize,
    history_len: usize,
    total_lines: usize,
    visible_history_generation: u64,
    generation: u64,
    scroll_offset: usize,
    cursor: types.CursorPos,
    cursor_style: types.CursorStyle,
    cursor_visible: bool,
    has_blink: bool,
    dirty: Dirty,
    damage: Damage,
    full_dirty_reason: FullDirtyReason,
    full_dirty_seq: u64,
    alt_active: bool,
    selection_active: bool,
    sync_updates_active: bool,
    screen_reverse: bool,
    mouse_reporting_active: bool,
    kitty_generation: u64,
    clear_generation: u64,
    viewport_shift_rows: i32,
    viewport_shift_exposed_only: bool,

    pub fn init() RenderCache {
        return .{
            .cells = std.ArrayList(Cell).empty,
            .dirty_rows = std.ArrayList(bool).empty,
            .row_dirty_span_counts = std.ArrayList(u8).empty,
            .row_dirty_span_overflow = std.ArrayList(bool).empty,
            .row_dirty_spans = std.ArrayList([max_row_dirty_spans]RowDirtySpan).empty,
            .dirty_cols_start = std.ArrayList(u16).empty,
            .dirty_cols_end = std.ArrayList(u16).empty,
            .selection_rows = std.ArrayList(bool).empty,
            .selection_cols_start = std.ArrayList(u16).empty,
            .selection_cols_end = std.ArrayList(u16).empty,
            .row_hashes = std.ArrayList(u64).empty,
            .kitty_images = std.ArrayList(KittyImage).empty,
            .kitty_placements = std.ArrayList(KittyPlacement).empty,
            .rows = 0,
            .cols = 0,
            .history_len = 0,
            .total_lines = 0,
            .visible_history_generation = 0,
            .generation = 0,
            .scroll_offset = 0,
            .cursor = .{ .row = 0, .col = 0 },
            .cursor_style = types.default_cursor_style,
            .cursor_visible = false,
            .has_blink = false,
            .dirty = .none,
            .damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 },
            .full_dirty_reason = .unknown,
            .full_dirty_seq = 0,
            .alt_active = false,
            .selection_active = false,
            .sync_updates_active = false,
            .screen_reverse = false,
            .mouse_reporting_active = false,
            .kitty_generation = 0,
            .clear_generation = 0,
            .viewport_shift_rows = 0,
            .viewport_shift_exposed_only = false,
        };
    }

    pub fn deinit(self: *RenderCache, allocator: std.mem.Allocator) void {
        self.cells.deinit(allocator);
        self.dirty_rows.deinit(allocator);
        self.row_dirty_span_counts.deinit(allocator);
        self.row_dirty_span_overflow.deinit(allocator);
        self.row_dirty_spans.deinit(allocator);
        self.dirty_cols_start.deinit(allocator);
        self.dirty_cols_end.deinit(allocator);
        self.selection_rows.deinit(allocator);
        self.selection_cols_start.deinit(allocator);
        self.selection_cols_end.deinit(allocator);
        self.row_hashes.deinit(allocator);
        self.kitty_images.deinit(allocator);
        self.kitty_placements.deinit(allocator);
    }
};

pub fn copySnapshot(dst: *RenderCache, allocator: std.mem.Allocator, src: *const RenderCache) !void {
    try dst.cells.resize(allocator, src.cells.items.len);
    std.mem.copyForwards(Cell, dst.cells.items, src.cells.items);

    try dst.dirty_rows.resize(allocator, src.dirty_rows.items.len);
    std.mem.copyForwards(bool, dst.dirty_rows.items, src.dirty_rows.items);

    try dst.row_dirty_span_counts.resize(allocator, src.row_dirty_span_counts.items.len);
    std.mem.copyForwards(u8, dst.row_dirty_span_counts.items, src.row_dirty_span_counts.items);

    try dst.row_dirty_span_overflow.resize(allocator, src.row_dirty_span_overflow.items.len);
    std.mem.copyForwards(bool, dst.row_dirty_span_overflow.items, src.row_dirty_span_overflow.items);

    try dst.row_dirty_spans.resize(allocator, src.row_dirty_spans.items.len);
    std.mem.copyForwards([max_row_dirty_spans]RowDirtySpan, dst.row_dirty_spans.items, src.row_dirty_spans.items);

    try dst.dirty_cols_start.resize(allocator, src.dirty_cols_start.items.len);
    std.mem.copyForwards(u16, dst.dirty_cols_start.items, src.dirty_cols_start.items);

    try dst.dirty_cols_end.resize(allocator, src.dirty_cols_end.items.len);
    std.mem.copyForwards(u16, dst.dirty_cols_end.items, src.dirty_cols_end.items);

    try dst.selection_rows.resize(allocator, src.selection_rows.items.len);
    std.mem.copyForwards(bool, dst.selection_rows.items, src.selection_rows.items);

    try dst.selection_cols_start.resize(allocator, src.selection_cols_start.items.len);
    std.mem.copyForwards(u16, dst.selection_cols_start.items, src.selection_cols_start.items);

    try dst.selection_cols_end.resize(allocator, src.selection_cols_end.items.len);
    std.mem.copyForwards(u16, dst.selection_cols_end.items, src.selection_cols_end.items);

    try dst.row_hashes.resize(allocator, src.row_hashes.items.len);
    std.mem.copyForwards(u64, dst.row_hashes.items, src.row_hashes.items);

    try dst.kitty_images.resize(allocator, src.kitty_images.items.len);
    std.mem.copyForwards(KittyImage, dst.kitty_images.items, src.kitty_images.items);

    try dst.kitty_placements.resize(allocator, src.kitty_placements.items.len);
    std.mem.copyForwards(KittyPlacement, dst.kitty_placements.items, src.kitty_placements.items);

    dst.rows = src.rows;
    dst.cols = src.cols;
    dst.history_len = src.history_len;
    dst.total_lines = src.total_lines;
    dst.visible_history_generation = src.visible_history_generation;
    dst.generation = src.generation;
    dst.scroll_offset = src.scroll_offset;
    dst.cursor = src.cursor;
    dst.cursor_style = src.cursor_style;
    dst.cursor_visible = src.cursor_visible;
    dst.has_blink = src.has_blink;
    dst.dirty = src.dirty;
    dst.damage = src.damage;
    dst.full_dirty_reason = src.full_dirty_reason;
    dst.full_dirty_seq = src.full_dirty_seq;
    dst.alt_active = src.alt_active;
    dst.selection_active = src.selection_active;
    dst.sync_updates_active = src.sync_updates_active;
    dst.screen_reverse = src.screen_reverse;
    dst.mouse_reporting_active = src.mouse_reporting_active;
    dst.kitty_generation = src.kitty_generation;
    dst.clear_generation = src.clear_generation;
    dst.viewport_shift_rows = src.viewport_shift_rows;
    dst.viewport_shift_exposed_only = src.viewport_shift_exposed_only;
}
