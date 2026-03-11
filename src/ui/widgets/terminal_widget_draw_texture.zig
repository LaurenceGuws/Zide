const std = @import("std");
const render_cache_mod = @import("../../terminal/core/render_cache.zig");

const RenderCache = render_cache_mod.RenderCache;

pub const ViewportTextureShiftPlan = union(enum) {
    none,
    attempt: usize,
};

pub const TextureUpdatePlan = struct {
    needs_full: bool,
    needs_partial: bool,
};

pub fn planViewportTextureShift(
    texture_shift_enabled: bool,
    gen_changed: bool,
    viewport_shift_rows: i32,
    viewport_shift_exposed_only: bool,
    scroll_offset: usize,
    needs_full: bool,
    terminal_texture_ready: bool,
    rows: usize,
) ViewportTextureShiftPlan {
    const shift_abs_i: i32 = if (viewport_shift_rows < 0) -viewport_shift_rows else viewport_shift_rows;
    if (texture_shift_enabled and
        gen_changed and
        viewport_shift_rows != 0 and
        (scroll_offset == 0 or viewport_shift_exposed_only) and
        !needs_full and
        terminal_texture_ready and
        shift_abs_i > 0 and
        shift_abs_i < @as(i32, @intCast(rows)))
    {
        return .{ .attempt = @as(usize, @intCast(shift_abs_i)) };
    }
    return .none;
}

pub fn chooseTextureUpdatePlan(
    cache_dirty: @TypeOf(RenderCache.init().dirty),
    recreated: bool,
    cell_metrics_changed: bool,
    render_scale_changed: bool,
    blink_requires_partial: bool,
    terminal_texture_ready: bool,
) TextureUpdatePlan {
    var needs_full = recreated or
        cell_metrics_changed or
        render_scale_changed or
        cache_dirty == .full;
    var needs_partial = (cache_dirty == .partial or blink_requires_partial) and !needs_full;
    if (!terminal_texture_ready) {
        needs_full = true;
        needs_partial = false;
    }
    return .{
        .needs_full = needs_full,
        .needs_partial = needs_partial,
    };
}

pub fn markPartialPlanRows(
    partial_rows: []bool,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
    rows: usize,
    row: usize,
    col_start: usize,
    col_end: usize,
) void {
    const affect_start = row -| 1;
    const affect_end = @min(rows - 1, row + 1);
    const col_start_u16: u16 = @intCast(col_start);
    const col_end_u16: u16 = @intCast(col_end);
    var affect_row = affect_start;
    while (affect_row <= affect_end) : (affect_row += 1) {
        partial_rows[affect_row] = true;
        if (partial_cols_start[affect_row] > col_start_u16) partial_cols_start[affect_row] = col_start_u16;
        if (partial_cols_end[affect_row] < col_end_u16) partial_cols_end[affect_row] = col_end_u16;
    }
}

pub fn markAllRowsFullWidthPartialPlan(
    partial_rows: []bool,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
    rows: usize,
    cols: usize,
) void {
    if (rows == 0 or cols == 0) return;
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        partial_rows[row] = true;
        partial_cols_start[row] = 0;
        partial_cols_end[row] = @intCast(cols - 1);
    }
}

pub fn addBlinkRowsToPartialPlan(
    cache: *const RenderCache,
    partial_rows: []bool,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
) void {
    const rows = cache.rows;
    const cols = cache.cols;
    if (rows == 0 or cols == 0) return;

    var row: usize = 0;
    while (row < rows) : (row += 1) {
        const row_start = row * cols;
        const row_cells = cache.cells.items[row_start .. row_start + cols];
        var first_col: ?usize = null;
        var last_col: usize = 0;
        var col: usize = 0;
        while (col < cols) : (col += 1) {
            const cell = row_cells[col];
            if (cell.x != 0 or cell.y != 0) continue;
            if (!cell.attrs.blink) continue;
            const width_units = @as(usize, @max(@as(u8, 1), cell.width));
            if (first_col == null) first_col = col;
            last_col = @max(last_col, @min(cols - 1, col + width_units - 1));
        }
        if (first_col) |start_col| {
            markPartialPlanRows(
                partial_rows,
                partial_cols_start,
                partial_cols_end,
                rows,
                row,
                start_col,
                last_col,
            );
        }
    }
}

