const std = @import("std");
const types = @import("../types.zig");

pub const Dirty = enum {
    none,
    partial,
    full,
};

pub const FullDirtyReason = enum {
    unknown,
    init,
    resize,
    screen_mark_dirty_api,
    screen_reverse_mode_toggle,
    screen_clear,
    erase_display_full,
    palette_default_changed,
    palette_ansi_changed,
    alt_enter,
    alt_exit,
    session_mark_dirty_api,
    sync_updates_disabled,
    decstr_soft_reset,
    scrollback_view_offset_change,
    resize_reflow,
    kitty_graphics_changed,
};

pub const Damage = struct {
    start_row: usize,
    end_row: usize,
    start_col: usize,
    end_col: usize,
};

pub const TerminalGrid = struct {
    allocator: std.mem.Allocator,
    rows: u16,
    cols: u16,
    cells: std.ArrayList(types.Cell),
    wrap_flags: std.ArrayList(bool),
    dirty_rows: std.ArrayList(bool),
    dirty_cols_start: std.ArrayList(u16),
    dirty_cols_end: std.ArrayList(u16),
    dirty: Dirty,
    damage: Damage,
    full_dirty_reason: FullDirtyReason,
    full_dirty_seq: u64,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16, default_cell: types.Cell) !TerminalGrid {
        var cells = std.ArrayList(types.Cell).empty;
        var wrap_flags = std.ArrayList(bool).empty;
        var dirty_rows = std.ArrayList(bool).empty;
        var dirty_cols_start = std.ArrayList(u16).empty;
        var dirty_cols_end = std.ArrayList(u16).empty;
        const count = @as(usize, rows) * @as(usize, cols);
        try cells.resize(allocator, count);
        try wrap_flags.resize(allocator, rows);
        try dirty_rows.resize(allocator, rows);
        try dirty_cols_start.resize(allocator, rows);
        try dirty_cols_end.resize(allocator, rows);
        for (cells.items) |*cell| {
            cell.* = default_cell;
        }
        for (wrap_flags.items) |*flag| {
            flag.* = false;
        }
        for (dirty_rows.items) |*row_dirty| {
            row_dirty.* = true;
        }
        for (dirty_cols_start.items, dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = 0;
            col_end.* = if (cols > 0) cols - 1 else 0;
        }
        return .{
            .allocator = allocator,
            .rows = rows,
            .cols = cols,
            .cells = cells,
            .wrap_flags = wrap_flags,
            .dirty_rows = dirty_rows,
            .dirty_cols_start = dirty_cols_start,
            .dirty_cols_end = dirty_cols_end,
            .dirty = .full,
            .damage = .{
                .start_row = 0,
                .end_row = if (rows > 0) @as(usize, rows - 1) else 0,
                .start_col = 0,
                .end_col = if (cols > 0) @as(usize, cols - 1) else 0,
            },
            .full_dirty_reason = .init,
            .full_dirty_seq = 1,
        };
    }

    pub fn deinit(self: *TerminalGrid) void {
        self.cells.deinit(self.allocator);
        self.wrap_flags.deinit(self.allocator);
        self.dirty_rows.deinit(self.allocator);
        self.dirty_cols_start.deinit(self.allocator);
        self.dirty_cols_end.deinit(self.allocator);
    }

    pub fn resize(self: *TerminalGrid, rows: u16, cols: u16, default_cell: types.Cell) !void {
        if (self.rows == rows and self.cols == cols) return;
        const old_rows = self.rows;
        const old_cols = self.cols;
        const old_cells = self.cells;
        const old_wraps = self.wrap_flags;

        var new_cells = std.ArrayList(types.Cell).empty;
        var new_wraps = std.ArrayList(bool).empty;
        var new_dirty_rows = std.ArrayList(bool).empty;
        var new_dirty_cols_start = std.ArrayList(u16).empty;
        var new_dirty_cols_end = std.ArrayList(u16).empty;
        const count = @as(usize, rows) * @as(usize, cols);
        try new_cells.resize(self.allocator, count);
        try new_wraps.resize(self.allocator, rows);
        try new_dirty_rows.resize(self.allocator, rows);
        try new_dirty_cols_start.resize(self.allocator, rows);
        try new_dirty_cols_end.resize(self.allocator, rows);

        for (new_cells.items) |*cell| {
            cell.* = default_cell;
        }
        for (new_wraps.items) |*flag| {
            flag.* = false;
        }

        const copy_rows = @min(@as(usize, old_rows), @as(usize, rows));
        const copy_cols = @min(@as(usize, old_cols), @as(usize, cols));
        if (copy_rows > 0 and copy_cols > 0 and old_cells.items.len > 0) {
            var row: usize = 0;
            while (row < copy_rows) : (row += 1) {
                const old_start = row * @as(usize, old_cols);
                const new_start = row * @as(usize, cols);
                std.mem.copyForwards(
                    types.Cell,
                    new_cells.items[new_start .. new_start + copy_cols],
                    old_cells.items[old_start .. old_start + copy_cols],
                );
                if (row < old_wraps.items.len) {
                    new_wraps.items[row] = old_wraps.items[row];
                }
            }
        }

        for (new_dirty_rows.items) |*row_dirty| {
            row_dirty.* = true;
        }
        for (new_dirty_cols_start.items, new_dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = 0;
            col_end.* = if (cols > 0) cols - 1 else 0;
        }

        self.cells.deinit(self.allocator);
        self.wrap_flags.deinit(self.allocator);
        self.dirty_rows.deinit(self.allocator);
        self.dirty_cols_start.deinit(self.allocator);
        self.dirty_cols_end.deinit(self.allocator);
        self.cells = new_cells;
        self.wrap_flags = new_wraps;
        self.dirty_rows = new_dirty_rows;
        self.dirty_cols_start = new_dirty_cols_start;
        self.dirty_cols_end = new_dirty_cols_end;
        self.rows = rows;
        self.cols = cols;
        self.markDirtyAll();
    }

    pub fn setRowWrapped(self: *TerminalGrid, row: usize, wrapped: bool) void {
        if (row >= self.wrap_flags.items.len) return;
        self.wrap_flags.items[row] = wrapped;
    }

    pub fn rowWrapped(self: *const TerminalGrid, row: usize) bool {
        if (row >= self.wrap_flags.items.len) return false;
        return self.wrap_flags.items[row];
    }

    fn setAllDirtyRows(self: *TerminalGrid, value: bool) void {
        for (self.dirty_rows.items) |*row_dirty| {
            row_dirty.* = value;
        }
    }

    fn setAllDirtyCols(self: *TerminalGrid, start: u16, end: u16) void {
        for (self.dirty_cols_start.items, self.dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = start;
            col_end.* = end;
        }
    }

    pub fn markDirtyRange(self: *TerminalGrid, start_row: usize, end_row: usize, start_col: usize, end_col: usize) void {
        if (self.rows == 0 or self.cols == 0) return;
        const max_row = @as(usize, self.rows - 1);
        const max_col = @as(usize, self.cols - 1);
        const row_start = @min(start_row, max_row);
        const row_end = @min(end_row, max_row);
        const col_start = @min(start_col, max_col);
        const col_end = @min(end_col, max_col);
        if (row_start > row_end or col_start > col_end) return;

        if (self.dirty != .full) {
            if (self.dirty == .none) {
                self.dirty = .partial;
                self.damage = .{
                    .start_row = row_start,
                    .end_row = row_end,
                    .start_col = col_start,
                    .end_col = col_end,
                };
            } else {
                self.damage.start_row = @min(self.damage.start_row, row_start);
                self.damage.end_row = @max(self.damage.end_row, row_end);
                self.damage.start_col = @min(self.damage.start_col, col_start);
                self.damage.end_col = @max(self.damage.end_col, col_end);
            }
        }

        for (row_start..row_end + 1) |row| {
            self.dirty_rows.items[row] = true;
            const col_start_u16: u16 = @intCast(col_start);
            const col_end_u16: u16 = @intCast(col_end);
            if (self.dirty_cols_start.items[row] > col_start_u16) {
                self.dirty_cols_start.items[row] = col_start_u16;
            }
            if (self.dirty_cols_end.items[row] < col_end_u16) {
                self.dirty_cols_end.items[row] = col_end_u16;
            }
        }
    }

    pub fn markDirtyAll(self: *TerminalGrid) void {
        self.markDirtyAllWithReason(.unknown);
    }

    pub fn markDirtyAllWithReason(self: *TerminalGrid, reason: FullDirtyReason) void {
        self.dirty = .full;
        self.damage = .{
            .start_row = 0,
            .end_row = if (self.rows > 0) @as(usize, self.rows - 1) else 0,
            .start_col = 0,
            .end_col = if (self.cols > 0) @as(usize, self.cols - 1) else 0,
        };
        self.full_dirty_reason = reason;
        self.full_dirty_seq +%= 1;
        self.setAllDirtyRows(true);
        if (self.cols > 0) {
            self.setAllDirtyCols(0, self.cols - 1);
        } else {
            self.setAllDirtyCols(0, 0);
        }
    }

    pub fn clearDirty(self: *TerminalGrid) void {
        self.dirty = .none;
        self.setAllDirtyRows(false);
        const invalid_start = self.cols;
        for (self.dirty_cols_start.items, self.dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = invalid_start;
            col_end.* = 0;
        }
        self.damage = .{
            .start_row = 0,
            .end_row = 0,
            .start_col = 0,
            .end_col = 0,
        };
    }
};
