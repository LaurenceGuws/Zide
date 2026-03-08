const std = @import("std");
const types = @import("../model/types.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const render_cache_mod = @import("render_cache.zig");
const app_logger = @import("../../app_logger.zig");
const screen_mod = @import("../model/screen.zig");

const RenderCache = render_cache_mod.RenderCache;
const Cell = types.Cell;
const FullDirtyReason = screen_mod.FullDirtyReason;

fn pickForcedFullDirtyReason(
    force_full_damage: bool,
    rows: usize,
    active_rows: usize,
    cols: usize,
    active_cols: usize,
    scroll_offset: usize,
    active_scroll_offset: usize,
    requires_full_damage_for_scrollback: bool,
    active_is_alt: bool,
    cache_alt_active: bool,
    screen_reverse: bool,
    cache_screen_reverse: bool,
    kitty_generation: u64,
    cache_kitty_generation: u64,
    view_dirty: anytype,
    view_reason: FullDirtyReason,
) FullDirtyReason {
    if (force_full_damage) return .view_cache_force_full_damage;
    if (rows != active_rows or cols != active_cols) return .view_cache_geometry_change;
    if (scroll_offset != active_scroll_offset) return .view_cache_scroll_offset_change;
    if (requires_full_damage_for_scrollback) return .view_cache_scrollback_generation_change;
    if (active_is_alt != cache_alt_active) return .view_cache_alt_state_change;
    if (screen_reverse != cache_screen_reverse) return .view_cache_screen_reverse_change;
    if (kitty_generation != cache_kitty_generation) return .view_cache_kitty_generation_change;
    if (view_dirty == .full) {
        return if (view_reason == .unknown) .view_cache_view_dirty_full else view_reason;
    }
    return .unknown;
}

fn rowLastContentCol(row_cells: []const Cell, cols: usize) ?usize {
    if (cols == 0 or row_cells.len < cols) return null;
    var last: ?usize = null;
    var col: usize = 0;
    while (col < cols) : (col += 1) {
        const cell = row_cells[col];
        if (cell.x != 0 or cell.y != 0) continue;
        if (cell.codepoint == 0 and cell.combining_len == 0) continue;
        const width_units = @as(usize, @max(@as(u8, 1), cell.width));
        const end_col = @min(cols - 1, col + width_units - 1);
        last = end_col;
    }
    return last;
}

pub fn updateViewCacheNoLock(self: anytype, generation: u64, scroll_offset: usize) void {
    const screen = self.activeScreenConst();
    const view = screen.snapshotView();
    const screen_reverse = screen.screen_reverse;
    const rows = view.rows;
    const cols = view.cols;
    const active_index = self.render_cache_index.load(.acquire);
    const target_index: u8 = if (active_index == 0) 1 else 0;
    var cache = &self.render_caches[target_index];
    if (self.active != .alt) {
        self.history.ensureViewCache(@intCast(cols), self.primary.defaultCell());
    }
    const history_len = if (self.active == .alt) 0 else self.history.scrollbackCount();
    const total_lines = history_len + rows;
    const max_offset = if (total_lines > rows) total_lines - rows else 0;
    const clamped_offset = if (scroll_offset > max_offset) max_offset else scroll_offset;
    const kitty_generation = kitty_mod.kittyStateConst(self).generation;
    const clear_generation = self.clear_generation.load(.acquire);
    const force_full_damage = self.force_full_damage.swap(false, .acq_rel);
    const selection_active = self.active != .alt and self.history.selectionState() != null;
    const active_cache = &self.render_caches[active_index];
    if (active_cache.rows == rows and
        active_cache.cols == cols and
        active_cache.history_len == history_len and
        active_cache.total_lines == total_lines and
        active_cache.scroll_offset == clamped_offset and
        active_cache.generation == generation and
        active_cache.clear_generation == clear_generation and
        active_cache.alt_active == (self.active == .alt) and
        active_cache.sync_updates_active == self.sync_updates_active and
        active_cache.screen_reverse == screen_reverse and
        active_cache.kitty_generation == kitty_generation and
        !force_full_damage and
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
        active_cache.scroll_offset == clamped_offset and
        active_cache.clear_generation == clear_generation and
        active_cache.alt_active == (self.active == .alt) and
        active_cache.sync_updates_active == self.sync_updates_active and
        active_cache.screen_reverse == screen_reverse and
        active_cache.kitty_generation == kitty_generation and
        !force_full_damage and
        view.dirty == .none and
        active_cache.dirty == .none and
        !selection_active and
        !active_cache.selection_active)
    {
        // Generation can advance without visible cell changes (e.g. parser-side churn).
        // Keep cache generation current without forcing a redraw.
        active_cache.generation = generation;
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
        cache.alt_active = self.active == .alt;
        cache.selection_active = selection_active;
        cache.sync_updates_active = self.sync_updates_active;
        cache.screen_reverse = screen_reverse;
        cache.clear_generation = clear_generation;
        cache.viewport_shift_rows = 0;
        updateKittyViewNoLock(self, cache);
        self.render_cache_index.store(target_index, .release);
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
    var viewport_shift_rows: i32 = 0;
    if (active_cache.rows == rows) {
        const prev_end_line = if (active_cache.total_lines > active_cache.scroll_offset)
            active_cache.total_lines - active_cache.scroll_offset
        else
            0;
        const prev_start_line = if (prev_end_line > rows) prev_end_line - rows else 0;
        viewport_shift_rows = @as(i32, @intCast(start_line)) - @as(i32, @intCast(prev_start_line));
    }
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        const global_row = start_line + row;
        const row_start = row * cols;
        const row_dest = cache.cells.items[row_start .. row_start + cols];
        if (global_row < history_len) {
            if (self.history.scrollbackRow(global_row)) |history_row| {
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

    if (self.active == .alt) {
        for (cache.selection_rows.items) |*row_selected| {
            row_selected.* = false;
        }
        cache.selection_active = selection_active;
    } else if (self.history.selectionState()) |selection| {
        cache.selection_active = selection_active;
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

        row = 0;
        while (row < rows) : (row += 1) {
            const global_row = start_line + row;
            const row_start = row * cols;
            const row_cells = cache.cells.items[row_start .. row_start + cols];
            const last_content_col = rowLastContentCol(row_cells, cols);
            if (global_row < start_sel.row or global_row > end_sel.row) {
                cache.selection_rows.items[row] = false;
                continue;
            }
            const col_start = if (global_row == start_sel.row) start_sel.col else 0;
            const col_end = if (global_row == end_sel.row) end_sel.col else cols - 1;
            if (last_content_col == null) {
                cache.selection_rows.items[row] = false;
                continue;
            }
            const clamped_end = @min(col_end, last_content_col.?);
            if (clamped_end < col_start) {
                cache.selection_rows.items[row] = false;
                continue;
            }
            cache.selection_rows.items[row] = true;
            cache.selection_cols_start.items[row] = @intCast(col_start);
            cache.selection_cols_end.items[row] = @intCast(clamped_end);
        }
    } else {
        for (cache.selection_rows.items) |*row_selected| {
            row_selected.* = false;
        }
        cache.selection_active = selection_active;
    }
    const scrollback_generation_changed = clear_generation != active_cache.clear_generation;
    // Full-region scrolls advance scrollback generation even when the user is
    // pinned to the live bottom view. In that case the visible viewport can
    // still use viewport_shift_rows + partial row damage; forcing full damage
    // here scales badly with large terminals and defeats the fast path.
    const requires_full_damage_for_scrollback = scrollback_generation_changed and
        (clamped_offset != 0 or active_cache.scroll_offset != 0);
    const needs_full_damage = force_full_damage or
        rows != active_cache.rows or
        cols != active_cache.cols or
        scroll_offset != active_cache.scroll_offset or
        requires_full_damage_for_scrollback or
        (self.active == .alt) != active_cache.alt_active or
        screen_reverse != active_cache.screen_reverse or
        kitty_generation != active_cache.kitty_generation or
        view.dirty == .full;
    if (needs_full_damage) {
        row = 0;
        while (row < rows) : (row += 1) {
            const row_start = row * cols;
            const row_cells = cache.cells.items[row_start .. row_start + cols];
            cache.row_hashes.items[row] = hashRow(row_cells);
        }
    }

    if (view.dirty_rows.len == rows and !needs_full_damage) {
        std.mem.copyForwards(bool, cache.dirty_rows.items, view.dirty_rows);
    } else {
        for (cache.dirty_rows.items) |*row_dirty| {
            row_dirty.* = true;
        }
    }
    if (view.dirty_cols_start.len == rows and view.dirty_cols_end.len == rows and !needs_full_damage) {
        std.mem.copyForwards(u16, cache.dirty_cols_start.items, view.dirty_cols_start);
        std.mem.copyForwards(u16, cache.dirty_cols_end.items, view.dirty_cols_end);
        if (view.dirty == .partial and cols > 0) {
            var row_idx: usize = 0;
            while (row_idx < rows) : (row_idx += 1) {
                if (!cache.dirty_rows.items[row_idx]) continue;
                cache.dirty_cols_start.items[row_idx] = 0;
                cache.dirty_cols_end.items[row_idx] = @intCast(cols - 1);
            }
        }
    } else {
        for (cache.dirty_cols_start.items, cache.dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = 0;
            col_end.* = if (cols > 0) @intCast(cols - 1) else 0;
        }
    }

    if (!needs_full_damage and active_cache.rows == rows and active_cache.cols == cols and active_cache.selection_rows.items.len == rows) {
        var row_idx: usize = 0;
        while (row_idx < rows) : (row_idx += 1) {
            const was_selected = active_cache.selection_rows.items[row_idx];
            const is_selected = cache.selection_rows.items[row_idx];
            var changed = was_selected != is_selected;
            if (!changed and is_selected and active_cache.selection_cols_start.items.len == rows and active_cache.selection_cols_end.items.len == rows) {
                changed = active_cache.selection_cols_start.items[row_idx] != cache.selection_cols_start.items[row_idx] or
                    active_cache.selection_cols_end.items[row_idx] != cache.selection_cols_end.items[row_idx];
            }
            if (!changed) continue;

            cache.dirty_rows.items[row_idx] = true;
            cache.dirty_cols_start.items[row_idx] = 0;
            cache.dirty_cols_end.items[row_idx] = if (cols > 0) @intCast(cols - 1) else 0;
            if (cache.dirty == .none) {
                cache.dirty = .partial;
                cache.damage = .{
                    .start_row = row_idx,
                    .end_row = row_idx,
                    .start_col = 0,
                    .end_col = if (cols > 0) cols - 1 else 0,
                };
            } else if (cache.dirty != .full) {
                cache.damage.start_row = @min(cache.damage.start_row, row_idx);
                cache.damage.end_row = @max(cache.damage.end_row, row_idx);
                cache.damage.start_col = 0;
                cache.damage.end_col = if (cols > 0) cols - 1 else 0;
            }
        }
    }

    cache.rows = rows;
    cache.cols = cols;
    cache.history_len = history_len;
    cache.total_lines = total_lines;
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
    cache.dirty = if (needs_full_damage) .full else view.dirty;
    cache.damage = if (needs_full_damage)
        .{ .start_row = 0, .end_row = if (rows > 0) rows - 1 else 0, .start_col = 0, .end_col = if (cols > 0) cols - 1 else 0 }
    else
        view.damage;
    if (needs_full_damage) {
        const forced_reason = pickForcedFullDirtyReason(
            force_full_damage,
            rows,
            active_cache.rows,
            cols,
            active_cache.cols,
            scroll_offset,
            active_cache.scroll_offset,
            requires_full_damage_for_scrollback,
            self.active == .alt,
            active_cache.alt_active,
            screen_reverse,
            active_cache.screen_reverse,
            kitty_generation,
            active_cache.kitty_generation,
            view.dirty,
            view.full_dirty_reason,
        );
        cache.full_dirty_reason = forced_reason;
        cache.full_dirty_seq = active_cache.full_dirty_seq +% 1;
    } else {
        cache.full_dirty_reason = view.full_dirty_reason;
        cache.full_dirty_seq = view.full_dirty_seq;
    }

    if (!needs_full_damage and cache.dirty == .full and active_cache.rows == rows and active_cache.cols == cols and active_cache.row_hashes.items.len == rows and rows > 0 and cols > 0) {
        const shift = viewport_shift_rows;
        var any_dirty = false;
        var damage_start_row: usize = rows - 1;
        var damage_end_row: usize = 0;
        var row_idx: usize = 0;
        while (row_idx < rows) : (row_idx += 1) {
            const row_start = row_idx * cols;
            const row_cells = cache.cells.items[row_start .. row_start + cols];
            const hash_now = hashRow(row_cells);
            cache.row_hashes.items[row_idx] = hash_now;

            const source_row_signed: i32 = @as(i32, @intCast(row_idx)) + shift;
            const source_row_valid = source_row_signed >= 0 and source_row_signed < @as(i32, @intCast(rows));
            const source_row: usize = if (source_row_valid) @intCast(source_row_signed) else 0;
            const hash_changed = if (!source_row_valid)
                true
            else
                hash_now != active_cache.row_hashes.items[source_row];

            cache.dirty_rows.items[row_idx] = hash_changed;
            if (hash_changed) {
                cache.dirty_cols_start.items[row_idx] = 0;
                cache.dirty_cols_end.items[row_idx] = @intCast(cols - 1);
                if (!any_dirty) {
                    damage_start_row = row_idx;
                    damage_end_row = row_idx;
                } else {
                    damage_start_row = @min(damage_start_row, row_idx);
                    damage_end_row = @max(damage_end_row, row_idx);
                }
                any_dirty = true;
            } else {
                cache.dirty_cols_start.items[row_idx] = @intCast(cols);
                cache.dirty_cols_end.items[row_idx] = 0;
            }
        }
        if (any_dirty) {
            cache.dirty = .partial;
            cache.damage = .{
                .start_row = damage_start_row,
                .end_row = damage_end_row,
                .start_col = 0,
                .end_col = cols - 1,
            };
        } else {
            cache.dirty = .none;
            cache.damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
        }
    }

    if (!needs_full_damage and view.dirty == .partial and active_cache.rows == rows and active_cache.cols == cols and active_cache.row_hashes.items.len == rows) {
        var any_dirty = false;
        var row_idx: usize = 0;
        while (row_idx < rows) : (row_idx += 1) {
            if (!cache.dirty_rows.items[row_idx]) continue;
            const row_start = row_idx * cols;
            const row_cells = cache.cells.items[row_start .. row_start + cols];
            const hash_now = hashRow(row_cells);
            cache.row_hashes.items[row_idx] = hash_now;
            const hash_changed = hash_now != active_cache.row_hashes.items[row_idx];
            cache.dirty_rows.items[row_idx] = hash_changed;
            if (hash_changed) {
                cache.dirty_cols_start.items[row_idx] = 0;
                cache.dirty_cols_end.items[row_idx] = if (cols > 0) @intCast(cols - 1) else 0;
                any_dirty = true;
            }
        }
        if (!any_dirty) {
            cache.dirty = .none;
        }
    }

    // Cursor is rendered as a UI overlay in terminal_widget_draw, so cursor visibility
    // changes should not dirty the cached terminal texture rows every frame.

    if (cache.dirty == .partial and cols > 0) {
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
        }
    }
    cache.alt_active = self.active == .alt;
    cache.selection_active = selection_active;
    cache.sync_updates_active = self.sync_updates_active;
    cache.screen_reverse = screen_reverse;
    cache.clear_generation = clear_generation;
    cache.viewport_shift_rows = viewport_shift_rows;
    updateKittyViewNoLock(self, cache);
    self.render_cache_index.store(target_index, .release);
}

pub fn updateViewCacheForScroll(self: anytype) void {
    if (self.state_mutex.tryLock()) {
        const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
        updateViewCacheNoLock(self, self.output_generation.load(.acquire), offset);
        self.state_mutex.unlock();
    }
}

pub fn updateViewCacheForScrollLocked(self: anytype) void {
    const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
    updateViewCacheNoLock(self, self.output_generation.load(.acquire), offset);
}

fn hashRow(cells: []const Cell) u64 {
    var h: u64 = 1469598103934665603;
    const prime: u64 = 1099511628211;
    for (cells) |cell| {
        h = (h ^ @as(u64, cell.codepoint)) *% prime;
        h = (h ^ @as(u64, cell.combining_len)) *% prime;
        if (cell.combining_len > 0) {
            var i: usize = 0;
            while (i < cell.combining_len and i < cell.combining.len) : (i += 1) {
                h = (h ^ @as(u64, cell.combining[i])) *% prime;
            }
        }
        h = (h ^ @as(u64, cell.width)) *% prime;
        const attrs = cell.attrs;
        h = (h ^ @as(u64, attrs.fg.r)) *% prime;
        h = (h ^ @as(u64, attrs.fg.g)) *% prime;
        h = (h ^ @as(u64, attrs.fg.b)) *% prime;
        h = (h ^ @as(u64, attrs.fg.a)) *% prime;
        h = (h ^ @as(u64, attrs.bg.r)) *% prime;
        h = (h ^ @as(u64, attrs.bg.g)) *% prime;
        h = (h ^ @as(u64, attrs.bg.b)) *% prime;
        h = (h ^ @as(u64, attrs.bg.a)) *% prime;
        h = (h ^ @as(u64, attrs.underline_color.r)) *% prime;
        h = (h ^ @as(u64, attrs.underline_color.g)) *% prime;
        h = (h ^ @as(u64, attrs.underline_color.b)) *% prime;
        h = (h ^ @as(u64, attrs.underline_color.a)) *% prime;
        h = (h ^ @as(u64, @intFromBool(attrs.bold))) *% prime;
        h = (h ^ @as(u64, @intFromBool(attrs.blink))) *% prime;
        h = (h ^ @as(u64, @intFromBool(attrs.blink_fast))) *% prime;
        h = (h ^ @as(u64, @intFromBool(attrs.reverse))) *% prime;
        h = (h ^ @as(u64, @intFromBool(attrs.underline))) *% prime;
        h = (h ^ @as(u64, attrs.link_id)) *% prime;
    }
    return h;
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
