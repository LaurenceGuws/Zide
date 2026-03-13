const std = @import("std");
const screen_mod = @import("../model/screen.zig");
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

const LeftEdgeCellSummary = struct {
    changed: bool,
    codepoint: u32,
    fg: types.Color,
    bg: types.Color,
    bold: bool,
    underline: bool,
};

const CellWindowSummary = struct {
    col: usize,
    changed: bool,
    codepoint: u32,
    fg: types.Color,
    bg: types.Color,
    reverse: bool,
    resolved_bg: types.Color,
};

const RowStyleDiffSummary = struct {
    changed_cells: usize,
    codepoint_changed_cells: usize,
    attr_only_cells: usize,
    fg_changed_cells: usize,
    bg_changed_cells: usize,
    flag_changed_cells: usize,
};

fn summarizeLeftEdgeCell(
    cache: *const RenderCache,
    active_cache: *const RenderCache,
    row: usize,
    col: usize,
    cols: usize,
) ?LeftEdgeCellSummary {
    if (col >= cols) return null;
    const row_start = row * cols;
    if (row_start + col >= cache.cells.items.len or row_start + col >= active_cache.cells.items.len) return null;
    const cell = cache.cells.items[row_start + col];
    const active_cell = active_cache.cells.items[row_start + col];
    return .{
        .changed = !publication.cellsEqual(cell, active_cell),
        .codepoint = cell.codepoint,
        .fg = cell.attrs.fg,
        .bg = cell.attrs.bg,
        .bold = cell.attrs.bold,
        .underline = cell.attrs.underline,
    };
}

fn summarizeCellWindow(
    cache: *const RenderCache,
    active_cache: *const RenderCache,
    row: usize,
    col: usize,
    cols: usize,
) ?CellWindowSummary {
    if (col >= cols) return null;
    const row_start = row * cols;
    if (row_start + col >= cache.cells.items.len or row_start + col >= active_cache.cells.items.len) return null;
    const cell = cache.cells.items[row_start + col];
    const active_cell = active_cache.cells.items[row_start + col];
    const screen_reverse_mode = cache.screen_reverse;
    const cell_reverse = cell.attrs.reverse != screen_reverse_mode;
    return .{
        .col = col,
        .changed = !publication.cellsEqual(cell, active_cell),
        .codepoint = cell.codepoint,
        .fg = cell.attrs.fg,
        .bg = cell.attrs.bg,
        .reverse = cell_reverse,
        .resolved_bg = if (cell_reverse) cell.attrs.fg else cell.attrs.bg,
    };
}

fn summarizeRowStyleDiff(
    cache: *const RenderCache,
    active_cache: *const RenderCache,
    row: usize,
    start_col: usize,
    end_col: usize,
    cols: usize,
) RowStyleDiffSummary {
    var out = RowStyleDiffSummary{
        .changed_cells = 0,
        .codepoint_changed_cells = 0,
        .attr_only_cells = 0,
        .fg_changed_cells = 0,
        .bg_changed_cells = 0,
        .flag_changed_cells = 0,
    };
    if (cols == 0 or start_col > end_col or start_col >= cols) return out;
    const clamped_end = @min(end_col, cols - 1);
    const row_start = row * cols;
    if (row_start + clamped_end >= cache.cells.items.len or row_start + clamped_end >= active_cache.cells.items.len) return out;

    var col = start_col;
    while (col <= clamped_end) : (col += 1) {
        const cell = cache.cells.items[row_start + col];
        const active_cell = active_cache.cells.items[row_start + col];
        const codepoint_changed = cell.codepoint != active_cell.codepoint or
            cell.combining_len != active_cell.combining_len or
            !std.mem.eql(u32, cell.combining[0..], active_cell.combining[0..]) or
            cell.width != active_cell.width or
            cell.height != active_cell.height or
            cell.x != active_cell.x or
            cell.y != active_cell.y;
        const fg_changed = !std.meta.eql(cell.attrs.fg, active_cell.attrs.fg);
        const bg_changed = !std.meta.eql(cell.attrs.bg, active_cell.attrs.bg);
        const flag_changed = cell.attrs.bold != active_cell.attrs.bold or
            cell.attrs.blink != active_cell.attrs.blink or
            cell.attrs.blink_fast != active_cell.attrs.blink_fast or
            cell.attrs.reverse != active_cell.attrs.reverse or
            cell.attrs.underline != active_cell.attrs.underline or
            !std.meta.eql(cell.attrs.underline_color, active_cell.attrs.underline_color) or
            cell.attrs.link_id != active_cell.attrs.link_id;
        if (!(codepoint_changed or fg_changed or bg_changed or flag_changed)) continue;
        out.changed_cells += 1;
        if (codepoint_changed) out.codepoint_changed_cells += 1;
        if (!codepoint_changed and (fg_changed or bg_changed or flag_changed)) out.attr_only_cells += 1;
        if (fg_changed) out.fg_changed_cells += 1;
        if (bg_changed) out.bg_changed_cells += 1;
        if (flag_changed) out.flag_changed_cells += 1;
    }
    return out;
}

