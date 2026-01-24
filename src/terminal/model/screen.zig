const std = @import("std");
const types = @import("types.zig");

pub const Dirty = enum {
    none,
    partial,
    full,
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
    dirty_rows: std.ArrayList(bool),
    dirty_cols_start: std.ArrayList(u16),
    dirty_cols_end: std.ArrayList(u16),
    dirty: Dirty,
    damage: Damage,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16, default_cell: types.Cell) !TerminalGrid {
        var cells = std.ArrayList(types.Cell).empty;
        var dirty_rows = std.ArrayList(bool).empty;
        var dirty_cols_start = std.ArrayList(u16).empty;
        var dirty_cols_end = std.ArrayList(u16).empty;
        const count = @as(usize, rows) * @as(usize, cols);
        try cells.resize(allocator, count);
        try dirty_rows.resize(allocator, rows);
        try dirty_cols_start.resize(allocator, rows);
        try dirty_cols_end.resize(allocator, rows);
        for (cells.items) |*cell| {
            cell.* = default_cell;
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
        };
    }

    pub fn deinit(self: *TerminalGrid) void {
        self.cells.deinit(self.allocator);
        self.dirty_rows.deinit(self.allocator);
        self.dirty_cols_start.deinit(self.allocator);
        self.dirty_cols_end.deinit(self.allocator);
    }

    pub fn resize(self: *TerminalGrid, rows: u16, cols: u16, default_cell: types.Cell) !void {
        if (self.rows == rows and self.cols == cols) return;
        const old_rows = self.rows;
        const old_cols = self.cols;
        const old_cells = self.cells;

        var new_cells = std.ArrayList(types.Cell).empty;
        var new_dirty_rows = std.ArrayList(bool).empty;
        var new_dirty_cols_start = std.ArrayList(u16).empty;
        var new_dirty_cols_end = std.ArrayList(u16).empty;
        const count = @as(usize, rows) * @as(usize, cols);
        try new_cells.resize(self.allocator, count);
        try new_dirty_rows.resize(self.allocator, rows);
        try new_dirty_cols_start.resize(self.allocator, rows);
        try new_dirty_cols_end.resize(self.allocator, rows);

        for (new_cells.items) |*cell| {
            cell.* = default_cell;
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
        self.dirty_rows.deinit(self.allocator);
        self.dirty_cols_start.deinit(self.allocator);
        self.dirty_cols_end.deinit(self.allocator);
        self.cells = new_cells;
        self.dirty_rows = new_dirty_rows;
        self.dirty_cols_start = new_dirty_cols_start;
        self.dirty_cols_end = new_dirty_cols_end;
        self.rows = rows;
        self.cols = cols;
        self.markDirtyAll();
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
        self.dirty = .full;
        self.damage = .{
            .start_row = 0,
            .end_row = if (self.rows > 0) @as(usize, self.rows - 1) else 0,
            .start_col = 0,
            .end_col = if (self.cols > 0) @as(usize, self.cols - 1) else 0,
        };
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

pub const TabStops = struct {
    allocator: std.mem.Allocator,
    stops: std.ArrayList(bool),

    pub fn init(allocator: std.mem.Allocator, cols: u16) !TabStops {
        var stops = std.ArrayList(bool).empty;
        try stops.resize(allocator, cols);
        var tabstops = TabStops{
            .allocator = allocator,
            .stops = stops,
        };
        tabstops.reset();
        return tabstops;
    }

    pub fn deinit(self: *TabStops) void {
        self.stops.deinit(self.allocator);
    }

    pub fn resize(self: *TabStops, cols: u16) !void {
        const old_len = self.stops.items.len;
        try self.stops.resize(self.allocator, cols);
        if (cols > old_len) {
            var idx: usize = old_len;
            while (idx < cols) : (idx += 1) {
                self.stops.items[idx] = TabStops.defaultStop(idx);
            }
        }
    }

    pub fn reset(self: *TabStops) void {
        for (self.stops.items, 0..) |*stop, idx| {
            stop.* = TabStops.defaultStop(idx);
        }
    }

    pub fn next(self: *const TabStops, col: usize, max_col: usize) usize {
        if (self.stops.items.len == 0) return col;
        var idx = col + 1;
        const limit = @min(max_col, self.stops.items.len - 1);
        while (idx <= limit) : (idx += 1) {
            if (self.stops.items[idx]) return idx;
        }
        return max_col;
    }

    fn defaultStop(col: usize) bool {
        return (col % 8) == 0;
    }
};

pub const Screen = struct {
    grid: TerminalGrid,
    cursor: types.CursorPos,
    cursor_style: types.CursorStyle,
    cursor_visible: bool,
    saved_cursor: SavedCursor,
    scroll_top: usize,
    scroll_bottom: usize,
    tabstops: TabStops,
    key_mode: KeyModeStack,
    current_attrs: types.CellAttrs,
    default_attrs: types.CellAttrs,
    wrap_next: bool,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16, default_attrs: types.CellAttrs) !Screen {
        const grid = try TerminalGrid.init(allocator, rows, cols, .{
            .codepoint = 0,
            .width = 1,
            .attrs = default_attrs,
        });
        const tabstops = try TabStops.init(allocator, cols);
        return .{
            .grid = grid,
            .cursor = .{ .row = 0, .col = 0 },
            .cursor_style = types.default_cursor_style,
            .cursor_visible = true,
            .saved_cursor = .{ .active = false, .cursor = .{ .row = 0, .col = 0 }, .attrs = default_attrs },
            .scroll_top = 0,
            .scroll_bottom = if (rows > 0) @as(usize, rows - 1) else 0,
            .tabstops = tabstops,
            .key_mode = KeyModeStack.init(),
            .current_attrs = default_attrs,
            .default_attrs = default_attrs,
            .wrap_next = false,
        };
    }

    pub fn deinit(self: *Screen) void {
        self.grid.deinit();
        self.tabstops.deinit();
    }

    pub fn resize(self: *Screen, rows: u16, cols: u16) !void {
        const old_rows = self.grid.rows;
        const old_cols = self.grid.cols;
        const was_full_region = old_rows > 0 and self.scroll_top == 0 and self.scroll_bottom + 1 == @as(usize, old_rows);
        try self.grid.resize(rows, cols, .{
            .codepoint = 0,
            .width = 1,
            .attrs = self.default_attrs,
        });
        if (cols != old_cols) {
            try self.tabstops.resize(cols);
        }
        if (rows > 0) {
            if (self.scroll_top >= @as(usize, rows)) self.scroll_top = 0;
            if (self.scroll_bottom >= @as(usize, rows)) self.scroll_bottom = @as(usize, rows - 1);
            if (self.scroll_top > self.scroll_bottom) {
                self.scroll_top = 0;
                self.scroll_bottom = @as(usize, rows - 1);
            }
            if (was_full_region) {
                self.scroll_top = 0;
                self.scroll_bottom = @as(usize, rows - 1);
            }
        } else {
            self.scroll_top = 0;
            self.scroll_bottom = 0;
        }
        const max_row = if (rows > 0) @as(usize, rows - 1) else 0;
        const max_col = if (cols > 0) @as(usize, cols - 1) else 0;
        if (self.cursor.row > max_row) self.cursor.row = max_row;
        if (self.cursor.col > max_col) self.cursor.col = max_col;
    }

    pub fn resetState(self: *Screen) void {
        self.cursor = .{ .row = 0, .col = 0 };
        self.cursor_style = types.default_cursor_style;
        self.cursor_visible = true;
        self.saved_cursor = .{ .active = false, .cursor = .{ .row = 0, .col = 0 }, .attrs = self.default_attrs };
        self.scroll_top = 0;
        self.scroll_bottom = if (self.grid.rows > 0) @as(usize, self.grid.rows - 1) else 0;
        self.key_mode = KeyModeStack.init();
        self.current_attrs = self.default_attrs;
        self.wrap_next = false;
        self.tabstops.reset();
    }

    pub fn blankCell(self: *const Screen) types.Cell {
        return .{
            .codepoint = 0,
            .width = 1,
            .attrs = self.current_attrs,
        };
    }

    pub fn defaultCell(self: *const Screen) types.Cell {
        return .{
            .codepoint = 0,
            .width = 1,
            .attrs = self.default_attrs,
        };
    }

    pub fn isFullScrollRegion(self: *const Screen) bool {
        const rows = @as(usize, self.grid.rows);
        if (rows == 0) return false;
        return self.scroll_top == 0 and self.scroll_bottom + 1 == rows;
    }

    pub fn setCursorStyle(self: *Screen, mode: i32) void {
        const style = switch (mode) {
            0, 1 => types.CursorStyle{ .shape = .block, .blink = true },
            2 => types.CursorStyle{ .shape = .block, .blink = false },
            3 => types.CursorStyle{ .shape = .underline, .blink = true },
            4 => types.CursorStyle{ .shape = .underline, .blink = false },
            5 => types.CursorStyle{ .shape = .bar, .blink = true },
            6 => types.CursorStyle{ .shape = .bar, .blink = false },
            else => self.cursor_style,
        };
        self.cursor_style = style;
    }

    pub fn saveCursor(self: *Screen) void {
        const slot = &self.saved_cursor;
        slot.active = true;
        slot.cursor = self.cursor;
        slot.attrs = self.current_attrs;
    }

    pub fn restoreCursor(self: *Screen) void {
        const slot = &self.saved_cursor;
        if (!slot.active) return;
        self.cursor = slot.cursor;
        self.current_attrs = slot.attrs;
    }

    pub fn keyModeStack(self: *Screen) *KeyModeStack {
        return &self.key_mode;
    }

    pub fn keyModeFlags(self: *const Screen) u32 {
        return self.key_mode.current();
    }

    pub fn keyModePush(self: *Screen, flags: u32) void {
        self.key_mode.push(flags);
    }

    pub fn keyModePop(self: *Screen, count: usize) void {
        self.key_mode.pop(count);
    }

    pub fn keyModeModify(self: *Screen, flags: u32, mode: u32) void {
        const current = self.key_mode.current();
        const updated = switch (mode) {
            2 => current | flags,
            3 => current & ~flags,
            else => flags,
        };
        self.key_mode.setCurrent(updated);
    }

    pub fn clear(self: *Screen) void {
        const default_cell = types.Cell{
            .codepoint = 0,
            .width = 1,
            .attrs = self.default_attrs,
        };
        for (self.grid.cells.items) |*cell| {
            cell.* = default_cell;
        }
        self.grid.markDirtyAll();
    }

    pub fn eraseDisplay(self: *Screen, mode: i32, blank_cell: types.Cell) void {
        const rows = @as(usize, self.grid.rows);
        const cols = @as(usize, self.grid.cols);
        if (rows == 0 or cols == 0) return;
        const row = self.cursor.row;
        const col = self.cursor.col;
        if (row >= rows or col >= cols) return;

        switch (mode) {
            0 => { // cursor to end
                const start_idx = row * cols + col;
                for (self.grid.cells.items[start_idx..]) |*cell| cell.* = blank_cell;
                self.grid.markDirtyRange(row, row, col, cols - 1);
                if (row + 1 < rows) {
                    self.grid.markDirtyRange(row + 1, rows - 1, 0, cols - 1);
                }
            },
            1 => { // start to cursor
                const end = row * cols + col + 1;
                for (self.grid.cells.items[0..end]) |*cell| cell.* = blank_cell;
                if (row > 0) {
                    self.grid.markDirtyRange(0, row - 1, 0, cols - 1);
                }
                self.grid.markDirtyRange(row, row, 0, col);
            },
            2 => { // all
                for (self.grid.cells.items) |*cell| cell.* = blank_cell;
                self.grid.markDirtyAll();
            },
            else => {},
        }
    }

    pub fn eraseLine(self: *Screen, mode: i32, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return;
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const row_start = self.cursor.row * cols;
        const col = self.cursor.col;
        if (col >= cols) return;
        switch (mode) {
            0 => { // cursor to end of line
                for (self.grid.cells.items[row_start + col .. row_start + cols]) |*cell| cell.* = blank_cell;
                self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, cols - 1);
            },
            1 => { // start to cursor
                for (self.grid.cells.items[row_start .. row_start + col + 1]) |*cell| cell.* = blank_cell;
                self.grid.markDirtyRange(self.cursor.row, self.cursor.row, 0, col);
            },
            2 => { // entire line
                for (self.grid.cells.items[row_start .. row_start + cols]) |*cell| cell.* = blank_cell;
                self.grid.markDirtyRange(self.cursor.row, self.cursor.row, 0, cols - 1);
            },
            else => {},
        }
    }

    pub fn insertChars(self: *Screen, count: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0) return;
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const col = self.cursor.col;
        if (col >= cols) return;
        const n = @min(count, cols - col);
        const row_start = self.cursor.row * cols;
        const line = self.grid.cells.items[row_start .. row_start + cols];
        if (cols - col > n) {
            std.mem.copyBackwards(types.Cell, line[col + n ..], line[col .. cols - n]);
        }
        for (line[col .. col + n]) |*cell| cell.* = blank_cell;
        self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, cols - 1);
    }

    pub fn deleteChars(self: *Screen, count: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0) return;
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const col = self.cursor.col;
        if (col >= cols) return;
        const n = @min(count, cols - col);
        const row_start = self.cursor.row * cols;
        const line = self.grid.cells.items[row_start .. row_start + cols];
        if (cols - col > n) {
            std.mem.copyForwards(types.Cell, line[col .. cols - n], line[col + n ..]);
        }
        for (line[cols - n .. cols]) |*cell| cell.* = blank_cell;
        self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, cols - 1);
    }

    pub fn eraseChars(self: *Screen, count: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0) return;
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const col = self.cursor.col;
        if (col >= cols) return;
        const n = @min(count, cols - col);
        const row_start = self.cursor.row * cols;
        const line = self.grid.cells.items[row_start .. row_start + cols];
        for (line[col .. col + n]) |*cell| cell.* = blank_cell;
        self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, col + n - 1);
    }

    pub fn insertLines(self: *Screen, count: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        const rows = @as(usize, self.grid.rows);
        if (rows == 0 or cols == 0) return;
        if (self.cursor.row < self.scroll_top or self.cursor.row > self.scroll_bottom) return;
        const n = @min(count, self.scroll_bottom - self.cursor.row + 1);
        const region_end = (self.scroll_bottom + 1) * cols;
        const insert_at = self.cursor.row * cols;
        const move_len = region_end - insert_at - n * cols;
        if (move_len > 0) {
            std.mem.copyBackwards(types.Cell, self.grid.cells.items[insert_at + n * cols .. region_end], self.grid.cells.items[insert_at .. insert_at + move_len]);
        }
        for (self.grid.cells.items[insert_at .. insert_at + n * cols]) |*cell| cell.* = blank_cell;
        self.grid.markDirtyRange(self.cursor.row, self.scroll_bottom, 0, cols - 1);
    }

    pub fn deleteLines(self: *Screen, count: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        const rows = @as(usize, self.grid.rows);
        if (rows == 0 or cols == 0) return;
        if (self.cursor.row < self.scroll_top or self.cursor.row > self.scroll_bottom) return;
        const n = @min(count, self.scroll_bottom - self.cursor.row + 1);
        const region_end = (self.scroll_bottom + 1) * cols;
        const delete_at = self.cursor.row * cols;
        const move_len = region_end - delete_at - n * cols;
        if (move_len > 0) {
            std.mem.copyForwards(types.Cell, self.grid.cells.items[delete_at .. delete_at + move_len], self.grid.cells.items[delete_at + n * cols .. region_end]);
        }
        for (self.grid.cells.items[region_end - n * cols .. region_end]) |*cell| cell.* = blank_cell;
        self.grid.markDirtyRange(self.cursor.row, self.scroll_bottom, 0, cols - 1);
    }

    pub fn updateDefaultColors(self: *Screen, old_attrs: types.CellAttrs, new_attrs: types.CellAttrs) void {
        self.default_attrs = new_attrs;

        if (self.current_attrs.fg.r == old_attrs.fg.r and
            self.current_attrs.fg.g == old_attrs.fg.g and
            self.current_attrs.fg.b == old_attrs.fg.b and
            self.current_attrs.fg.a == old_attrs.fg.a and
            self.current_attrs.bg.r == old_attrs.bg.r and
            self.current_attrs.bg.g == old_attrs.bg.g and
            self.current_attrs.bg.b == old_attrs.bg.b and
            self.current_attrs.bg.a == old_attrs.bg.a and
            self.current_attrs.underline_color.r == old_attrs.underline_color.r and
            self.current_attrs.underline_color.g == old_attrs.underline_color.g and
            self.current_attrs.underline_color.b == old_attrs.underline_color.b and
            self.current_attrs.underline_color.a == old_attrs.underline_color.a)
        {
            self.current_attrs.fg = new_attrs.fg;
            self.current_attrs.bg = new_attrs.bg;
            self.current_attrs.underline_color = new_attrs.underline_color;
        }

        if (self.saved_cursor.attrs.fg.r == old_attrs.fg.r and
            self.saved_cursor.attrs.fg.g == old_attrs.fg.g and
            self.saved_cursor.attrs.fg.b == old_attrs.fg.b and
            self.saved_cursor.attrs.fg.a == old_attrs.fg.a and
            self.saved_cursor.attrs.bg.r == old_attrs.bg.r and
            self.saved_cursor.attrs.bg.g == old_attrs.bg.g and
            self.saved_cursor.attrs.bg.b == old_attrs.bg.b and
            self.saved_cursor.attrs.bg.a == old_attrs.bg.a and
            self.saved_cursor.attrs.underline_color.r == old_attrs.underline_color.r and
            self.saved_cursor.attrs.underline_color.g == old_attrs.underline_color.g and
            self.saved_cursor.attrs.underline_color.b == old_attrs.underline_color.b and
            self.saved_cursor.attrs.underline_color.a == old_attrs.underline_color.a)
        {
            self.saved_cursor.attrs.fg = new_attrs.fg;
            self.saved_cursor.attrs.bg = new_attrs.bg;
            self.saved_cursor.attrs.underline_color = new_attrs.underline_color;
        }

        for (self.grid.cells.items) |*cell| {
            if (cell.attrs.fg.r == old_attrs.fg.r and
                cell.attrs.fg.g == old_attrs.fg.g and
                cell.attrs.fg.b == old_attrs.fg.b and
                cell.attrs.fg.a == old_attrs.fg.a and
                cell.attrs.bg.r == old_attrs.bg.r and
                cell.attrs.bg.g == old_attrs.bg.g and
                cell.attrs.bg.b == old_attrs.bg.b and
                cell.attrs.bg.a == old_attrs.bg.a and
                cell.attrs.underline_color.r == old_attrs.underline_color.r and
                cell.attrs.underline_color.g == old_attrs.underline_color.g and
                cell.attrs.underline_color.b == old_attrs.underline_color.b and
                cell.attrs.underline_color.a == old_attrs.underline_color.a)
            {
                cell.attrs.fg = new_attrs.fg;
                cell.attrs.bg = new_attrs.bg;
                cell.attrs.underline_color = new_attrs.underline_color;
            }
        }
        self.grid.markDirtyAll();
    }

    pub fn scrollRegionUpBy(self: *Screen, n: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return;
        if (n == 0) return;
        const region_start = self.scroll_top * cols;
        const region_end = (self.scroll_bottom + 1) * cols;
        const move_len = region_end - region_start - n * cols;
        if (move_len > 0) {
            std.mem.copyForwards(types.Cell, self.grid.cells.items[region_start .. region_start + move_len], self.grid.cells.items[region_start + n * cols .. region_end]);
        }
        for (self.grid.cells.items[region_end - n * cols .. region_end]) |*cell| cell.* = blank_cell;
        self.grid.markDirtyRange(self.scroll_top, self.scroll_bottom, 0, cols - 1);
    }

    pub fn scrollRegionDownBy(self: *Screen, n: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return;
        if (n == 0) return;
        const region_start = self.scroll_top * cols;
        const region_end = (self.scroll_bottom + 1) * cols;
        const move_len = region_end - region_start - n * cols;
        if (move_len > 0) {
            std.mem.copyBackwards(types.Cell, self.grid.cells.items[region_start + n * cols .. region_end], self.grid.cells.items[region_start .. region_start + move_len]);
        }
        for (self.grid.cells.items[region_start .. region_start + n * cols]) |*cell| cell.* = blank_cell;
        self.grid.markDirtyRange(self.scroll_top, self.scroll_bottom, 0, cols - 1);
    }

    pub fn scrollUp(self: *Screen, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        const rows = @as(usize, self.grid.rows);
        if (rows == 0 or cols == 0) return;
        const total = rows * cols;
        const row_bytes = cols * @sizeOf(types.Cell);
        const src = @as([*]u8, @ptrCast(self.grid.cells.items.ptr));
        std.mem.copyForwards(u8, src[0 .. total * @sizeOf(types.Cell) - row_bytes], src[row_bytes .. total * @sizeOf(types.Cell)]);

        const row_start = (rows - 1) * cols;
        for (self.grid.cells.items[row_start .. row_start + cols]) |*cell| {
            cell.* = blank_cell;
        }
        self.cursor.row = rows - 1;
        self.cursor.col = 0;
        self.grid.markDirtyAll();
    }
};

const SavedCursor = struct {
    active: bool,
    cursor: types.CursorPos,
    attrs: types.CellAttrs,
};

pub const KeyModeStack = struct {
    len: usize,
    items: [key_mode_stack_max]u32,

    pub fn init() KeyModeStack {
        return .{
            .len = 1,
            .items = [_]u32{0} ** key_mode_stack_max,
        };
    }

    pub fn current(self: *const KeyModeStack) u32 {
        return self.items[self.len - 1];
    }

    pub fn push(self: *KeyModeStack, flags: u32) void {
        if (self.len >= key_mode_stack_max) {
            var idx: usize = 1;
            while (idx < key_mode_stack_max) : (idx += 1) {
                self.items[idx - 1] = self.items[idx];
            }
            self.len = key_mode_stack_max - 1;
        }
        self.items[self.len] = flags;
        self.len += 1;
    }

    pub fn pop(self: *KeyModeStack, count: usize) void {
        if (self.len <= 1) return;
        const max_pop = self.len - 1;
        const actual = @min(count, max_pop);
        self.len -= actual;
    }

    pub fn setCurrent(self: *KeyModeStack, flags: u32) void {
        self.items[self.len - 1] = flags;
    }
};

const key_mode_stack_max: usize = 32;
