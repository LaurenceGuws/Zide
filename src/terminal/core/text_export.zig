const std = @import("std");
const types = @import("../model/types.zig");
const selection_mod = @import("selection.zig");
const scrollback_view = @import("scrollback_view.zig");

const Cell = types.Cell;
const CellAttrs = types.CellAttrs;
const TerminalSelection = types.TerminalSelection;

fn rowLastContentCol(row_cells: []const Cell, cols_count: usize) ?usize {
    if (cols_count == 0 or row_cells.len < cols_count) return null;
    var last: ?usize = null;
    var col_idx: usize = 0;
    while (col_idx < cols_count) : (col_idx += 1) {
        const cell = row_cells[col_idx];
        if (cell.x != 0 or cell.y != 0) continue;
        if (cell.codepoint == 0 and cell.combining_len == 0) continue;
        const width_units = @as(usize, @max(@as(u8, 1), cell.width));
        const end_col = @min(cols_count - 1, col_idx + width_units - 1);
        last = end_col;
    }
    return last;
}

fn appendCellText(out: *std.ArrayList(u8), allocator: std.mem.Allocator, cell: Cell) !void {
    if (cell.x != 0 or cell.y != 0) return;
    if (cell.codepoint == 0) {
        try out.append(allocator, ' ');
        return;
    }

    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(@intCast(cell.codepoint), &buf) catch 0;
    if (len > 0) try out.appendSlice(allocator, buf[0..len]);

    if (cell.combining_len > 0) {
        var ci: usize = 0;
        while (ci < @as(usize, @intCast(cell.combining_len)) and ci < cell.combining.len) : (ci += 1) {
            const cp = cell.combining[ci];
            const c_len = std.unicode.utf8Encode(@intCast(cp), &buf) catch 0;
            if (c_len > 0) try out.appendSlice(allocator, buf[0..c_len]);
        }
    }
}

fn appendSelectionRange(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    row_cells: []const Cell,
    cols: usize,
    col_start: usize,
    col_end: usize,
) !void {
    const last_content_col = rowLastContentCol(row_cells, cols) orelse return;
    const clamped_end = @min(col_end, last_content_col);
    if (clamped_end < col_start) return;

    var col_idx: usize = col_start;
    while (col_idx <= clamped_end and col_idx < cols) : (col_idx += 1) {
        try appendCellText(out, allocator, row_cells[col_idx]);
    }

    while (out.items.len > 0 and out.items[out.items.len - 1] == ' ') {
        _ = out.pop();
    }
}

fn appendPlainRow(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    row_cells: []const Cell,
) !void {
    var line = std.ArrayList(u8).empty;
    defer line.deinit(allocator);

    for (row_cells) |cell| {
        try appendCellText(&line, allocator, cell);
    }

    while (line.items.len > 0 and line.items[line.items.len - 1] == ' ') {
        _ = line.pop();
    }

    try out.appendSlice(allocator, line.items);
    try out.append(allocator, '\n');
}

fn attrsEqual(a: CellAttrs, b: CellAttrs) bool {
    return a.fg.r == b.fg.r and
        a.fg.g == b.fg.g and
        a.fg.b == b.fg.b and
        a.fg.a == b.fg.a and
        a.bg.r == b.bg.r and
        a.bg.g == b.bg.g and
        a.bg.b == b.bg.b and
        a.bg.a == b.bg.a and
        a.bold == b.bold and
        a.blink == b.blink and
        a.blink_fast == b.blink_fast and
        a.reverse == b.reverse and
        a.underline == b.underline and
        a.underline_color.r == b.underline_color.r and
        a.underline_color.g == b.underline_color.g and
        a.underline_color.b == b.underline_color.b and
        a.underline_color.a == b.underline_color.a;
}

fn appendSgrForAttrs(out: *std.ArrayList(u8), allocator: std.mem.Allocator, attrs: CellAttrs) !void {
    try out.writer(allocator).print(
        "\x1b[0{s}{s}{s}{s};38;2;{d};{d};{d};48;2;{d};{d};{d};58;2;{d};{d};{d}m",
        .{
            if (attrs.bold) ";1" else "",
            if (attrs.underline) ";4" else "",
            if (attrs.reverse) ";7" else "",
            if (attrs.blink) (if (attrs.blink_fast) ";6" else ";5") else "",
            attrs.fg.r,
            attrs.fg.g,
            attrs.fg.b,
            attrs.bg.r,
            attrs.bg.g,
            attrs.bg.b,
            attrs.underline_color.r,
            attrs.underline_color.g,
            attrs.underline_color.b,
        },
    );
}

