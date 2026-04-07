const types = @import("../../model/types.zig");
const std = @import("std");

pub fn projectSelection(
    self: anytype,
    cache: anytype,
    total_lines: usize,
    start_line: usize,
    rows: usize,
    cols: usize,
    _: bool,
) void {
    if (self.core.active == .alt) {
        for (cache.selection_rows.items) |*row_selected| {
            row_selected.* = false;
        }
    } else if (self.core.history.selectionState()) |selection| {
        var start_sel = selection.start;
        var end_sel = selection.end;
        if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
            const tmp = start_sel;
            start_sel = end_sel;
            end_sel = tmp;
        }
        const total_lines_sel = total_lines;
        if (total_lines_sel > 0) {
            start_sel.row = @min(start_sel.row, total_lines_sel - 1);
            end_sel.row = @min(end_sel.row, total_lines_sel - 1);
            start_sel.col = @min(start_sel.col, cols - 1);
            end_sel.col = @min(end_sel.col, cols - 1);
        } else {
            start_sel.row = 0;
            end_sel.row = 0;
            start_sel.col = 0;
            end_sel.col = 0;
        }

        var row: usize = 0;
        while (row < rows) : (row += 1) {
            const global_row = start_line + row;
            if (global_row < start_sel.row or global_row > end_sel.row) {
                cache.selection_rows.items[row] = false;
                continue;
            }
            const col_start = if (global_row == start_sel.row) start_sel.col else 0;
            const col_end = if (global_row == end_sel.row) end_sel.col else cols - 1;
            if (col_end < col_start) {
                cache.selection_rows.items[row] = false;
                continue;
            }
            cache.selection_rows.items[row] = true;
            cache.selection_cols_start.items[row] = @intCast(col_start);
            cache.selection_cols_end.items[row] = @intCast(col_end);
        }
    } else {
        for (cache.selection_rows.items) |*row_selected| {
            row_selected.* = false;
        }
    }
}

test "projectSelection keeps empty middle rows visible inside multiline selection" {
    const FakeHistory = struct {
        selection: ?types.TerminalSelection,
        fn selectionState(self: @This()) ?types.TerminalSelection {
            return self.selection;
        }
    };
    const FakeCore = struct {
        active: enum { primary, alt },
        history: FakeHistory,
    };
    const FakeSelf = struct {
        core: FakeCore,
    };
    const FakeCache = struct {
        selection_rows: std.ArrayList(bool),
        selection_cols_start: std.ArrayList(u16),
        selection_cols_end: std.ArrayList(u16),
    };

    var rows = std.ArrayList(bool).empty;
    var starts = std.ArrayList(u16).empty;
    var ends = std.ArrayList(u16).empty;
    defer rows.deinit(std.testing.allocator);
    defer starts.deinit(std.testing.allocator);
    defer ends.deinit(std.testing.allocator);
    try rows.resize(std.testing.allocator, 3);
    try starts.resize(std.testing.allocator, 3);
    try ends.resize(std.testing.allocator, 3);

    var cache = FakeCache{
        .selection_rows = rows,
        .selection_cols_start = starts,
        .selection_cols_end = ends,
    };
    const self = FakeSelf{
        .core = .{
            .active = .primary,
            .history = .{
                .selection = .{
                    .active = true,
                    .selecting = false,
                    .start = .{ .row = 10, .col = 2 },
                    .end = .{ .row = 12, .col = 1 },
                },
            },
        },
    };

    projectSelection(self, &cache, 20, 10, 3, 5, true);

    try std.testing.expect(cache.selection_rows.items[0]);
    try std.testing.expect(cache.selection_rows.items[1]);
    try std.testing.expect(cache.selection_rows.items[2]);
    try std.testing.expectEqual(@as(u16, 2), cache.selection_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 4), cache.selection_cols_end.items[0]);
    try std.testing.expectEqual(@as(u16, 0), cache.selection_cols_start.items[1]);
    try std.testing.expectEqual(@as(u16, 4), cache.selection_cols_end.items[1]);
    try std.testing.expectEqual(@as(u16, 0), cache.selection_cols_start.items[2]);
    try std.testing.expectEqual(@as(u16, 1), cache.selection_cols_end.items[2]);
}

test "projectSelection does not drop a selected row just because it has no content" {
    const FakeHistory = struct {
        selection: ?types.TerminalSelection,
        fn selectionState(self: @This()) ?types.TerminalSelection {
            return self.selection;
        }
    };
    const FakeCore = struct {
        active: enum { primary, alt },
        history: FakeHistory,
    };
    const FakeSelf = struct {
        core: FakeCore,
    };
    const FakeCache = struct {
        selection_rows: std.ArrayList(bool),
        selection_cols_start: std.ArrayList(u16),
        selection_cols_end: std.ArrayList(u16),
    };

    var rows = std.ArrayList(bool).empty;
    var starts = std.ArrayList(u16).empty;
    var ends = std.ArrayList(u16).empty;
    defer rows.deinit(std.testing.allocator);
    defer starts.deinit(std.testing.allocator);
    defer ends.deinit(std.testing.allocator);
    try rows.resize(std.testing.allocator, 1);
    try starts.resize(std.testing.allocator, 1);
    try ends.resize(std.testing.allocator, 1);

    var cache = FakeCache{
        .selection_rows = rows,
        .selection_cols_start = starts,
        .selection_cols_end = ends,
    };
    const self = FakeSelf{
        .core = .{
            .active = .primary,
            .history = .{
                .selection = .{
                    .active = true,
                    .selecting = false,
                    .start = .{ .row = 4, .col = 0 },
                    .end = .{ .row = 4, .col = 3 },
                },
            },
        },
    };

    projectSelection(self, &cache, 8, 4, 1, 5, true);

    try std.testing.expect(cache.selection_rows.items[0]);
    try std.testing.expectEqual(@as(u16, 0), cache.selection_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 3), cache.selection_cols_end.items[0]);
}
