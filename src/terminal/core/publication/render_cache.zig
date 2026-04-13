const std = @import("std");
const screen_mod = @import("../../model/screen.zig");
const snapshot_mod = @import("snapshot.zig");
const types = @import("../../model/types.zig");

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
    sync_updates_active: bool,
    screen_reverse: bool,
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
            .sync_updates_active = false,
            .screen_reverse = false,
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

    pub fn totalLines(self: *const RenderCache) usize {
        return self.history_len + self.rows;
    }

    pub fn hasSelection(self: *const RenderCache) bool {
        for (self.selection_rows.items) |selected| {
            if (selected) return true;
        }
        return false;
    }

    pub const PublishedStateMatch = struct {
        rows: usize,
        cols: usize,
        history_len: usize,
        visible_history_generation: u64,
        scroll_offset: usize,
        generation: ?u64 = null,
        clear_generation: u64,
        alt_active: bool,
        selection_active: bool,
        sync_updates_active: bool,
        screen_reverse: bool,
        kitty_generation: u64,
        cursor: ?types.CursorPos = null,
        cursor_style: ?types.CursorStyle = null,
        cursor_visible: ?bool = null,
    };

    pub fn matchesPublishedState(self: *const RenderCache, expected: PublishedStateMatch) bool {
        if (self.rows != expected.rows or
            self.cols != expected.cols or
            self.history_len != expected.history_len or
            self.visible_history_generation != expected.visible_history_generation or
            self.scroll_offset != expected.scroll_offset or
            self.clear_generation != expected.clear_generation or
            self.alt_active != expected.alt_active or
            self.hasSelection() != expected.selection_active or
            self.sync_updates_active != expected.sync_updates_active or
            self.screen_reverse != expected.screen_reverse or
            self.kitty_generation != expected.kitty_generation)
        {
            return false;
        }
        if (expected.generation) |generation| {
            if (self.generation != generation) return false;
        }
        if (expected.cursor) |cursor| {
            if (!std.meta.eql(self.cursor, cursor)) return false;
        }
        if (expected.cursor_style) |cursor_style| {
            if (!std.meta.eql(self.cursor_style, cursor_style)) return false;
        }
        if (expected.cursor_visible) |cursor_visible| {
            if (self.cursor_visible != cursor_visible) return false;
        }
        return true;
    }
};

pub const SelectionBounds = struct {
    start_row: usize,
    end_row: usize,
    start_col: usize,
    end_col: usize,
};

pub fn selectionBounds(cache: *const RenderCache) ?SelectionBounds {
    if (cache.selection_rows.items.len == 0 or
        cache.selection_cols_start.items.len != cache.selection_rows.items.len or
        cache.selection_cols_end.items.len != cache.selection_rows.items.len)
    {
        return null;
    }

    var found = false;
    var min_row: usize = 0;
    var max_row: usize = 0;
    var min_col: usize = 0;
    var max_col: usize = 0;

    for (cache.selection_rows.items, 0..) |row_selected, row_idx| {
        if (!row_selected) continue;
        const row_start = @as(usize, cache.selection_cols_start.items[row_idx]);
        const row_end = @as(usize, cache.selection_cols_end.items[row_idx]);
        if (!found) {
            found = true;
            min_row = row_idx;
            max_row = row_idx;
            min_col = row_start;
            max_col = row_end;
            continue;
        }
        min_row = @min(min_row, row_idx);
        max_row = @max(max_row, row_idx);
        min_col = @min(min_col, row_start);
        max_col = @max(max_col, row_end);
    }

    if (!found) return null;
    return .{
        .start_row = min_row,
        .end_row = max_row,
        .start_col = min_col,
        .end_col = max_col,
    };
}

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
    dst.sync_updates_active = src.sync_updates_active;
    dst.screen_reverse = src.screen_reverse;
    dst.kitty_generation = src.kitty_generation;
    dst.clear_generation = src.clear_generation;
    dst.viewport_shift_rows = src.viewport_shift_rows;
    dst.viewport_shift_exposed_only = src.viewport_shift_exposed_only;
}

test "selectionBounds returns null when no visible selection exists" {
    var cache = RenderCache.init();
    defer cache.deinit(std.testing.allocator);

    try cache.selection_rows.resize(std.testing.allocator, 2);
    try cache.selection_cols_start.resize(std.testing.allocator, 2);
    try cache.selection_cols_end.resize(std.testing.allocator, 2);
    @memset(cache.selection_rows.items, false);
    @memset(cache.selection_cols_start.items, 0);
    @memset(cache.selection_cols_end.items, 0);

    try std.testing.expect(selectionBounds(&cache) == null);
}

test "selectionBounds returns bounding box across selected rows" {
    var cache = RenderCache.init();
    defer cache.deinit(std.testing.allocator);

    try cache.selection_rows.resize(std.testing.allocator, 3);
    try cache.selection_cols_start.resize(std.testing.allocator, 3);
    try cache.selection_cols_end.resize(std.testing.allocator, 3);

    cache.selection_rows.items[0] = false;
    cache.selection_rows.items[1] = true;
    cache.selection_rows.items[2] = true;

    cache.selection_cols_start.items[0] = 0;
    cache.selection_cols_start.items[1] = 2;
    cache.selection_cols_start.items[2] = 0;

    cache.selection_cols_end.items[0] = 0;
    cache.selection_cols_end.items[1] = 4;
    cache.selection_cols_end.items[2] = 6;

    const bounds = selectionBounds(&cache).?;
    try std.testing.expectEqual(@as(usize, 1), bounds.start_row);
    try std.testing.expectEqual(@as(usize, 2), bounds.end_row);
    try std.testing.expectEqual(@as(usize, 0), bounds.start_col);
    try std.testing.expectEqual(@as(usize, 6), bounds.end_col);
}