fn appendAnsiRow(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    row_cells: []const Cell,
) !void {
    var active_attrs: ?CellAttrs = null;
    var col_idx: usize = 0;
    while (col_idx < row_cells.len) : (col_idx += 1) {
        const cell = row_cells[col_idx];
        if (cell.x != 0 or cell.y != 0) continue;

        if (active_attrs == null or !attrsEqual(active_attrs.?, cell.attrs)) {
            try appendSgrForAttrs(out, allocator, cell.attrs);
            active_attrs = cell.attrs;
        }
        try appendCellText(out, allocator, cell);
    }

    if (active_attrs != null) {
        try out.appendSlice(allocator, "\x1b[0m");
    }
    try out.append(allocator, '\n');
}

fn visibleRow(self: anytype, cells: []const Cell, rows: usize, cols: usize, history: usize, line_idx: usize) ?[]const Cell {
    if (line_idx < history) return scrollback_view.scrollbackRow(self, line_idx);
    const grid_row = line_idx - history;
    if (grid_row >= rows or cols == 0) return null;
    const row_start = grid_row * cols;
    return cells[row_start .. row_start + cols];
}

pub fn selectionPlainTextAlloc(self: anytype, allocator: std.mem.Allocator) !?[]u8 {
    self.lock();
    defer self.unlock();

    const selection = selection_mod.selectionState(self) orelse return null;
    const screen = self.activeScreenConst();
    const view = screen.snapshotView();
    const rows = view.rows;
    const cols = view.cols;
    const history = scrollback_view.scrollbackCount(self);
    const total_lines = history + rows;
    if (rows == 0 or cols == 0 or total_lines == 0) return null;

    var start_sel = selection.start;
    var end_sel = selection.end;
    if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
        const tmp = start_sel;
        start_sel = end_sel;
        end_sel = tmp;
    }
    start_sel.row = @min(start_sel.row, total_lines - 1);
    end_sel.row = @min(end_sel.row, total_lines - 1);
    start_sel.col = @min(start_sel.col, cols - 1);
    end_sel.col = @min(end_sel.col, cols - 1);

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var row_idx: usize = start_sel.row;
    while (row_idx <= end_sel.row and row_idx < total_lines) : (row_idx += 1) {
        const row_cells = visibleRow(self, view.cells, rows, cols, history, row_idx) orelse continue;
        const col_start = if (row_idx == start_sel.row) start_sel.col else 0;
        const col_end = if (row_idx == end_sel.row) end_sel.col else cols - 1;
        try appendSelectionRange(&out, allocator, row_cells, cols, col_start, col_end);
        if (row_idx != end_sel.row) try out.append(allocator, '\n');
    }

    const text = try out.toOwnedSlice(allocator);
    return text;
}

pub fn scrollbackPlainTextAlloc(self: anytype, allocator: std.mem.Allocator) ![]u8 {
    self.lock();
    defer self.unlock();

    const screen = self.activeScreenConst();
    const view = screen.snapshotView();
    const rows = view.rows;
    const cols = view.cols;
    const history = scrollback_view.scrollbackCount(self);

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var line_idx: usize = 0;
    while (line_idx < history + rows) : (line_idx += 1) {
        const row_cells = visibleRow(self, view.cells, rows, cols, history, line_idx) orelse continue;
        try appendPlainRow(&out, allocator, row_cells);
    }

    return out.toOwnedSlice(allocator);
}

pub fn scrollbackAnsiTextAlloc(self: anytype, allocator: std.mem.Allocator) ![]u8 {
    self.lock();
    defer self.unlock();

    const screen = self.activeScreenConst();
    const view = screen.snapshotView();
    const rows = view.rows;
    const cols = view.cols;
    const history = scrollback_view.scrollbackCount(self);

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var line_idx: usize = 0;
    while (line_idx < history + rows) : (line_idx += 1) {
        const row_cells = visibleRow(self, view.cells, rows, cols, history, line_idx) orelse continue;
        try appendAnsiRow(&out, allocator, row_cells);
    }

    return out.toOwnedSlice(allocator);
}
