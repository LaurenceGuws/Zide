const std = @import("std");
const screen_mod = @import("../../model/screen.zig");
const types = @import("../../model/types.zig");
const kitty_mod = @import("../../kitty/graphics.zig");
const render_cache_mod = @import("render_cache.zig");
const app_logger = @import("../../../app_logger.zig");
const terminal_publication = @import("terminal_publication.zig");
const damage_mod = @import("view_cache_damage.zig");
const publication = @import("view_cache_publication.zig");
const plan_mod = @import("view_cache_plan.zig");
const refinement = @import("view_cache_refinement.zig");
const selection_dirty = @import("view_cache_selection_dirty.zig");
const selection_projection = @import("view_cache_selection.zig");

const RenderCache = render_cache_mod.RenderCache;
const Cell = types.Cell;

fn shouldPreserveUnpresentedDirtyPublication(
    active_cache: *const RenderCache,
    cache: *const RenderCache,
    presented_generation: u64,
) bool {
    return active_cache.generation != presented_generation and
        active_cache.dirty != .none and
        cache.dirty == .none and
        active_cache.rows == cache.rows and
        active_cache.cols == cache.cols;
}

fn setFullDamageMetadata(cache: *RenderCache, rows: usize, cols: usize) void {
    cache.dirty = .full;
    cache.damage = .{
        .start_row = 0,
        .end_row = if (rows > 0) rows - 1 else 0,
        .start_col = 0,
        .end_col = if (cols > 0) cols - 1 else 0,
    };
    var row_idx: usize = 0;
    while (row_idx < rows) : (row_idx += 1) {
        cache.dirty_rows.items[row_idx] = true;
        cache.row_dirty_span_counts.items[row_idx] = if (cols > 0) 1 else 0;
        cache.row_dirty_span_overflow.items[row_idx] = false;
        cache.row_dirty_spans.items[row_idx][0] = .{
            .start = 0,
            .end = if (cols > 0) @intCast(cols - 1) else 0,
        };
        cache.dirty_cols_start.items[row_idx] = 0;
        cache.dirty_cols_end.items[row_idx] = if (cols > 0) @intCast(cols - 1) else 0;
        var span_idx: usize = 1;
        while (span_idx < screen_mod.max_row_dirty_spans) : (span_idx += 1) {
            cache.row_dirty_spans.items[row_idx][span_idx] = publication.invalidRowSpan(cols);
        }
    }
}

