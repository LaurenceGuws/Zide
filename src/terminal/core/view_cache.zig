const std = @import("std");
const types = @import("../model/types.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const render_cache_mod = @import("render_cache.zig");
const app_logger = @import("../../app_logger.zig");
const damage_mod = @import("view_cache_damage.zig");
const publication = @import("view_cache_publication.zig");
const plan_mod = @import("view_cache_plan.zig");
const refinement = @import("view_cache_refinement.zig");
const selection_dirty = @import("view_cache_selection_dirty.zig");
const selection_projection = @import("view_cache_selection.zig");

const RenderCache = render_cache_mod.RenderCache;
const Cell = types.Cell;

pub fn updateViewCacheNoLock(self: anytype, generation: u64, scroll_offset: usize) void {
    const fullwidth_origin_log = app_logger.logger("terminal.ui.row_fullwidth_origin");
    const perf_log = app_logger.logger("terminal.view_cache");
    const update_start_ns = std.time.nanoTimestamp();
    var snapshot_ms: f64 = 0.0;
    var ensure_view_cache_ms: f64 = 0.0;
    var plan_ms: f64 = 0.0;
    var resize_ms: f64 = 0.0;
    var copy_rows_ms: f64 = 0.0;
    var selection_ms: f64 = 0.0;
    var damage_ms: f64 = 0.0;
    var kitty_ms: f64 = 0.0;
    const snapshot_start_ns = std.time.nanoTimestamp();
    const screen = self.core.activeScreenConst();
    const view = screen.snapshotView();
    snapshot_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - snapshot_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    const screen_reverse = screen.screen_reverse;
    const rows = view.rows;
    const cols = view.cols;
    const active_index = self.render_cache_index.load(.acquire);
    const target_index: u8 = if (active_index == 0) 1 else 0;
    var cache = &self.render_caches[target_index];
    if (self.core.active != .alt and !(scroll_offset == 0 and self.core.history.view_cols == cols and self.core.history.view_row_count_generation == self.core.history.scrollback_generation)) {
        const ensure_view_cache_start_ns = std.time.nanoTimestamp();
        self.core.history.ensureViewCache(@intCast(cols), self.core.primary.defaultCell());
        ensure_view_cache_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - ensure_view_cache_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
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
    const mouse_reporting_active = self.mouseReportingEnabled();
    const selection_active = self.core.active != .alt and self.core.history.selectionState() != null;
    const active_cache = &self.render_caches[active_index];
    const presented_generation = self.presentedGeneration();
    if (active_cache.rows == rows and
        active_cache.cols == cols and
        active_cache.history_len == history_len and
        active_cache.total_lines == total_lines and
        active_cache.visible_history_generation == visible_history_generation and
        active_cache.scroll_offset == clamped_offset and
        active_cache.generation == generation and
        active_cache.clear_generation == clear_generation and
        active_cache.alt_active == (self.core.active == .alt) and
        active_cache.sync_updates_active == self.core.sync_updates_active and
        active_cache.screen_reverse == screen_reverse and
        active_cache.kitty_generation == kitty_generation and
        std.meta.eql(active_cache.cursor, view.cursor) and
        std.meta.eql(active_cache.cursor_style, view.cursor_style) and
        active_cache.cursor_visible == view.cursor_visible and
        view.dirty == .none and
        active_cache.dirty == .none and
        !selection_active and
        !active_cache.selection_active)
    {
        return;
    }
    if (active_cache.rows == rows and
        active_cache.cols == cols and
        active_cache.history_len == history_len and
        active_cache.total_lines == total_lines and
        active_cache.visible_history_generation == visible_history_generation and
        active_cache.scroll_offset == clamped_offset and
        active_cache.clear_generation == clear_generation and
        active_cache.alt_active == (self.core.active == .alt) and
        active_cache.sync_updates_active == self.core.sync_updates_active and
        active_cache.screen_reverse == screen_reverse and
        active_cache.kitty_generation == kitty_generation and
        view.dirty == .none and
        active_cache.dirty == .none and
        !selection_active and
        !active_cache.selection_active)
    {
        // Generation can advance without visible cell changes (e.g. cursor-only shell
        // movement). Keep overlay-facing state current even when cell contents stay the same.
        active_cache.generation = generation;
        active_cache.cursor = view.cursor;
        active_cache.cursor_style = view.cursor_style;
        active_cache.cursor_visible = view.cursor_visible;
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
        cache.total_lines = total_lines;
        cache.visible_history_generation = visible_history_generation;
        cache.generation = generation;
        cache.scroll_offset = clamped_offset;
        cache.cursor = view.cursor;
        cache.cursor_style = view.cursor_style;
        cache.cursor_visible = view.cursor_visible;
        cache.has_blink = false;
        cache.dirty = .full;
        cache.damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
        cache.full_dirty_reason = view.full_dirty_reason;
        cache.full_dirty_seq = view.full_dirty_seq;
        cache.alt_active = self.core.active == .alt;
        cache.selection_active = selection_active;
        cache.sync_updates_active = self.core.sync_updates_active;
        cache.screen_reverse = screen_reverse;
        cache.mouse_reporting_active = mouse_reporting_active;
        cache.clear_generation = clear_generation;
        cache.viewport_shift_rows = 0;
        cache.viewport_shift_exposed_only = false;
        updateKittyViewNoLock(self, cache);
        self.render_cache_index.store(target_index, .release);
        return;
    }

    const resize_start_ns = std.time.nanoTimestamp();
    const view_count = rows * cols;
    const log = perf_log;
    cache.cells.resize(self.allocator, view_count) catch |err| {
        log.logf(.warning, "view cache resize failed field=cells view_count={d} err={s}", .{ view_count, @errorName(err) });
        return;
    };
    cache.dirty_rows.resize(self.allocator, rows) catch |err| {
        log.logf(.warning, "view cache resize failed field=dirty_rows rows={d} err={s}", .{ rows, @errorName(err) });
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
    resize_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - resize_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));

    const start_line = if (total_lines > rows + clamped_offset)
        total_lines - rows - clamped_offset
    else
        0;
    const plan_start_ns = std.time.nanoTimestamp();
    const plan = plan_mod.buildPublicationPlan(
        visible_history_generation,
        active_cache.visible_history_generation,
        clamped_offset,
        active_cache.scroll_offset,
        history_len,
        active_cache.history_len,
        total_lines,
        active_cache.total_lines,
        rows,
        active_cache.rows,
        cols,
        active_cache.cols,
        selection_active,
        active_cache.selection_active,
        view.dirty,
        view.dirty == .none,
        presented_generation,
        active_cache.generation,
        self.core.active == .alt,
        active_cache.alt_active,
    );
    plan_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - plan_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    const copy_rows_start_ns = std.time.nanoTimestamp();
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        const global_row = start_line + row;
        const row_start = row * cols;
        const row_dest = cache.cells.items[row_start .. row_start + cols];
        if (global_row < history_len) {
            if (self.core.history.scrollbackRow(global_row)) |history_row| {
                std.mem.copyForwards(Cell, row_dest, history_row[0..cols]);
            } else {
                std.mem.copyForwards(Cell, row_dest, view.cells[0..cols]);
            }
        } else {
            const grid_row = global_row - history_len;
            const src_start = grid_row * cols;
            std.mem.copyForwards(Cell, row_dest, view.cells[src_start .. src_start + cols]);
        }
    }
    copy_rows_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - copy_rows_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));

    const selection_start_ns = std.time.nanoTimestamp();
    selection_projection.projectSelection(self, cache, total_lines, start_line, rows, cols, selection_active);
    if (plan.needs_full_damage) {
        row = 0;
        while (row < rows) : (row += 1) {
            const row_start = row * cols;
            const row_cells = cache.cells.items[row_start .. row_start + cols];
            cache.row_hashes.items[row] = publication.hashRow(row_cells);
        }
    }
    selection_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - selection_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));

    const damage_start_ns = std.time.nanoTimestamp();
    if (plan.can_publish_scroll_shift) {
        for (cache.dirty_rows.items) |*row_dirty| {
            row_dirty.* = false;
        }
    } else if (view.dirty_rows.len == rows and !plan.needs_full_damage and !plan.visible_history_changed) {
        std.mem.copyForwards(bool, cache.dirty_rows.items, view.dirty_rows);
    } else {
        for (cache.dirty_rows.items) |*row_dirty| {
            row_dirty.* = true;
        }
    }
    if (plan.can_publish_scroll_shift) {
        for (cache.dirty_cols_start.items, cache.dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = 0;
            col_end.* = if (cols > 0) @intCast(cols - 1) else 0;
        }
        if (plan.viewport_shift_rows > 0) {
            var row_idx = rows - plan.shift_abs;
            while (row_idx < rows) : (row_idx += 1) {
                cache.dirty_rows.items[row_idx] = true;
            }
        } else {
            var row_idx: usize = 0;
            while (row_idx < plan.shift_abs) : (row_idx += 1) {
                cache.dirty_rows.items[row_idx] = true;
            }
        }
    } else if (view.dirty_cols_start.len == rows and view.dirty_cols_end.len == rows and !plan.needs_full_damage and !plan.visible_history_changed) {
        std.mem.copyForwards(u16, cache.dirty_cols_start.items, view.dirty_cols_start);
        std.mem.copyForwards(u16, cache.dirty_cols_end.items, view.dirty_cols_end);
        if (cols > 0 and view.dirty == .partial) {
            var logged: usize = 0;
            var row_idx: usize = 0;
            while (row_idx < rows and logged < 5) : (row_idx += 1) {
                if (!cache.dirty_rows.items[row_idx]) continue;
                if (cache.dirty_cols_start.items[row_idx] != 0) continue;
                if (@as(usize, cache.dirty_cols_end.items[row_idx]) != cols - 1) continue;
                fullwidth_origin_log.logf(
                    .info,
                    "source=view row={d} reason=copied_from_view cols=0..{d} dirty={s} damage_rows={d} damage_cols={d} rows={d} cols={d}",
                    .{
                        row_idx,
                        cols - 1,
                        @tagName(view.dirty),
                        if (view.damage.end_row >= view.damage.start_row) view.damage.end_row - view.damage.start_row + 1 else 0,
                        if (view.damage.end_col >= view.damage.start_col) view.damage.end_col - view.damage.start_col + 1 else 0,
                        rows,
                        cols,
                    },
                );
                logged += 1;
            }
        }
    } else {
        for (cache.dirty_cols_start.items, cache.dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = 0;
            col_end.* = if (cols > 0) @intCast(cols - 1) else 0;
        }
    }

    if (!plan.needs_full_damage and active_cache.rows == rows and active_cache.cols == cols) {
        selection_dirty.applySelectionDirtyExpansion(
            cache,
            active_cache,
            rows,
            cols,
            fullwidth_origin_log,
            active_cache.generation == presented_generation,
        );
    }

    cache.rows = rows;
    cache.cols = cols;
    cache.history_len = history_len;
    cache.total_lines = total_lines;
    cache.visible_history_generation = visible_history_generation;
    cache.generation = generation;
    cache.scroll_offset = clamped_offset;
    cache.cursor = view.cursor;
    cache.cursor_style = view.cursor_style;
    cache.cursor_visible = view.cursor_visible;
    cache.has_blink = false;
    for (cache.cells.items) |cell| {
        if (cell.attrs.blink) {
            cache.has_blink = true;
            break;
        }
    }
    damage_mod.assignBaseDamage(cache, view, plan, rows, cols);
    const kitty_generation_unchanged = active_cache.kitty_generation == kitty_generation;

    if (!plan.needs_full_damage and
        !plan.can_publish_scroll_shift and
        plan.visible_history_changed and
        view.dirty == .none and
        active_cache.rows == rows and
        active_cache.cols == cols and
        active_cache.generation == presented_generation and
        active_cache.cells.items.len == cache.cells.items.len)
    {
        publication.assignProjectedDiffDamage(cache, active_cache, rows, cols);
    }
    if (plan.needs_full_damage) {
        const forced_reason = publication.pickForcedFullDirtyReason(
            rows,
            active_cache.rows,
            cols,
            active_cache.cols,
            plan.requires_full_damage_for_scroll_offset_change,
            self.core.active == .alt,
            active_cache.alt_active,
            view.dirty,
            view.full_dirty_reason,
        );
        cache.full_dirty_reason = forced_reason;
        cache.full_dirty_seq = active_cache.full_dirty_seq +% 1;
    } else {
        cache.full_dirty_reason = view.full_dirty_reason;
        cache.full_dirty_seq = view.full_dirty_seq;
    }

    if (!plan.needs_full_damage and
        !plan.can_publish_scroll_shift and
        (view.dirty == .partial or plan.visible_history_changed) and
        active_cache.rows == rows and
        active_cache.cols == cols and
        kitty_generation_unchanged and
        active_cache.row_hashes.items.len == rows and
        (active_cache.generation == presented_generation or active_cache.dirty == .partial))
    {
        refinement.refineRowHashDamage(
            cache,
            active_cache,
            rows,
            cols,
            fullwidth_origin_log,
            active_cache.generation == presented_generation,
            active_cache.generation != presented_generation,
        );
    }

    // Cursor is rendered as a UI overlay in terminal_widget_draw, so cursor visibility
    // changes should not dirty the cached terminal texture rows every frame.

    cache.alt_active = self.core.active == .alt;
    cache.selection_active = selection_active;
    cache.sync_updates_active = self.core.sync_updates_active;
    cache.screen_reverse = screen_reverse;
    cache.mouse_reporting_active = mouse_reporting_active;
    cache.clear_generation = clear_generation;
    cache.viewport_shift_rows = plan.viewport_shift_rows;
    cache.viewport_shift_exposed_only = plan.can_publish_scroll_shift;
    damage_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - damage_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    const kitty_start_ns = std.time.nanoTimestamp();
    updateKittyViewNoLock(self, cache);
    kitty_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - kitty_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    self.render_cache_index.store(target_index, .release);

    const total_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - update_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    if (total_ms >= 2.0) {
        perf_log.logf(
            .info,
            "update_ms={d:.2} snapshot_ms={d:.2} ensure_view_cache_ms={d:.2} plan_ms={d:.2} resize_ms={d:.2} copy_rows_ms={d:.2} selection_ms={d:.2} damage_ms={d:.2} kitty_ms={d:.2} history={d} scroll_offset={d} visible_history_changed={any}",
            .{
                total_ms,
                snapshot_ms,
                ensure_view_cache_ms,
                plan_ms,
                resize_ms,
                copy_rows_ms,
                selection_ms,
                damage_ms,
                kitty_ms,
                history_len,
                clamped_offset,
                plan.visible_history_changed,
            },
        );
    }
}

pub fn updateViewCacheForScroll(self: anytype) void {
    if (self.state_mutex.tryLock()) {
        defer self.state_mutex.unlock();
        if (!self.view_cache_pending.swap(false, .acq_rel)) return;
        const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
        updateViewCacheNoLock(self, self.output_generation.load(.acquire), offset);
    }
}

pub fn updateViewCacheForScrollLocked(self: anytype) void {
    if (!self.view_cache_pending.swap(false, .acq_rel)) return;
    const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
    updateViewCacheNoLock(self, self.output_generation.load(.acquire), offset);
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