test "markPartialPlanRows widens to adjacent rows" {
    var partial_rows = [_]bool{false} ** 5;
    var partial_cols_start = [_]u16{99} ** 5;
    var partial_cols_end = [_]u16{0} ** 5;

    markPartialPlanRows(&partial_rows, &partial_cols_start, &partial_cols_end, 5, 2, 4, 6);

    try std.testing.expectEqualSlices(bool, &[_]bool{ false, true, true, true, false }, &partial_rows);
    try std.testing.expectEqual(@as(u16, 4), partial_cols_start[1]);
    try std.testing.expectEqual(@as(u16, 6), partial_cols_end[1]);
    try std.testing.expectEqual(@as(u16, 4), partial_cols_start[2]);
    try std.testing.expectEqual(@as(u16, 6), partial_cols_end[2]);
    try std.testing.expectEqual(@as(u16, 4), partial_cols_start[3]);
    try std.testing.expectEqual(@as(u16, 6), partial_cols_end[3]);
}

test "markPartialPlanRows clamps at top edge" {
    var partial_rows = [_]bool{false} ** 4;
    var partial_cols_start = [_]u16{99} ** 4;
    var partial_cols_end = [_]u16{0} ** 4;

    markPartialPlanRows(&partial_rows, &partial_cols_start, &partial_cols_end, 4, 0, 2, 3);

    try std.testing.expectEqualSlices(bool, &[_]bool{ true, true, false, false }, &partial_rows);
    try std.testing.expectEqual(@as(u16, 2), partial_cols_start[0]);
    try std.testing.expectEqual(@as(u16, 3), partial_cols_end[0]);
    try std.testing.expectEqual(@as(u16, 2), partial_cols_start[1]);
    try std.testing.expectEqual(@as(u16, 3), partial_cols_end[1]);
}

test "markPartialPlanRows reproduces cursorcolumn aggregate box" {
    var partial_rows = [_]bool{false} ** 12;
    var partial_cols_start = [_]u16{99} ** 12;
    var partial_cols_end = [_]u16{0} ** 12;

    inline for (0..8) |row| {
        markPartialPlanRows(&partial_rows, &partial_cols_start, &partial_cols_end, 12, row, 6, 6);
    }
    markPartialPlanRows(&partial_rows, &partial_cols_start, &partial_cols_end, 12, 8, 4, 6);
    markPartialPlanRows(&partial_rows, &partial_cols_start, &partial_cols_end, 12, 9, 4, 6);
    markPartialPlanRows(&partial_rows, &partial_cols_start, &partial_cols_end, 12, 10, 33, 33);

    try std.testing.expectEqualSlices(
        bool,
        &[_]bool{ true, true, true, true, true, true, true, true, true, true, true, false },
        &partial_rows,
    );
    try std.testing.expectEqual(@as(u16, 4), partial_cols_start[0]);
    try std.testing.expectEqual(@as(u16, 33), partial_cols_end[10]);

    var min_start: usize = 99;
    var max_end: usize = 0;
    var first_row: ?usize = null;
    var last_row: usize = 0;
    for (partial_rows, 0..) |dirty, row| {
        if (!dirty) continue;
        if (first_row == null) first_row = row;
        last_row = row;
        min_start = @min(min_start, partial_cols_start[row]);
        max_end = @max(max_end, partial_cols_end[row]);
    }
    try std.testing.expectEqual(@as(usize, 0), first_row.?);
    try std.testing.expectEqual(@as(usize, 10), last_row);
    try std.testing.expectEqual(@as(usize, 4), min_start);
    try std.testing.expectEqual(@as(usize, 33), max_end);
}