fn preserveUnpresentedDirtyPublication(cache: *RenderCache, active_cache: *const RenderCache, rows: usize, cols: usize) []const u8 {
    if (active_cache.dirty == .full or active_cache.viewport_shift_rows != 0) {
        setFullDamageMetadata(cache, rows, cols);
        cache.full_dirty_reason = active_cache.full_dirty_reason;
        cache.full_dirty_seq = active_cache.full_dirty_seq;
        cache.viewport_shift_rows = 0;
        cache.viewport_shift_exposed_only = false;
        return "promote_full";
    }

    cache.dirty = active_cache.dirty;
    cache.damage = active_cache.damage;
    std.mem.copyForwards(bool, cache.dirty_rows.items, active_cache.dirty_rows.items);
    std.mem.copyForwards(u8, cache.row_dirty_span_counts.items, active_cache.row_dirty_span_counts.items);
    std.mem.copyForwards(bool, cache.row_dirty_span_overflow.items, active_cache.row_dirty_span_overflow.items);
    std.mem.copyForwards([screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan, cache.row_dirty_spans.items, active_cache.row_dirty_spans.items);
    std.mem.copyForwards(u16, cache.dirty_cols_start.items, active_cache.dirty_cols_start.items);
    std.mem.copyForwards(u16, cache.dirty_cols_end.items, active_cache.dirty_cols_end.items);
    cache.viewport_shift_rows = 0;
    cache.viewport_shift_exposed_only = false;
    return "carry_partial";
}

pub fn updateViewCacheNoLockTagged(self: anytype, generation: u64, scroll_offset: usize, source: []const u8) void {
    _ = source;
    const screen = self.core.activeScreenConst();
    const view = screen.snapshotView();
    const screen_reverse = screen.screen_reverse;
    const rows = view.rows;
    const cols = view.cols;
    const publication_target = publication.beginCachePublication(self);
    var cache = publication_target.target_cache;
    if (self.core.active != .alt and !(scroll_offset == 0 and self.core.history.view_cols == cols and self.core.history.view_row_count_generation == self.core.history.scrollback_generation)) {
        self.core.history.ensureViewCache(@intCast(cols), self.core.primary.defaultCell());
    }
    const history_len = if (self.core.active == .alt) 0 else self.core.history.scrollbackCount();
    const total_lines = history_len + rows;
    const max_offset = if (total_lines > rows) total_lines - rows else 0;
    const clamped_offset = if (scroll_offset > max_offset) max_offset else scroll_offset;
    const visible_history_generation: u64 = if (self.core.active == .alt or clamped_offset == 0)
        0
    else
        self.core.history.view_generation;
    const kitty_generation = kitty_mod.kittyStateConst(self).generation;
    const clear_generation = self.core.clear_generation.load(.acquire);
    const selection_active = self.core.active != .alt and self.core.history.selectionState() != null;
    const active_cache = publication_target.active_cache;
    const presented_generation = terminal_publication.presentedGeneration(self);

    if (publication.canSkipPublish(active_cache, .{
        .rows = rows,
        .cols = cols,
        .history_len = history_len,
        .visible_history_generation = visible_history_generation,
        .scroll_offset = clamped_offset,
        .generation = generation,
        .clear_generation = clear_generation,
        .alt_active = self.core.active == .alt,
        .selection_active = selection_active,
        .sync_updates_active = self.core.sync_updates_active,
        .screen_reverse = screen_reverse,
        .kitty_generation = kitty_generation,
        .cursor = view.cursor,
        .cursor_style = view.cursor_style,
        .cursor_visible = view.cursor_visible,
    }, total_lines, view.dirty)) {
        return;
    }
    if (publication.canCleanAdvancePublish(active_cache, .{
        .rows = rows,
        .cols = cols,
        .history_len = history_len,
        .visible_history_generation = visible_history_generation,
        .scroll_offset = clamped_offset,
        .clear_generation = clear_generation,
        .alt_active = self.core.active == .alt,
        .selection_active = selection_active,
        .sync_updates_active = self.core.sync_updates_active,
        .screen_reverse = screen_reverse,
        .kitty_generation = kitty_generation,
    }, total_lines, view.dirty)) {
        // Generation can advance without visible cell changes (e.g. cursor-only shell
        // movement). Keep overlay-facing state current even when cell contents stay the same.
        publication.applyCleanAdvancePublish(active_cache, generation, view.cursor, view.cursor_style, view.cursor_visible);
        return;
    }
    if (rows == 0 or cols == 0) {
        cache.cells.clearRetainingCapacity();
        cache.dirty_rows.clearRetainingCapacity();
        cache.dirty_cols_start.clearRetainingCapacity();
        cache.dirty_cols_end.clearRetainingCapacity();
        cache.selection_rows.clearRetainingCapacity();
        cache.selection_cols_start.clearRetainingCapacity();
        cache.selection_cols_end.clearRetainingCapacity();
        cache.row_hashes.clearRetainingCapacity();
        cache.rows = 0;
        cache.cols = 0;
        cache.history_len = history_len;
        cache.visible_history_generation = visible_history_generation;
        cache.generation = generation;
        cache.scroll_offset = clamped_offset;
        cache.cursor = view.cursor;
        cache.cursor_style = view.cursor_style;
        cache.cursor_visible = view.cursor_visible;
        cache.dirty = .full;
        cache.damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
        cache.full_dirty_reason = view.full_dirty_reason;
        cache.full_dirty_seq = view.full_dirty_seq;
        publication.assignPublishedCacheState(
            cache,
            0,
            0,
            history_len,
            visible_history_generation,
            generation,
            clamped_offset,
            view.cursor,
            view.cursor_style,
            view.cursor_visible,
            self.core.active == .alt,
            self.core.sync_updates_active,
            screen_reverse,
            clear_generation,
            0,
            false,
        );
        updateKittyViewNoLock(self, cache);
        publication.finishCachePublication(self, publication_target);
        return;
    }

    const view_count = rows * cols;
    const log = app_logger.logger("terminal.view_cache");
    cache.cells.resize(self.allocator, view_count) catch |err| {
        log.logf(.warning, "view cache resize failed field=cells view_count={d} err={s}", .{ view_count, @errorName(err) });
        return;
    };
    cache.dirty_rows.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=dirty_rows rows={d} err={s}", .{ rows, @errorName(err) });
        return;
    };
    cache.row_dirty_span_counts.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=row_dirty_span_counts rows={d} err={s}", .{ rows, @errorName(err) });
        return;
    };
    cache.row_dirty_span_overflow.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=row_dirty_span_overflow rows={d} err={s}", .{ rows, @errorName(err) });
        return;
    };
    cache.row_dirty_spans.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=row_dirty_spans rows={d} err={s}", .{ rows, @errorName(err) });
        return;
    };
    cache.dirty_cols_start.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=dirty_cols_start rows={d} err={s}", .{ rows, @errorName(err) });
        return;
    };
    cache.dirty_cols_end.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=dirty_cols_end rows={d} err={s}", .{ rows, @errorName(err) });
        return;
    };
    cache.selection_rows.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=selection_rows rows={d} err={s}", .{ rows, @errorName(err) });
        return;
    };
    cache.selection_cols_start.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=selection_cols_start rows={d} err={s}", .{ rows, @errorName(err) });
        return;
    };
    cache.selection_cols_end.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=selection_cols_end rows={d} err={s}", .{ rows, @errorName(err) });
        return;
    };
    cache.row_hashes.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=row_hashes rows={d} err={s}", .{ rows, @errorName(err) });
        return;
    };
    const start_line = if (total_lines > rows + clamped_offset)
        total_lines - rows - clamped_offset
    else
        0;
    const plan = plan_mod.buildPublicationPlan(
        visible_history_generation,
        active_cache.visible_history_generation,
        clamped_offset,
        active_cache.scroll_offset,
        history_len,
        active_cache.history_len,
        rows,
        active_cache.rows,
        cols,
        active_cache.cols,
        selection_active,
        active_cache.hasSelection(),
        view.dirty,
        view.dirty == .none,
        presented_generation,
        active_cache.generation,
        self.core.active == .alt,
        active_cache.alt_active,
    );
    publication.populateVisibleCells(self, cache, view, history_len, start_line, rows, cols);
    var row: usize = 0;
    selection_projection.projectSelection(self, cache, total_lines, start_line, rows, cols, selection_active);
    if (plan.needs_full_damage) {
        row = 0;
        while (row < rows) : (row += 1) {
            const row_start = row * cols;
            const row_cells = cache.cells.items[row_start .. row_start + cols];
            cache.row_hashes.items[row] = publication.hashRow(row_cells);
        }
    }
    publication.assignDirtyRows(cache, view, plan, rows);
    publication.assignDirtySpans(cache, view, plan, rows, cols);
    if (plan.can_publish_scroll_shift) {
        publication.assignDirtyColsFallback(cache, cols);
        publication.assignScrollShiftDirtyRows(cache, plan, rows);
    } else if (publication.assignDirtyColsFromView(cache, view, plan, rows)) {} else {
        publication.assignDirtyColsFallback(cache, cols);
    }

    if (!plan.needs_full_damage and active_cache.rows == rows and active_cache.cols == cols) {
        selection_dirty.applySelectionDirtyExpansion(
            cache,
            active_cache,
            rows,
            cols,
            active_cache.generation == presented_generation,
        );
    }

    publication.assignPublishedCacheState(
        cache,
        rows,
        cols,
        history_len,
        visible_history_generation,
        generation,
        clamped_offset,
        view.cursor,
        view.cursor_style,
        view.cursor_visible,
        self.core.active == .alt,
        self.core.sync_updates_active,
        screen_reverse,
        clear_generation,
        plan.viewport_shift_rows,
        plan.can_publish_scroll_shift,
    );
    damage_mod.assignBaseDamage(cache, view, plan, rows, cols);
    const kitty_generation_unchanged = active_cache.kitty_generation == kitty_generation;

    if (publication.canAssignProjectedDiffDamage(plan, view.dirty, active_cache, cache, rows, cols, presented_generation)) {
        publication.assignProjectedDiffDamage(cache, active_cache, rows, cols);
    }
    publication.assignFullDirtyMetadata(
        cache,
        active_cache,
        rows,
        cols,
        plan,
        self.core.active == .alt,
        view.dirty,
        view.full_dirty_reason,
        view.full_dirty_seq,
    );

    if (refinement.canRefineRowHashDamage(plan, view.dirty, active_cache, rows, cols, kitty_generation_unchanged, presented_generation)) {
        refinement.refineRowHashDamage(
            cache,
            active_cache,
            rows,
            cols,
            active_cache.generation == presented_generation,
            active_cache.generation != presented_generation,
        );
    }

    // Cursor is rendered as a UI overlay in terminal_widget_draw, so cursor visibility
    // changes should not dirty the cached terminal texture rows every frame.

    if (shouldPreserveUnpresentedDirtyPublication(active_cache, cache, presented_generation)) {
        _ = preserveUnpresentedDirtyPublication(cache, active_cache, rows, cols);
    }
    updateKittyViewNoLock(self, cache);
    publication.finishCachePublication(self, publication_target);
}