fn logCursorMotionDamage(
    logger: app_logger.Logger,
    cache: *const RenderCache,
    active_cache: *const RenderCache,
    old_cursor: types.CursorPos,
    new_cursor: types.CursorPos,
    rows: usize,
    cols: usize,
) void {
    if ((!logger.enabled_file and !logger.enabled_console) or rows == 0 or cols == 0) return;

    const old_row = if (old_cursor.row < rows) old_cursor.row else rows - 1;
    const new_row = if (new_cursor.row < rows) new_cursor.row else rows - 1;

    const old_dirty = cache.dirty_rows.items[old_row];
    const new_dirty = cache.dirty_rows.items[new_row];

    const old_count = if (old_row < cache.row_dirty_span_counts.items.len) cache.row_dirty_span_counts.items[old_row] else 0;
    const new_count = if (new_row < cache.row_dirty_span_counts.items.len) cache.row_dirty_span_counts.items[new_row] else 0;

    const old_spans = if (old_row < cache.row_dirty_spans.items.len) cache.row_dirty_spans.items[old_row] else undefined;
    const new_spans = if (new_row < cache.row_dirty_spans.items.len) cache.row_dirty_spans.items[new_row] else undefined;
    const old_row_start = old_row * cols;
    const new_row_start = new_row * cols;
    const old_diff = if (old_row_start + cols <= cache.cells.items.len and old_row_start + cols <= active_cache.cells.items.len)
        publication.rowDiffSpans(
            cache.cells.items[old_row_start .. old_row_start + cols],
            active_cache.cells.items[old_row_start .. old_row_start + cols],
            cols,
        )
    else
        publication.RowDiffSpans{
            .count = 0,
            .overflow = false,
            .spans = [_]publication.RowDirtySpan{publication.invalidRowSpan(cols)} ** publication.max_row_dirty_spans,
        };
    const new_diff = if (new_row_start + cols <= cache.cells.items.len and new_row_start + cols <= active_cache.cells.items.len)
        publication.rowDiffSpans(
            cache.cells.items[new_row_start .. new_row_start + cols],
            active_cache.cells.items[new_row_start .. new_row_start + cols],
            cols,
        )
    else
        publication.RowDiffSpans{
            .count = 0,
            .overflow = false,
            .spans = [_]publication.RowDirtySpan{publication.invalidRowSpan(cols)} ** publication.max_row_dirty_spans,
        };

    const damage_rows = if (cache.damage.end_row >= cache.damage.start_row) cache.damage.end_row - cache.damage.start_row + 1 else 0;
    const damage_cols = if (cache.damage.end_col >= cache.damage.start_col) cache.damage.end_col - cache.damage.start_col + 1 else 0;

    logger.logf(
        .info,
        "move old={d}:{d} new={d}:{d} damage_rows={d} damage_cols={d} shift_rows={d} shift_exposed_only={d} rows={d} cols={d}",
        .{
            old_cursor.row,
            old_cursor.col,
            new_cursor.row,
            new_cursor.col,
            damage_rows,
            damage_cols,
            cache.viewport_shift_rows,
            @intFromBool(cache.viewport_shift_exposed_only),
            rows,
            cols,
        },
    );
    logger.logf(
        .info,
        "old_row={d} dirty={d} union={d}..{d} spans={d} [{d}..{d},{d}..{d},{d}..{d},{d}..{d}] diff={d}/{d} [{d}..{d},{d}..{d},{d}..{d},{d}..{d}]",
        .{
            old_row,
            @intFromBool(old_dirty),
            cache.dirty_cols_start.items[old_row],
            cache.dirty_cols_end.items[old_row],
            old_count,
            old_spans[0].start,
            old_spans[0].end,
            old_spans[1].start,
            old_spans[1].end,
            old_spans[2].start,
            old_spans[2].end,
            old_spans[3].start,
            old_spans[3].end,
            old_diff.count,
            @intFromBool(old_diff.overflow),
            old_diff.spans[0].start,
            old_diff.spans[0].end,
            old_diff.spans[1].start,
            old_diff.spans[1].end,
            old_diff.spans[2].start,
            old_diff.spans[2].end,
            old_diff.spans[3].start,
            old_diff.spans[3].end,
        },
    );
    logger.logf(
        .info,
        "new_row={d} dirty={d} union={d}..{d} spans={d} [{d}..{d},{d}..{d},{d}..{d},{d}..{d}] diff={d}/{d} [{d}..{d},{d}..{d},{d}..{d},{d}..{d}]",
        .{
            new_row,
            @intFromBool(new_dirty),
            cache.dirty_cols_start.items[new_row],
            cache.dirty_cols_end.items[new_row],
            new_count,
            new_spans[0].start,
            new_spans[0].end,
            new_spans[1].start,
            new_spans[1].end,
            new_spans[2].start,
            new_spans[2].end,
            new_spans[3].start,
            new_spans[3].end,
            new_diff.count,
            @intFromBool(new_diff.overflow),
            new_diff.spans[0].start,
            new_diff.spans[0].end,
            new_diff.spans[1].start,
            new_diff.spans[1].end,
            new_diff.spans[2].start,
            new_diff.spans[2].end,
            new_diff.spans[3].start,
            new_diff.spans[3].end,
        },
    );

    if ((cache.dirty_cols_start.items[old_row] == 2 or cache.dirty_cols_start.items[new_row] == 2) and cols >= 2) {
        const old_left0 = summarizeLeftEdgeCell(cache, active_cache, old_row, 0, cols);
        const old_left1 = summarizeLeftEdgeCell(cache, active_cache, old_row, 1, cols);
        const new_left0 = summarizeLeftEdgeCell(cache, active_cache, new_row, 0, cols);
        const new_left1 = summarizeLeftEdgeCell(cache, active_cache, new_row, 1, cols);
        logger.logf(
            .info,
            "left_edge row={d} col=0 present={d} changed={d} cp={d} fg={d}:{d}:{d} bg={d}:{d}:{d}",
            .{
                old_row,
                @intFromBool(old_left0 != null),
                @intFromBool(old_left0 != null and old_left0.?.changed),
                if (old_left0) |s| s.codepoint else 0,
                if (old_left0) |s| s.fg.r else 0,
                if (old_left0) |s| s.fg.g else 0,
                if (old_left0) |s| s.fg.b else 0,
                if (old_left0) |s| s.bg.r else 0,
                if (old_left0) |s| s.bg.g else 0,
                if (old_left0) |s| s.bg.b else 0,
            },
        );
        logger.logf(
            .info,
            "left_edge row={d} col=1 present={d} changed={d} cp={d} fg={d}:{d}:{d} bg={d}:{d}:{d}",
            .{
                old_row,
                @intFromBool(old_left1 != null),
                @intFromBool(old_left1 != null and old_left1.?.changed),
                if (old_left1) |s| s.codepoint else 0,
                if (old_left1) |s| s.fg.r else 0,
                if (old_left1) |s| s.fg.g else 0,
                if (old_left1) |s| s.fg.b else 0,
                if (old_left1) |s| s.bg.r else 0,
                if (old_left1) |s| s.bg.g else 0,
                if (old_left1) |s| s.bg.b else 0,
            },
        );
        logger.logf(
            .info,
            "left_edge row={d} col=0 present={d} changed={d} cp={d} fg={d}:{d}:{d} bg={d}:{d}:{d}",
            .{
                new_row,
                @intFromBool(new_left0 != null),
                @intFromBool(new_left0 != null and new_left0.?.changed),
                if (new_left0) |s| s.codepoint else 0,
                if (new_left0) |s| s.fg.r else 0,
                if (new_left0) |s| s.fg.g else 0,
                if (new_left0) |s| s.fg.b else 0,
                if (new_left0) |s| s.bg.r else 0,
                if (new_left0) |s| s.bg.g else 0,
                if (new_left0) |s| s.bg.b else 0,
            },
        );
        logger.logf(
            .info,
            "left_edge row={d} col=1 present={d} changed={d} cp={d} fg={d}:{d}:{d} bg={d}:{d}:{d}",
            .{
                new_row,
                @intFromBool(new_left1 != null),
                @intFromBool(new_left1 != null and new_left1.?.changed),
                if (new_left1) |s| s.codepoint else 0,
                if (new_left1) |s| s.fg.r else 0,
                if (new_left1) |s| s.fg.g else 0,
                if (new_left1) |s| s.fg.b else 0,
                if (new_left1) |s| s.bg.r else 0,
                if (new_left1) |s| s.bg.g else 0,
                if (new_left1) |s| s.bg.b else 0,
            },
        );
    }

    const old_style = summarizeRowStyleDiff(
        cache,
        active_cache,
        old_row,
        cache.dirty_cols_start.items[old_row],
        cache.dirty_cols_end.items[old_row],
        cols,
    );
    const new_style = summarizeRowStyleDiff(
        cache,
        active_cache,
        new_row,
        cache.dirty_cols_start.items[new_row],
        cache.dirty_cols_end.items[new_row],
        cols,
    );
    logger.logf(
        .info,
        "style_diff old_row={d} changed={d} codepoint={d} attr_only={d} fg={d} bg={d} flags={d}",
        .{
            old_row,
            old_style.changed_cells,
            old_style.codepoint_changed_cells,
            old_style.attr_only_cells,
            old_style.fg_changed_cells,
            old_style.bg_changed_cells,
            old_style.flag_changed_cells,
        },
    );
    logger.logf(
        .info,
        "style_diff new_row={d} changed={d} codepoint={d} attr_only={d} fg={d} bg={d} flags={d}",
        .{
            new_row,
            new_style.changed_cells,
            new_style.codepoint_changed_cells,
            new_style.attr_only_cells,
            new_style.fg_changed_cells,
            new_style.bg_changed_cells,
            new_style.flag_changed_cells,
        },
    );

    const old_union_start = @as(usize, cache.dirty_cols_start.items[old_row]);
    const new_union_start = @as(usize, cache.dirty_cols_start.items[new_row]);
    if ((old_style.bg_changed_cells > 0 or new_style.bg_changed_cells > 0) and cols > 0) {
        const old_probe_cols = [_]usize{
            old_union_start,
            @min(old_union_start + 1, cols - 1),
            @min(old_union_start + 2, cols - 1),
        };
        const new_probe_cols = [_]usize{
            new_union_start,
            @min(new_union_start + 1, cols - 1),
            @min(new_union_start + 2, cols - 1),
        };
        inline for (old_probe_cols) |probe_col| {
            if (summarizeCellWindow(cache, active_cache, old_row, probe_col, cols)) |summary| {
                logger.logf(
                    .info,
                    "style_window row={d} col={d} changed={d} cp={d} fg={d}:{d}:{d} bg={d}:{d}:{d} rev={d} resolved_bg={d}:{d}:{d}",
                    .{
                        old_row,
                        summary.col,
                        @intFromBool(summary.changed),
                        summary.codepoint,
                        summary.fg.r,
                        summary.fg.g,
                        summary.fg.b,
                        summary.bg.r,
                        summary.bg.g,
                        summary.bg.b,
                        @intFromBool(summary.reverse),
                        summary.resolved_bg.r,
                        summary.resolved_bg.g,
                        summary.resolved_bg.b,
                    },
                );
            }
        }
        inline for (new_probe_cols) |probe_col| {
            if (summarizeCellWindow(cache, active_cache, new_row, probe_col, cols)) |summary| {
                logger.logf(
                    .info,
                    "style_window row={d} col={d} changed={d} cp={d} fg={d}:{d}:{d} bg={d}:{d}:{d} rev={d} resolved_bg={d}:{d}:{d}",
                    .{
                        new_row,
                        summary.col,
                        @intFromBool(summary.changed),
                        summary.codepoint,
                        summary.fg.r,
                        summary.fg.g,
                        summary.fg.b,
                        summary.bg.r,
                        summary.bg.g,
                        summary.bg.b,
                        @intFromBool(summary.reverse),
                        summary.resolved_bg.r,
                        summary.resolved_bg.g,
                        summary.resolved_bg.b,
                    },
                );
            }
        }
    }
}

