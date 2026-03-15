const std = @import("std");
const scrollback_buffer = @import("scrollback_buffer.zig");
const app_logger = @import("../../app_logger.zig");
const selection_mod = @import("selection.zig");
const types = @import("types.zig");

const ScrollbackBuffer = scrollback_buffer.ScrollbackBuffer;

pub const TerminalHistory = struct {
    allocator: std.mem.Allocator,
    scrollback: ScrollbackBuffer,
    scrollback_offset: usize,
    saved_scrollback_offset: usize,
    selection: selection_mod.SelectionState,
    view_cache: std.ArrayList(types.Cell),
    view_wraps: std.ArrayList(bool),
    view_rows: usize,
    view_cols: u16,
    scrollback_generation: u64,
    view_generation: u64,
    view_row_count_generation: u64,

    pub fn init(allocator: std.mem.Allocator, max_rows: usize, cols: u16) !TerminalHistory {
        _ = cols;
        const scrollback = try ScrollbackBuffer.init(allocator, max_rows);
        return .{
            .allocator = allocator,
            .scrollback = scrollback,
            .scrollback_offset = 0,
            .saved_scrollback_offset = 0,
            .selection = selection_mod.SelectionState.init(),
            .view_cache = std.ArrayList(types.Cell).empty,
            .view_wraps = std.ArrayList(bool).empty,
            .view_rows = 0,
            .view_cols = 0,
            .scrollback_generation = 0,
            .view_generation = 0,
            .view_row_count_generation = 0,
        };
    }

    pub fn deinit(self: *TerminalHistory) void {
        self.scrollback.deinit();
        self.view_cache.deinit(self.allocator);
        self.view_wraps.deinit(self.allocator);
    }

    pub fn resizePreserve(self: *TerminalHistory, cols: u16, default_cell: types.Cell) !void {
        if (cols == 0) {
            self.view_cache.clearRetainingCapacity();
            self.view_wraps.clearRetainingCapacity();
            self.view_rows = 0;
            self.view_cols = 0;
            self.view_generation = self.scrollback_generation;
            self.view_row_count_generation = self.scrollback_generation;
            return;
        }
        self.view_generation = if (self.scrollback_generation > 0) self.scrollback_generation - 1 else 0;
        self.view_row_count_generation = if (self.scrollback_generation > 0) self.scrollback_generation - 1 else 0;
        self.ensureViewCache(cols, default_cell);
    }

    pub fn clear(self: *TerminalHistory) void {
        self.scrollback.clear();
        self.scrollback_generation +|= 1;
        self.view_cache.clearRetainingCapacity();
        self.view_wraps.clearRetainingCapacity();
        self.view_rows = 0;
        self.view_cols = 0;
        self.view_generation = self.scrollback_generation;
        self.view_row_count_generation = self.scrollback_generation;
        self.scrollback_offset = 0;
        self.saved_scrollback_offset = 0;
    }

    pub fn updateDefaultColors(
        self: *TerminalHistory,
        old_fg: types.Color,
        old_bg: types.Color,
        new_fg: types.Color,
        new_bg: types.Color,
    ) void {
        var changed = false;
        var idx: usize = 0;
        while (idx < self.scrollback.count()) : (idx += 1) {
            const line = self.scrollback.lineByIndexMut(idx) orelse continue;
            for (line.cells) |*cell| {
                if (colorsEqual(cell.attrs.fg, old_fg)) {
                    cell.attrs.fg = new_fg;
                    changed = true;
                }
                if (colorsEqual(cell.attrs.bg, old_bg)) {
                    cell.attrs.bg = new_bg;
                    changed = true;
                }
            }
        }
        if (changed) self.markScrollbackChanged();
    }

    pub fn updateAnsiColors(self: *TerminalHistory, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
        var changed = false;
        var idx: usize = 0;
        while (idx < self.scrollback.count()) : (idx += 1) {
            const line = self.scrollback.lineByIndexMut(idx) orelse continue;
            for (line.cells) |*cell| {
                const old_fg = cell.attrs.fg;
                const old_bg = cell.attrs.bg;
                const old_ul = cell.attrs.underline_color;
                cell.attrs.fg = remapAnsiColor(cell.attrs.fg, old_colors, new_colors);
                cell.attrs.bg = remapAnsiColor(cell.attrs.bg, old_colors, new_colors);
                cell.attrs.underline_color = remapAnsiColor(cell.attrs.underline_color, old_colors, new_colors);
                if (!colorsEqual(old_fg, cell.attrs.fg) or !colorsEqual(old_bg, cell.attrs.bg) or !colorsEqual(old_ul, cell.attrs.underline_color)) {
                    changed = true;
                }
            }
        }
        if (changed) self.markScrollbackChanged();
    }

    fn remapAnsiColor(color: types.Color, old_colors: [16]types.Color, new_colors: [16]types.Color) types.Color {
        for (0..16) |i| {
            if (colorsEqual(color, old_colors[i])) return new_colors[i];
        }
        return color;
    }

    fn colorsEqual(a: types.Color, b: types.Color) bool {
        return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
    }

    pub fn ensureViewCache(self: *TerminalHistory, cols: u16, default_cell: types.Cell) void {
        if (cols == 0) {
            self.view_cache.clearRetainingCapacity();
            self.view_wraps.clearRetainingCapacity();
            self.view_rows = 0;
            self.view_cols = 0;
            self.view_generation = self.scrollback_generation;
            self.view_row_count_generation = self.scrollback_generation;
            return;
        }
        if (self.view_cols == cols and self.view_generation == self.scrollback_generation) return;

        const log = app_logger.logger("terminal.scroll");
        log.logf(.info, "scroll cache rebuild cols={d} lines={d} gen={d}", .{ cols, self.scrollback.count(), self.scrollback_generation });

        self.view_cache.clearRetainingCapacity();
        self.view_wraps.clearRetainingCapacity();
        self.view_rows = 0;
        self.view_cols = cols;

        var idx: usize = 0;
        while (idx < self.scrollback.count()) : (idx += 1) {
            const line = self.scrollback.lineByIndex(idx) orelse continue;
            const line_len = line.cells.len;
            if (line_len == 0) {
                self.view_cache.resize(self.allocator, self.view_cache.items.len + @as(usize, cols)) catch |err| {
                    log.logf(.warning, "scroll cache resize failed cols={d} err={s}", .{ cols, @errorName(err) });
                    return;
                };
                const start = self.view_cache.items.len - @as(usize, cols);
                for (self.view_cache.items[start .. start + @as(usize, cols)]) |*cell| cell.* = default_cell;
                self.view_wraps.append(self.allocator, line.wrapped) catch |err| {
                    log.logf(.warning, "scroll cache wraps append failed err={s}", .{@errorName(err)});
                    return;
                };
                self.view_rows += 1;
                continue;
            }
            var offset: usize = 0;
            while (offset < line_len) : (offset += @as(usize, cols)) {
                self.view_cache.resize(self.allocator, self.view_cache.items.len + @as(usize, cols)) catch |err| {
                    log.logf(.warning, "scroll cache resize failed cols={d} err={s}", .{ cols, @errorName(err) });
                    return;
                };
                const start = self.view_cache.items.len - @as(usize, cols);
                for (self.view_cache.items[start .. start + @as(usize, cols)]) |*cell| cell.* = default_cell;
                const remaining = line_len - offset;
                const copy_len = if (remaining > @as(usize, cols)) @as(usize, cols) else remaining;
                std.mem.copyForwards(types.Cell, self.view_cache.items[start .. start + copy_len], line.cells[offset .. offset + copy_len]);
                const is_last = remaining <= @as(usize, cols);
                self.view_wraps.append(self.allocator, if (is_last) line.wrapped else true) catch |err| {
                    log.logf(.warning, "scroll cache wraps append failed err={s}", .{@errorName(err)});
                    return;
                };
                self.view_rows += 1;
            }
        }

        self.view_generation = self.scrollback_generation;
        self.view_row_count_generation = self.scrollback_generation;

        log.logf(.info, "scroll cache rows={d} cells={d}", .{ self.view_rows, self.view_cache.items.len });
    }

    pub fn markScrollbackChanged(self: *TerminalHistory) void {
        self.scrollback_generation +|= 1;
    }

    fn flattenedRowsForLen(cols: u16, line_len: usize) usize {
        if (cols == 0) return 0;
        const cols_usize = @as(usize, cols);
        if (line_len == 0) return 1;
        return (line_len + cols_usize - 1) / cols_usize;
    }

    pub fn pushRow(self: *TerminalHistory, row: []const types.Cell, wrapped: bool, default_cell: types.Cell) void {
        const row_len_full = row.len;
        if (row_len_full == 0) return;
        const row_cols: u16 = @intCast(row_len_full);
        const can_update_view_rows = self.view_cols != 0 and self.view_cols == row_cols;
        const old_scrollback_generation = self.scrollback_generation;
        var dropped_view_rows: usize = 0;
        var last_view_rows_before: usize = 0;
        if (can_update_view_rows and self.scrollback.count() == self.scrollback.capacityLines() and !wrapped) {
            if (self.scrollback.lineByIndex(0)) |first_line| {
                dropped_view_rows = flattenedRowsForLen(self.view_cols, first_line.cells.len);
            }
        }

        var append_to_last = false;
        if (self.scrollback.count() > 0) {
            if (self.scrollback.lineByIndex(self.scrollback.count() - 1)) |last_line| {
                append_to_last = last_line.wrapped;
                if (can_update_view_rows and append_to_last) {
                    last_view_rows_before = flattenedRowsForLen(self.view_cols, last_line.cells.len);
                }
            }
        }

        const keep_full = wrapped or append_to_last;
        var row_len: usize = row_len_full;
        if (!keep_full) {
            var found = false;
            var col: usize = row_len_full;
            while (col > 0) {
                col -= 1;
                const cell = row[col];
                const is_default = cell.codepoint == default_cell.codepoint and
                    cell.width == default_cell.width and
                    cell.attrs.fg.r == default_cell.attrs.fg.r and
                    cell.attrs.fg.g == default_cell.attrs.fg.g and
                    cell.attrs.fg.b == default_cell.attrs.fg.b and
                    cell.attrs.fg.a == default_cell.attrs.fg.a and
                    cell.attrs.bg.r == default_cell.attrs.bg.r and
                    cell.attrs.bg.g == default_cell.attrs.bg.g and
                    cell.attrs.bg.b == default_cell.attrs.bg.b and
                    cell.attrs.bg.a == default_cell.attrs.bg.a and
                    cell.attrs.bold == default_cell.attrs.bold and
                    cell.attrs.reverse == default_cell.attrs.reverse and
                    cell.attrs.underline == default_cell.attrs.underline and
                    cell.attrs.underline_color.r == default_cell.attrs.underline_color.r and
                    cell.attrs.underline_color.g == default_cell.attrs.underline_color.g and
                    cell.attrs.underline_color.b == default_cell.attrs.underline_color.b and
                    cell.attrs.underline_color.a == default_cell.attrs.underline_color.a and
                    cell.attrs.link_id == default_cell.attrs.link_id;
                if (!is_default) {
                    row_len = col + 1;
                    found = true;
                    break;
                }
            }
            if (!found) {
                row_len = 0;
            }
        }

        if (append_to_last) {
            if (self.scrollback.lineByIndexMut(self.scrollback.count() - 1)) |last_line| {
                if (row_len == 0) {
                    last_line.wrapped = wrapped;
                    self.markScrollbackChanged();
                    if (can_update_view_rows and self.view_row_count_generation == old_scrollback_generation) {
                        self.view_row_count_generation = self.scrollback_generation;
                    }
                    return;
                }

                const old_len = last_line.cells.len;
                const new_len = old_len + row_len;
                const new_cells = self.allocator.realloc(last_line.cells, new_len) catch {
                    last_line.wrapped = false;
                    _ = self.scrollback.pushLine(row[0..row_len], wrapped) catch |push_err| blk: {
                        app_logger.logger("terminal.scroll").logf(.warning, "scrollback append fallback push failed len={d} err={s}", .{ row_len, @errorName(push_err) });
                        break :blk 0;
                    };
                    self.markScrollbackChanged();
                    if (can_update_view_rows and self.view_row_count_generation == old_scrollback_generation) {
                        self.view_rows += flattenedRowsForLen(self.view_cols, row_len);
                        self.view_row_count_generation = self.scrollback_generation;
                    }
                    return;
                };
                last_line.cells = new_cells;
                std.mem.copyForwards(types.Cell, last_line.cells[old_len .. old_len + row_len], row[0..row_len]);
                last_line.wrapped = wrapped;
                self.markScrollbackChanged();
                if (can_update_view_rows and self.view_row_count_generation == old_scrollback_generation) {
                    const last_view_rows_after = flattenedRowsForLen(self.view_cols, last_line.cells.len);
                    self.view_rows = self.view_rows - last_view_rows_before + last_view_rows_after;
                    self.view_row_count_generation = self.scrollback_generation;
                }
                return;
            }
        }

        _ = self.scrollback.pushLine(row[0..row_len], wrapped) catch |err| blk: {
            app_logger.logger("terminal.scroll").logf(.warning, "scrollback push failed len={d} wrapped={d} err={s}", .{ row_len, @intFromBool(wrapped), @errorName(err) });
            break :blk 0;
        };
        self.markScrollbackChanged();
        if (can_update_view_rows and self.view_row_count_generation == old_scrollback_generation) {
            if (dropped_view_rows > 0) self.view_rows -= dropped_view_rows;
            self.view_rows += flattenedRowsForLen(self.view_cols, row_len);
            self.view_row_count_generation = self.scrollback_generation;
        }
    }

    pub fn scrollbackCount(self: *TerminalHistory) usize {
        return self.view_rows;
    }

    pub fn scrollbackRow(self: *TerminalHistory, index: usize) ?[]const types.Cell {
        const cols = @as(usize, self.view_cols);
        if (cols == 0) return null;
        const start = index * cols;
        if (start + cols > self.view_cache.items.len) {
            const log = app_logger.logger("terminal.scroll");
            log.logf(.info, "scroll row miss index={d} start={d} cols={d} len={d}", .{ index, start, cols, self.view_cache.items.len });
            return null;
        }
        return self.view_cache.items[start .. start + cols];
    }

    pub fn scrollbackRowWrapped(self: *TerminalHistory, index: usize) bool {
        if (index >= self.view_wraps.items.len) return false;
        return self.view_wraps.items[index];
    }

    pub fn scrollbackLineId(self: *TerminalHistory, index: usize) ?u64 {
        const line = self.scrollback.lineByIndex(index) orelse return null;
        return line.id;
    }

    pub fn scrollbackCapacity(self: *TerminalHistory) usize {
        return self.scrollback.capacityLines();
    }

    pub fn scrollOffset(self: *TerminalHistory) usize {
        return self.scrollback_offset;
    }

    pub fn maxScrollOffset(self: *TerminalHistory, rows: u16) usize {
        const visible = @as(usize, rows);
        const total = self.view_rows + visible;
        if (total <= visible) return 0;
        return total - visible;
    }

    pub fn setScrollOffset(self: *TerminalHistory, rows: u16, offset: usize) void {
        if (rows == 0) {
            self.scrollback_offset = 0;
            return;
        }
        const max_offset = self.maxScrollOffset(rows);
        self.scrollback_offset = @min(offset, max_offset);
    }

    pub fn scrollBy(self: *TerminalHistory, rows: u16, delta: isize) void {
        if (rows == 0) return;
        const max_offset = self.maxScrollOffset(rows);
        var offset: isize = @intCast(self.scrollback_offset);
        offset += delta;
        if (offset < 0) offset = 0;
        if (offset > @as(isize, @intCast(max_offset))) offset = @intCast(max_offset);
        self.scrollback_offset = @intCast(offset);
    }

    pub fn saveScrollOffset(self: *TerminalHistory) void {
        self.saved_scrollback_offset = self.scrollback_offset;
        self.scrollback_offset = 0;
    }

    pub fn restoreScrollOffset(self: *TerminalHistory, rows: u16) void {
        self.setScrollOffset(rows, self.saved_scrollback_offset);
    }

    pub fn clearSelection(self: *TerminalHistory) void {
        self.selection.clear();
    }

    pub fn startSelection(self: *TerminalHistory, row: usize, col: usize) void {
        self.selection.start(row, col);
    }

    pub fn updateSelection(self: *TerminalHistory, row: usize, col: usize) void {
        self.selection.update(row, col);
    }

    pub fn finishSelection(self: *TerminalHistory) void {
        self.selection.finish();
    }

    pub fn selectionState(self: *TerminalHistory) ?types.TerminalSelection {
        return self.selection.state();
    }
};