pub fn updateViewCacheNoLock(self: anytype, generation: u64, scroll_offset: usize) void {
    updateViewCacheNoLockTagged(self, generation, scroll_offset, "direct");
}

pub fn updateViewCacheForScroll(self: anytype) void {
    if (self.control.state_mutex.tryLock()) {
        defer self.control.state_mutex.unlock();
        const request = terminal_publication.takePendingViewRefreshRequest(self) orelse return;
        updateViewCacheNoLockTagged(self, request.generation, request.scroll_offset, "view_cache_for_scroll");
    }
}

pub fn updateViewCacheForScrollLocked(self: anytype) void {
    const request = terminal_publication.takePendingViewRefreshRequest(self) orelse return;
    updateViewCacheNoLockTagged(self, request.generation, request.scroll_offset, "view_cache_for_scroll_locked");
}

fn updateKittyViewNoLock(self: anytype, cache: *RenderCache) void {
    const kitty = kitty_mod.kittyStateConst(self);
    const kitty_generation = kitty.generation;
    if (kitty_generation == cache.kitty_generation) return;

    const log = app_logger.logger("terminal.view_cache");
    cache.kitty_images.resize(self.allocator, kitty.images.items.len) catch |err| {
        log.logf(.warning, "view cache resize failed field=kitty_images len={d} err={s}", .{ kitty.images.items.len, @errorName(err) });
        return;
    };
    cache.kitty_placements.resize(self.allocator, kitty.placements.items.len) catch |err| {
        log.logf(.warning, "view cache resize failed field=kitty_placements len={d} err={s}", .{ kitty.placements.items.len, @errorName(err) });
        return;
    };
    std.mem.copyForwards(kitty_mod.KittyImage, cache.kitty_images.items, kitty.images.items);
    std.mem.copyForwards(kitty_mod.KittyPlacement, cache.kitty_placements.items, kitty.placements.items);
    if (cache.kitty_placements.items.len > 1) {
        std.sort.block(kitty_mod.KittyPlacement, cache.kitty_placements.items, {}, struct {
            fn lessThan(_: void, a: kitty_mod.KittyPlacement, b: kitty_mod.KittyPlacement) bool {
                if (a.z == b.z) {
                    if (a.row == b.row) return a.col < b.col;
                    return a.row < b.row;
                }
                return a.z < b.z;
            }
        }.lessThan);
    }
    cache.kitty_generation = kitty_generation;
}
