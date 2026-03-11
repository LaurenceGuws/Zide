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

pub const PartialPlanBounds = struct {
    start_row: usize,
    end_row: usize,
    start_col: usize,
    end_col: usize,
};

pub fn formatPartialPlanRows(
    buf: []u8,
    partial_rows: []const bool,
    partial_cols_start: []const u16,
    partial_cols_end: []const u16,
    max_rows: usize,
) []const u8 {
    if (buf.len == 0) return "";

    var stream = std.io.fixedBufferStream(buf);
    const writer = stream.writer();
    var emitted: usize = 0;
    var row_buf: [32]u8 = undefined;

    for (partial_rows, 0..) |dirty, row| {
        if (!dirty) continue;
        if (emitted == max_rows) {
            const ellipsis_needed: usize = if (emitted > 0) 4 else 3;
            if (stream.pos + ellipsis_needed <= buf.len) {
                if (emitted > 0) writer.writeAll(" ") catch {};
                writer.writeAll("...") catch {};
            }
            break;
        }
        const row_token = std.fmt.bufPrint(
            &row_buf,
            "{d}:{d}-{d}",
            .{ row, partial_cols_start[row], partial_cols_end[row] },
        ) catch break;
        const needed = row_token.len + @as(usize, if (emitted > 0) 1 else 0);
        if (stream.pos + needed > buf.len) {
            const ellipsis_needed: usize = if (emitted > 0) 4 else 3;
            if (stream.pos + ellipsis_needed <= buf.len) {
                if (emitted > 0) writer.writeAll(" ") catch {};
                writer.writeAll("...") catch {};
            }
            break;
        }
        if (emitted > 0) {
            writer.writeAll(" ") catch break;
        }
        writer.writeAll(row_token) catch break;
        emitted += 1;
    }

    return stream.getWritten();
}

pub fn buildPartialPlan(
    cache: *const RenderCache,
    partial_rows: []bool,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
    shifted_rows: usize,
    viewport_shift_rows: i32,
    shift_requires_fullwidth_partial: bool,
    blink_requires_partial: bool,
) ?PartialPlanBounds {
    buildBasePartialPlan(
        partial_rows,
        partial_cols_start,
        partial_cols_end,
        cache.dirty_rows.items,
        cache.dirty_cols_start.items,
        cache.dirty_cols_end.items,
        cache.rows,
        cache.cols,
        shifted_rows,
        viewport_shift_rows,
        shift_requires_fullwidth_partial,
    );
    if (blink_requires_partial) {
        addBlinkRowsToPartialPlan(
            cache,
            partial_rows,
            partial_cols_start,
            partial_cols_end,
        );
    }
    return summarizePartialPlan(partial_rows, partial_cols_start, partial_cols_end);
}

pub fn buildBasePartialPlan(
    partial_rows: []bool,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
    view_dirty_rows: []const bool,
    dirty_cols_start: []const u16,
    dirty_cols_end: []const u16,
    rows: usize,
    cols: usize,
    shifted_rows: usize,
    viewport_shift_rows: i32,
    shift_requires_fullwidth_partial: bool,
) void {
    for (partial_rows) |*row_draw| {
        row_draw.* = false;
    }
    for (partial_cols_start, partial_cols_end) |*col_start, *col_end| {
        col_start.* = if (cols > 0) @intCast(cols) else 0;
        col_end.* = 0;
    }

    if (rows == 0 or cols == 0) return;

    if (shift_requires_fullwidth_partial) {
        markAllRowsFullWidthPartialPlan(partial_rows, partial_cols_start, partial_cols_end, rows, cols);
        return;
    }

    const shift_up = viewport_shift_rows > 0;
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        const is_shift_row = shifted_rows > 0 and (if (shift_up) row >= rows - shifted_rows else row < shifted_rows);
        if (!((row < view_dirty_rows.len and view_dirty_rows[row]) or is_shift_row)) continue;

        var col_start: usize = 0;
        var col_end: usize = cols - 1;
        if (!is_shift_row and row < dirty_cols_start.len and row < dirty_cols_end.len) {
            col_start = @min(@as(usize, dirty_cols_start[row]), cols - 1);
            col_end = @min(@as(usize, dirty_cols_end[row]), cols - 1);
        }
        markPartialPlanRow(
            partial_rows,
            partial_cols_start,
            partial_cols_end,
            row,
            col_start,
            col_end,
        );
    }
}

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

