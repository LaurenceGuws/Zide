const std = @import("std");
const publication = @import("view_cache_publication.zig");

pub fn assignBaseDamage(
    cache: anytype,
    view: anytype,
    plan: anytype,
    rows: usize,
    cols: usize,
) void {
    cache.dirty = if (plan.needs_full_damage)
        .full
    else if (plan.can_publish_scroll_shift)
        .partial
    else if (plan.visible_history_changed and view.dirty == .none)
        .partial
    else
        view.dirty;

    cache.damage = if (plan.needs_full_damage)
        .{ .start_row = 0, .end_row = if (rows > 0) rows - 1 else 0, .start_col = 0, .end_col = if (cols > 0) cols - 1 else 0 }
    else if (plan.can_publish_scroll_shift and plan.viewport_shift_rows > 0)
        .{ .start_row = rows - plan.shift_abs, .end_row = rows - 1, .start_col = 0, .end_col = if (cols > 0) cols - 1 else 0 }
    else if (plan.can_publish_scroll_shift)
        .{ .start_row = 0, .end_row = plan.shift_abs - 1, .start_col = 0, .end_col = if (cols > 0) cols - 1 else 0 }
    else if (plan.visible_history_changed and view.dirty == .none)
        .{ .start_row = 0, .end_row = if (rows > 0) rows - 1 else 0, .start_col = 0, .end_col = if (cols > 0) cols - 1 else 0 }
    else
        view.damage;
}

pub fn widenPartialDamage(cache: anytype, rows: usize, cols: usize) void {
    if (cache.dirty != .partial or cols == 0) return;

    var row_idx: usize = 0;
    while (row_idx < rows) : (row_idx += 1) {
        if (!cache.dirty_rows.items[row_idx]) continue;
        const start_col = cache.dirty_cols_start.items[row_idx];
        const end_col = cache.dirty_cols_end.items[row_idx];
        if (start_col > 0) {
            cache.dirty_cols_start.items[row_idx] = start_col - 1;
            cache.damage.start_col = @min(cache.damage.start_col, @as(usize, start_col - 1));
        }
        const end_col_usize = @as(usize, end_col);
        if (end_col_usize + 1 < cols) {
            cache.dirty_cols_end.items[row_idx] = @intCast(end_col_usize + 1);
            cache.damage.end_col = @max(cache.damage.end_col, end_col_usize + 1);
        }
        publication.clearRowDirtySpans(cache, row_idx, cols);
        publication.addRowDirtySpan(
            cache,
            row_idx,
            cache.dirty_cols_start.items[row_idx],
            cache.dirty_cols_end.items[row_idx],
            cols,
        );
    }
}

test "assignBaseDamage exposes only shifted rows for scroll shift publication" {
    const screen = @import("../model/screen.zig");
    var cache = @import("render_cache.zig").RenderCache.init();

    assignBaseDamage(
        &cache,
        .{
            .dirty = screen.Dirty.none,
            .damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 },
        },
        .{
            .needs_full_damage = false,
            .can_publish_scroll_shift = true,
            .viewport_shift_rows = 1,
            .shift_abs = 1,
            .visible_history_changed = true,
        },
        12,
        40,
    );

    try std.testing.expectEqual(screen.Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 11), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 11), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 39), cache.damage.end_col);
}

test "assignBaseDamage uses full viewport when history changed without row-local truth" {
    const screen = @import("../model/screen.zig");
    var cache = @import("render_cache.zig").RenderCache.init();

    assignBaseDamage(
        &cache,
        .{
            .dirty = screen.Dirty.none,
            .damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 },
        },
        .{
            .needs_full_damage = false,
            .can_publish_scroll_shift = false,
            .viewport_shift_rows = 0,
            .shift_abs = 0,
            .visible_history_changed = true,
        },
        12,
        40,
    );

    try std.testing.expectEqual(screen.Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 11), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 39), cache.damage.end_col);
}
