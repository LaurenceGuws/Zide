const std = @import("std");
const screen_mod = @import("../model/screen.zig");
const snapshot_mod = @import("snapshot.zig");
const types = @import("../model/types.zig");

const Cell = types.Cell;
const Dirty = screen_mod.Dirty;
const Damage = screen_mod.Damage;
const FullDirtyReason = screen_mod.FullDirtyReason;

pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

pub const RenderCache = struct {
    cells: std.ArrayList(Cell),
    dirty_rows: std.ArrayList(bool),
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
    kitty_generation: u64,
    clear_generation: u64,
    viewport_shift_rows: i32,

    pub fn init() RenderCache {
        return .{
            .cells = std.ArrayList(Cell).empty,
            .dirty_rows = std.ArrayList(bool).empty,
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
            .kitty_generation = 0,
            .clear_generation = 0,
            .viewport_shift_rows = 0,
        };
    }

    pub fn deinit(self: *RenderCache, allocator: std.mem.Allocator) void {
        self.cells.deinit(allocator);
        self.dirty_rows.deinit(allocator);
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