pub fn useViewportShiftForPartialPlan(
    cache_dirty: @TypeOf(RenderCache.init().dirty),
    viewport_shift_rows: i32,
) bool {
    return cache_dirty == .partial and viewport_shift_rows != 0;
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

pub fn markPartialPlanRow(
    partial_rows: []bool,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
    row: usize,
    col_start: usize,
    col_end: usize,
) void {
    const col_start_u16: u16 = @intCast(col_start);
    const col_end_u16: u16 = @intCast(col_end);
    partial_rows[row] = true;
    if (partial_cols_start[row] > col_start_u16) partial_cols_start[row] = col_start_u16;
    if (partial_cols_end[row] < col_end_u16) partial_cols_end[row] = col_end_u16;
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

pub fn summarizePartialPlan(
    partial_rows: []const bool,
    partial_cols_start: []const u16,
    partial_cols_end: []const u16,
) ?PartialPlanBounds {
    var first_row: ?usize = null;
    var last_row: usize = 0;
    var min_start: usize = 0;
    var max_end: usize = 0;

    for (partial_rows, 0..) |dirty, row| {
        if (!dirty) continue;
        if (first_row == null) {
            first_row = row;
            last_row = row;
            min_start = partial_cols_start[row];
            max_end = partial_cols_end[row];
            continue;
        }
        last_row = row;
        min_start = @min(min_start, partial_cols_start[row]);
        max_end = @max(max_end, partial_cols_end[row]);
    }

    if (first_row) |start_row| {
        return .{
            .start_row = start_row,
            .end_row = last_row,
            .start_col = min_start,
            .end_col = max_end,
        };
    }
    return null;
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
            markPartialPlanRow(
                partial_rows,
                partial_cols_start,
                partial_cols_end,
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

test "markPartialPlanRow preserves cursorcolumn row spans" {
    var partial_rows = [_]bool{false} ** 12;
    var partial_cols_start = [_]u16{99} ** 12;
    var partial_cols_end = [_]u16{0} ** 12;

    inline for (0..8) |row| {
        markPartialPlanRow(&partial_rows, &partial_cols_start, &partial_cols_end, row, 6, 6);
    }
    markPartialPlanRow(&partial_rows, &partial_cols_start, &partial_cols_end, 8, 4, 6);
    markPartialPlanRow(&partial_rows, &partial_cols_start, &partial_cols_end, 9, 4, 6);
    markPartialPlanRow(&partial_rows, &partial_cols_start, &partial_cols_end, 10, 33, 33);

    try std.testing.expectEqualSlices(
        bool,
        &[_]bool{ true, true, true, true, true, true, true, true, true, true, true, false },
        &partial_rows,
    );
    try std.testing.expectEqual(@as(u16, 6), partial_cols_start[0]);
    try std.testing.expectEqual(@as(u16, 6), partial_cols_end[7]);
    try std.testing.expectEqual(@as(u16, 4), partial_cols_start[8]);
    try std.testing.expectEqual(@as(u16, 6), partial_cols_end[9]);
    try std.testing.expectEqual(@as(u16, 33), partial_cols_start[10]);
    try std.testing.expectEqual(@as(u16, 33), partial_cols_end[10]);
}

test "markPartialPlanRow narrows cursorcolumn aggregate bounds" {
    var partial_rows = [_]bool{false} ** 12;
    var partial_cols_start = [_]u16{99} ** 12;
    var partial_cols_end = [_]u16{0} ** 12;

    inline for (0..8) |row| {
        markPartialPlanRow(&partial_rows, &partial_cols_start, &partial_cols_end, row, 6, 6);
    }
    markPartialPlanRow(&partial_rows, &partial_cols_start, &partial_cols_end, 8, 4, 6);
    markPartialPlanRow(&partial_rows, &partial_cols_start, &partial_cols_end, 9, 4, 6);
    markPartialPlanRow(&partial_rows, &partial_cols_start, &partial_cols_end, 10, 33, 33);

    const bounds = summarizePartialPlan(&partial_rows, &partial_cols_start, &partial_cols_end).?;
    try std.testing.expectEqual(@as(usize, 0), bounds.start_row);
    try std.testing.expectEqual(@as(usize, 10), bounds.end_row);
    try std.testing.expectEqual(@as(usize, 4), bounds.start_col);
    try std.testing.expectEqual(@as(usize, 33), bounds.end_col);

    // The important improvement is row-locality, not the union box itself:
    // rows 0..7 no longer inherit rows 8..10's wider columns.
    var row: usize = 0;
    while (row < 8) : (row += 1) {
        try std.testing.expectEqual(@as(u16, 6), partial_cols_start[row]);
        try std.testing.expectEqual(@as(u16, 6), partial_cols_end[row]);
    }
}

test "buildBasePartialPlan preserves cursorcolumn row-locality" {
    var partial_rows = [_]bool{false} ** 12;
    var partial_cols_start = [_]u16{99} ** 12;
    var partial_cols_end = [_]u16{0} ** 12;
    var dirty_rows = [_]bool{false} ** 12;
    var dirty_start = [_]u16{0} ** 12;
    var dirty_end = [_]u16{0} ** 12;

    inline for (0..8) |row| {
        dirty_rows[row] = true;
        dirty_start[row] = 6;
        dirty_end[row] = 6;
    }
    dirty_rows[8] = true;
    dirty_rows[9] = true;
    dirty_start[8] = 4;
    dirty_end[8] = 6;
    dirty_start[9] = 4;
    dirty_end[9] = 6;
    dirty_rows[10] = true;
    dirty_start[10] = 33;
    dirty_end[10] = 33;

    buildBasePartialPlan(
        &partial_rows,
        &partial_cols_start,
        &partial_cols_end,
        &dirty_rows,
        &dirty_start,
        &dirty_end,
        12,
        50,
        0,
        0,
        false,
    );

    const bounds = summarizePartialPlan(&partial_rows, &partial_cols_start, &partial_cols_end).?;
    try std.testing.expectEqual(@as(usize, 0), bounds.start_row);
    try std.testing.expectEqual(@as(usize, 10), bounds.end_row);
    try std.testing.expectEqual(@as(usize, 4), bounds.start_col);
    try std.testing.expectEqual(@as(usize, 33), bounds.end_col);

    var row: usize = 0;
    while (row < 8) : (row += 1) {
        try std.testing.expectEqual(@as(u16, 6), partial_cols_start[row]);
        try std.testing.expectEqual(@as(u16, 6), partial_cols_end[row]);
    }
    try std.testing.expectEqual(@as(u16, 4), partial_cols_start[8]);
    try std.testing.expectEqual(@as(u16, 6), partial_cols_end[9]);
    try std.testing.expectEqual(@as(u16, 33), partial_cols_start[10]);
    try std.testing.expectEqual(@as(u16, 33), partial_cols_end[10]);
}

test "buildPartialPlan reproduces cursorcolumn live draw shape" {
    var cache = RenderCache.init();
    defer cache.deinit(std.testing.allocator);

    cache.rows = 12;
    cache.cols = 50;
    try cache.dirty_rows.resize(std.testing.allocator, 12);
    try cache.dirty_cols_start.resize(std.testing.allocator, 12);
    try cache.dirty_cols_end.resize(std.testing.allocator, 12);
    try cache.cells.resize(std.testing.allocator, 12 * 50);

    @memset(cache.dirty_rows.items, false);
    @memset(cache.dirty_cols_start.items, 0);
    @memset(cache.dirty_cols_end.items, 0);
    @memset(cache.cells.items, std.mem.zeroes(@TypeOf(cache.cells.items[0])));

    inline for (0..8) |row| {
        cache.dirty_rows.items[row] = true;
        cache.dirty_cols_start.items[row] = 6;
        cache.dirty_cols_end.items[row] = 6;
    }
    cache.dirty_rows.items[8] = true;
    cache.dirty_rows.items[9] = true;
    cache.dirty_cols_start.items[8] = 4;
    cache.dirty_cols_end.items[8] = 6;
    cache.dirty_cols_start.items[9] = 4;
    cache.dirty_cols_end.items[9] = 6;
    cache.dirty_rows.items[10] = true;
    cache.dirty_cols_start.items[10] = 33;
    cache.dirty_cols_end.items[10] = 33;

    var partial_rows = [_]bool{false} ** 12;
    var partial_cols_start = [_]u16{99} ** 12;
    var partial_cols_end = [_]u16{0} ** 12;

    const bounds = buildPartialPlan(
        &cache,
        &partial_rows,
        &partial_cols_start,
        &partial_cols_end,
        0,
        0,
        false,
        false,
    ).?;

    try std.testing.expectEqual(@as(usize, 0), bounds.start_row);
    try std.testing.expectEqual(@as(usize, 10), bounds.end_row);
    try std.testing.expectEqual(@as(usize, 4), bounds.start_col);
    try std.testing.expectEqual(@as(usize, 33), bounds.end_col);

    var row: usize = 0;
    while (row < 8) : (row += 1) {
        try std.testing.expectEqual(@as(u16, 6), partial_cols_start[row]);
        try std.testing.expectEqual(@as(u16, 6), partial_cols_end[row]);
    }
    try std.testing.expectEqual(@as(u16, 4), partial_cols_start[8]);
    try std.testing.expectEqual(@as(u16, 6), partial_cols_end[9]);
    try std.testing.expectEqual(@as(u16, 33), partial_cols_start[10]);
    try std.testing.expectEqual(@as(u16, 33), partial_cols_end[10]);
}

test "addBlinkRowsToPartialPlan preserves row-local blink spans" {
    var cache = RenderCache.init();
    defer cache.deinit(std.testing.allocator);

    cache.rows = 4;
    cache.cols = 8;
    try cache.cells.resize(std.testing.allocator, cache.rows * cache.cols);
    @memset(cache.cells.items, std.mem.zeroes(@TypeOf(cache.cells.items[0])));

    cache.cells.items[1].attrs.blink = true;
    cache.cells.items[1].width = 1;
    cache.cells.items[2 * cache.cols + 4].attrs.blink = true;
    cache.cells.items[2 * cache.cols + 4].width = 1;

    var partial_rows = [_]bool{false} ** 4;
    var partial_cols_start = [_]u16{99} ** 4;
    var partial_cols_end = [_]u16{0} ** 4;

    addBlinkRowsToPartialPlan(&cache, &partial_rows, &partial_cols_start, &partial_cols_end);

    try std.testing.expectEqualSlices(bool, &[_]bool{ true, false, true, false }, &partial_rows);
    try std.testing.expectEqual(@as(u16, 1), partial_cols_start[0]);
    try std.testing.expectEqual(@as(u16, 1), partial_cols_end[0]);
    try std.testing.expectEqual(@as(u16, 4), partial_cols_start[2]);
    try std.testing.expectEqual(@as(u16, 4), partial_cols_end[2]);
}

test "buildPartialPlan keeps blink-only updates row-local" {
    var cache = RenderCache.init();
    defer cache.deinit(std.testing.allocator);

    cache.rows = 4;
    cache.cols = 8;
    cache.dirty = .none;
    try cache.cells.resize(std.testing.allocator, cache.rows * cache.cols);
    @memset(cache.cells.items, std.mem.zeroes(@TypeOf(cache.cells.items[0])));

    cache.cells.items[1].attrs.blink = true;
    cache.cells.items[1].width = 1;
    cache.cells.items[2 * cache.cols + 4].attrs.blink = true;
    cache.cells.items[2 * cache.cols + 4].width = 1;

    var partial_rows = [_]bool{false} ** 4;
    var partial_cols_start = [_]u16{99} ** 4;
    var partial_cols_end = [_]u16{0} ** 4;

    const bounds = buildPartialPlan(
        &cache,
        &partial_rows,
        &partial_cols_start,
        &partial_cols_end,
        0,
        0,
        false,
        true,
    ).?;

    try std.testing.expectEqual(@as(usize, 0), bounds.start_row);
    try std.testing.expectEqual(@as(usize, 2), bounds.end_row);
    try std.testing.expectEqual(@as(usize, 1), bounds.start_col);
    try std.testing.expectEqual(@as(usize, 4), bounds.end_col);
    try std.testing.expectEqualSlices(bool, &[_]bool{ true, false, true, false }, &partial_rows);
}

test "formatPartialPlanRows summarizes row-local spans" {
    var partial_rows = [_]bool{ true, false, true, true };
    var partial_cols_start = [_]u16{ 6, 0, 4, 33 };
    var partial_cols_end = [_]u16{ 6, 0, 6, 33 };
    var buf: [64]u8 = undefined;

    const summary = formatPartialPlanRows(
        &buf,
        &partial_rows,
        &partial_cols_start,
        &partial_cols_end,
        8,
    );

    try std.testing.expectEqualStrings("0:6-6 2:4-6 3:33-33", summary);
}

test "formatPartialPlanRows truncates long plans" {
    var partial_rows = [_]bool{ true, true, true, true };
    var partial_cols_start = [_]u16{ 1, 2, 3, 4 };
    var partial_cols_end = [_]u16{ 1, 2, 3, 4 };
    var buf: [64]u8 = undefined;

    const summary = formatPartialPlanRows(
        &buf,
        &partial_rows,
        &partial_cols_start,
        &partial_cols_end,
        2,
    );

    try std.testing.expectEqualStrings("0:1-1 1:2-2 ...", summary);
}

test "formatPartialPlanRows never truncates a row token mid-span" {
    var partial_rows = [_]bool{true} ** 16;
    var partial_cols_start = [_]u16{146} ** 16;
    var partial_cols_end = [_]u16{148} ** 16;
    var buf: [40]u8 = undefined;

    const summary = formatPartialPlanRows(
        &buf,
        &partial_rows,
        &partial_cols_start,
        &partial_cols_end,
        16,
    );

    try std.testing.expect(std.mem.endsWith(u8, summary, "..."));
    try std.testing.expect(std.mem.indexOf(u8, summary, "146-13") == null);
}