pub fn updateViewCacheNoLock(self: anytype, generation: u64, scroll_offset: usize) void {
    const fullwidth_origin_log = app_logger.logger("terminal.ui.row_fullwidth_origin");
    const cursor_motion_log = app_logger.logger("terminal.ui.cursor_motion_damage");
    const screen = self.core.activeScreenConst();
    const view = screen.snapshotView();
    const screen_reverse = screen.screen_reverse;
    const rows = view.rows;
    const cols = view.cols;
    const active_index = self.render_cache_index.load(.acquire);
    const target_index: u8 = if (active_index == 0) 1 else 0;
    var cache = &self.render_caches[target_index];
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
    selection_projection.projectSelection(self, cache, total_lines, start_line, rows, cols, selection_active);
    if (plan.needs_full_damage) {
        row = 0;
        while (row < rows) : (row += 1) {
            const row_start = row * cols;
            const row_cells = cache.cells.items[row_start .. row_start + cols];
            cache.row_hashes.items[row] = publication.hashRow(row_cells);
        }
    }
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
    if (view.row_dirty_span_counts.len == rows and view.row_dirty_span_overflow.len == rows and view.row_dirty_spans.len == rows and !plan.needs_full_damage and !plan.visible_history_changed) {
        std.mem.copyForwards(u8, cache.row_dirty_span_counts.items, view.row_dirty_span_counts);
        std.mem.copyForwards(bool, cache.row_dirty_span_overflow.items, view.row_dirty_span_overflow);
        std.mem.copyForwards([screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan, cache.row_dirty_spans.items, view.row_dirty_spans);
    } else {
        var row_idx: usize = 0;
        while (row_idx < rows) : (row_idx += 1) {
            if (cache.dirty_rows.items[row_idx]) {
                cache.row_dirty_span_counts.items[row_idx] = 1;
                cache.row_dirty_span_overflow.items[row_idx] = false;
                cache.row_dirty_spans.items[row_idx][0] = .{
                    .start = if (cols > 0) 0 else 0,
                    .end = if (cols > 0) @intCast(cols - 1) else 0,
                };
            } else {
                cache.row_dirty_span_counts.items[row_idx] = 0;
                cache.row_dirty_span_overflow.items[row_idx] = false;
                cache.row_dirty_spans.items[row_idx][0] = .{ .start = @intCast(cols), .end = 0 };
            }
            var span_idx: usize = 1;
            while (span_idx < screen_mod.max_row_dirty_spans) : (span_idx += 1) {
                cache.row_dirty_spans.items[row_idx][span_idx] = .{ .start = @intCast(cols), .end = 0 };
            }
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
            var broad_logged: usize = 0;
            var row_idx: usize = 0;
            while (row_idx < rows and (logged < 5 or broad_logged < 5)) : (row_idx += 1) {
                if (!cache.dirty_rows.items[row_idx]) continue;
                const start_col = @as(usize, cache.dirty_cols_start.items[row_idx]);
                const end_col = @as(usize, cache.dirty_cols_end.items[row_idx]);
                if (start_col == 0 and end_col == cols - 1 and logged < 5) {
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
                const span_width = end_col - start_col + 1;
                if (broad_logged < 5 and span_width >= cols / 2 and !(start_col == 0 and end_col == cols - 1)) {
                    fullwidth_origin_log.logf(
                        .info,
                        "source=view row={d} reason=copied_broad_from_view cols={d}..{d} width={d} dirty={s} damage_rows={d} damage_cols={d} rows={d} cols={d}",
                        .{
                            row_idx,
                            start_col,
                            end_col,
                            span_width,
                            @tagName(view.dirty),
                            if (view.damage.end_row >= view.damage.start_row) view.damage.end_row - view.damage.start_row + 1 else 0,
                            if (view.damage.end_col >= view.damage.start_col) view.damage.end_col - view.damage.start_col + 1 else 0,
                            rows,
                            cols,
                        },
                    );
                    broad_logged += 1;
                }
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
        if (cols > 0 and cache.dirty == .partial) {
            var broad_refined_logged: usize = 0;
            var row_idx: usize = 0;
            while (row_idx < rows and broad_refined_logged < 5) : (row_idx += 1) {
                if (!cache.dirty_rows.items[row_idx]) continue;
                const start_col = @as(usize, cache.dirty_cols_start.items[row_idx]);
                const end_col = @as(usize, cache.dirty_cols_end.items[row_idx]);
                if (end_col < start_col) continue;
                const span_width = end_col - start_col + 1;
                if (span_width < cols / 2 or (start_col == 0 and end_col == cols - 1)) continue;
                fullwidth_origin_log.logf(
                    .info,
                    "source=view_cache row={d} reason=refined_broad_span cols={d}..{d} width={d} dirty={s} damage_rows={d} damage_cols={d} rows={d} cols={d}",
                    .{
                        row_idx,
                        start_col,
                        end_col,
                        span_width,
                        @tagName(cache.dirty),
                        if (cache.damage.end_row >= cache.damage.start_row) cache.damage.end_row - cache.damage.start_row + 1 else 0,
                        if (cache.damage.end_col >= cache.damage.start_col) cache.damage.end_col - cache.damage.start_col + 1 else 0,
                        rows,
                        cols,
                    },
                );
                broad_refined_logged += 1;
            }
        }
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
    if ((view.cursor.row != active_cache.cursor.row or view.cursor.col != active_cache.cursor.col) and
        cache.dirty == .partial and
        !plan.needs_full_damage)
    {
        logCursorMotionDamage(cursor_motion_log, cache, active_cache, active_cache.cursor, view.cursor, rows, cols);
    }
    updateKittyViewNoLock(self, cache);
    self.render_cache_index.store(target_index, .release);
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
