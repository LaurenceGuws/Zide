const std = @import("std");
const types = @import("types.zig");

pub const WordSpan = struct {
    start: usize,
    end: usize,
};

pub const SelectionRange = struct {
    start: types.SelectionPos,
    end: types.SelectionPos,
};

const SelectionCellClass = enum {
    empty,
    word,
    space,
    other,
};

pub fn before(a: types.SelectionPos, b: types.SelectionPos) bool {
    if (a.row < b.row) return true;
    if (a.row > b.row) return false;
    return a.col < b.col;
}

pub fn rowLastContentCol(row_cells: []const types.Cell) ?usize {
    var last: ?usize = null;
    var col_idx: usize = 0;
    while (col_idx < row_cells.len) : (col_idx += 1) {
        const cell = row_cells[col_idx];
        if (cell.x != 0 or cell.y != 0) continue;
        if (cell.codepoint == 0 and cell.combining_len == 0) continue;
        const width_units = @as(usize, @max(@as(u8, 1), cell.width));
        const cell_end = @min(row_cells.len - 1, col_idx + width_units - 1);
        last = cell_end;
    }
    return last;
}

pub fn orderedRange(
    anchor_start: types.SelectionPos,
    anchor_end: types.SelectionPos,
    target_start: types.SelectionPos,
    target_end: types.SelectionPos,
) SelectionRange {
    if (before(target_start, anchor_start)) {
        return .{ .start = target_start, .end = anchor_end };
    }
    return .{ .start = anchor_start, .end = target_end };
}

pub fn wordSpan(row_cells: []const types.Cell, col: usize, last_col: usize) ?WordSpan {
    if (row_cells.len == 0) return null;
    const clamped_last = @min(last_col, row_cells.len - 1);
    var anchor = @min(col, clamped_last);
    anchor = cellRootCol(row_cells, anchor);
    const anchor_class = classifyCell(row_cells[anchor]);
    if (anchor_class == .empty) return null;

    var start = anchor;
    while (start > 0) {
        const prev = start - 1;
        const prev_root = cellRootCol(row_cells, prev);
        if (prev_root >= start) break;
        if (prev_root > clamped_last) break;
        if (classifyCell(row_cells[prev_root]) != anchor_class) break;
        start = prev_root;
    }

    var end = anchor;
    while (end < clamped_last) {
        const next = end + 1;
        const next_root = cellRootCol(row_cells, next);
        if (next_root <= end) break;
        if (next_root > clamped_last) break;
        if (classifyCell(row_cells[next_root]) != anchor_class) break;
        end = next_root;
    }

    return .{ .start = start, .end = end };
}

fn classifyCell(cell: types.Cell) SelectionCellClass {
    if (cell.x != 0 or cell.y != 0) return .empty;
    if (cell.codepoint == 0 and cell.combining_len == 0) return .space;
    const cp = cell.codepoint;
    if (cp <= 0x7F) {
        const b: u8 = @intCast(cp);
        if (std.ascii.isAlphanumeric(b) or b == '_') return .word;
        if (std.ascii.isWhitespace(b)) return .space;
    } else {
        return .word;
    }
    return .other;
}

fn cellRootCol(row_cells: []const types.Cell, col: usize) usize {
    if (row_cells.len == 0) return 0;
    const idx = @min(col, row_cells.len - 1);
    const cell = row_cells[idx];
    if (cell.x == 0 or cell.y != 0) return idx;
    const delta = @as(usize, cell.x);
    if (delta > idx) return 0;
    return idx - delta;
}

test "rowLastContentCol ignores continuations and trailing blanks" {
    const base = types.Cell{
        .codepoint = 0,
        .attrs = types.defaultCell().attrs,
    };
    var row = [_]types.Cell{ base, base, base, base };
    row[0].codepoint = 'A';
    row[1].codepoint = 'B';
    try std.testing.expectEqual(@as(?usize, 1), rowLastContentCol(&row));
}

test "wordSpan groups ascii word cells" {
    const base = types.defaultCell();
    var row = [_]types.Cell{ base, base, base, base, base };
    row[0].codepoint = 'f';
    row[1].codepoint = 'o';
    row[2].codepoint = 'o';
    row[3].codepoint = ' ';
    row[4].codepoint = '!';

    const span = wordSpan(&row, 1, 4).?;
    try std.testing.expectEqual(@as(usize, 0), span.start);
    try std.testing.expectEqual(@as(usize, 2), span.end);
}

test "orderedRange expands in both directions from anchor" {
    const forward = orderedRange(
        .{ .row = 3, .col = 2 },
        .{ .row = 3, .col = 5 },
        .{ .row = 4, .col = 0 },
        .{ .row = 4, .col = 3 },
    );
    try std.testing.expectEqual(@as(usize, 3), forward.start.row);
    try std.testing.expectEqual(@as(usize, 2), forward.start.col);
    try std.testing.expectEqual(@as(usize, 4), forward.end.row);
    try std.testing.expectEqual(@as(usize, 3), forward.end.col);

    const backward = orderedRange(
        .{ .row = 3, .col = 2 },
        .{ .row = 3, .col = 5 },
        .{ .row = 2, .col = 1 },
        .{ .row = 2, .col = 4 },
    );
    try std.testing.expectEqual(@as(usize, 2), backward.start.row);
    try std.testing.expectEqual(@as(usize, 1), backward.start.col);
    try std.testing.expectEqual(@as(usize, 3), backward.end.row);
    try std.testing.expectEqual(@as(usize, 5), backward.end.col);
}
