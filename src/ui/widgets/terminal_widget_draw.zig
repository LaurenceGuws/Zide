const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const render_cache_mod = @import("../../terminal/core/render_cache.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const common = @import("common.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const draw_grid = @import("terminal_widget_draw_grid.zig");

const hover_mod = @import("terminal_widget_hover.zig");
const kitty_mod = @import("terminal_widget_kitty.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;

const RenderCache = render_cache_mod.RenderCache;
const PresentationCapture = terminal_mod.PresentationCapture;
const PresentedRenderCache = terminal_mod.PresentedRenderCache;
const PresentationFeedback = terminal_mod.PresentationFeedback;
var jitter_debug_enabled_cache: ?bool = null;
var frame_latency_seq: u64 = 0;
var frame_latency_metrics: FrameLatencyMetrics = .{};

pub const FrameLatencyMetrics = struct {
    seq: u64 = 0,
    generation: u64 = 0,
    lock_ms: f64 = 0.0,
    cache_copy_ms: f64 = 0.0,
    texture_update_ms: f64 = 0.0,
    overlay_ms: f64 = 0.0,
    render_ms: f64 = 0.0,
    draw_ms: f64 = 0.0,
};

pub const DrawOutcome = PresentationFeedback;
const drawRowBackgrounds = draw_grid.drawRowBackgrounds;
const drawRowGlyphs = draw_grid.drawRowGlyphs;

pub const DrawPreparation = struct {
    draw_start: f64,
    lock_ms: f64,
    presented: PresentedRenderCache,

    pub fn fromCapture(draw_start: f64, capture: PresentationCapture) DrawPreparation {
        return .{
            .draw_start = draw_start,
            .lock_ms = capture.lock_ms,
            .presented = capture.presented,
        };
    }
};

const ViewportTextureShiftPlan = union(enum) {
    none,
    attempt: usize,
};

const TextureUpdatePlan = struct {
    needs_full: bool,
    needs_partial: bool,
};

pub fn latestFrameLatencyMetrics() FrameLatencyMetrics {
    return frame_latency_metrics;
}

fn publishFrameLatencyMetrics(
    generation: u64,
    lock_ms: f64,
    cache_copy_ms: f64,
    texture_update_ms: f64,
    overlay_ms: f64,
    render_ms: f64,
    draw_ms: f64,
) void {
    frame_latency_seq +%= 1;
    frame_latency_metrics = .{
        .seq = frame_latency_seq,
        .generation = generation,
        .lock_ms = lock_ms,
        .cache_copy_ms = cache_copy_ms,
        .texture_update_ms = texture_update_ms,
        .overlay_ms = overlay_ms,
        .render_ms = render_ms,
        .draw_ms = draw_ms,
    };
}

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

fn softSelectionColor(base: Color) Color {
    return .{
        .r = base.r,
        .g = base.g,
        .b = base.b,
        .a = @min(@as(u8, 156), base.a),
    };
}

const SelectionCornerMask = struct {
    top_left_outward: bool = false,
    top_right_outward: bool = false,
    bottom_left_outward: bool = false,
    bottom_right_outward: bool = false,
    top_left_inward: bool = false,
    top_right_inward: bool = false,
    bottom_left_inward: bool = false,
    bottom_right_inward: bool = false,
};

fn drawSoftSelectionRect(r: anytype, x: i32, y: i32, w: i32, h: i32, color: Color, mask: SelectionCornerMask) void {
    if (w <= 0 or h <= 0) return;
    const style = r.terminalSelectionOverlayStyle();
    if (!style.smooth_enabled) {
        r.drawRect(x, y, w, h, color);
        return;
    }
    const corner_px = style.corner_px orelse @max(1.0, std.math.floor(r.uiScaleFactor() * 0.75));
    const inset_x = @max(1, @as(i32, @intFromFloat(std.math.round(corner_px))));
    const pad_px = style.pad_px orelse @max(1.0, std.math.round(r.uiScaleFactor() * 0.5));
    const pad_x = @max(0, @as(i32, @intFromFloat(std.math.round(pad_px))));
    const draw_x = x + inset_x - pad_x;
    const draw_y = y;
    const draw_w = @max(1, w - inset_x * 2 + pad_x * 2);
    const draw_h = h;
    const corner = @max(1, @min(inset_x, @divFloor(draw_h, 4)));
    const cornerDelta = struct {
        fn resolve(outward: bool, inward: bool, amount: i32) i32 {
            if (outward) return amount;
            if (inward) return -amount;
            return 0;
        }
    }.resolve;
    const top_left_inset = cornerDelta(mask.top_left_outward, mask.top_left_inward, corner);
    const top_right_inset = cornerDelta(mask.top_right_outward, mask.top_right_inward, corner);
    const bottom_left_inset = cornerDelta(mask.bottom_left_outward, mask.bottom_left_inward, corner);
    const bottom_right_inset = cornerDelta(mask.bottom_right_outward, mask.bottom_right_inward, corner);
    const top_left_edge = top_left_inset;
    const top_right_edge = top_right_inset;
    const bottom_left_edge = bottom_left_inset;
    const bottom_right_edge = bottom_right_inset;

    const drawTopRow = struct {
        fn draw(r_local: anytype, x_local: i32, y_local: i32, w_local: i32, color_local: Color, left_inset: i32, right_inset: i32) void {
            const line_x = x_local + left_inset;
            const line_w = w_local - left_inset - right_inset;
            if (line_w > 0) {
                r_local.drawRect(line_x, y_local, line_w, 1, color_local);
            }
        }
    }.draw;

    switch (draw_h) {
        1 => {
            drawTopRow(
                r,
                draw_x,
                draw_y,
                draw_w,
                color,
                if (top_left_edge != 0) top_left_edge else bottom_left_edge,
                if (top_right_edge != 0) top_right_edge else bottom_right_edge,
            );
            return;
        },
        2 => {
            drawTopRow(r, draw_x, draw_y, draw_w, color, top_left_edge, top_right_edge);
            drawTopRow(r, draw_x, draw_y + 1, draw_w, color, bottom_left_edge, bottom_right_edge);
            return;
        },
        else => {},
    }

    if (top_left_edge == 0 and top_right_edge == 0 and bottom_left_edge == 0 and bottom_right_edge == 0) {
        r.drawRect(draw_x, draw_y, draw_w, draw_h, color);
        return;
    }

    drawTopRow(r, draw_x, draw_y, draw_w, color, top_left_edge, top_right_edge);
    r.drawRect(draw_x, draw_y + 1, draw_w, draw_h - 2, color);
    drawTopRow(r, draw_x, draw_y + draw_h - 1, draw_w, color, bottom_left_edge, bottom_right_edge);
}

fn rowSelectionCoversColumn(cache: *const RenderCache, selection_rows: []const bool, row_idx: usize, col: usize) bool {
    if (row_idx >= selection_rows.len or !selection_rows[row_idx]) return false;
    const start = @as(usize, cache.selection_cols_start.items[row_idx]);
    const end = @as(usize, cache.selection_cols_end.items[row_idx]);
    return col >= start and col <= end;
}

fn rowSelectionNearColumn(cache: *const RenderCache, selection_rows: []const bool, row_idx: usize, col: usize, tolerance: usize) bool {
    if (row_idx >= selection_rows.len or !selection_rows[row_idx]) return false;
    const start = @as(usize, cache.selection_cols_start.items[row_idx]);
    const end = @as(usize, cache.selection_cols_end.items[row_idx]);
    const low = col -| tolerance;
    const high = col + tolerance;
    return !(end < low or start > high);
}

fn rowSelectionStart(cache: *const RenderCache, row_idx: usize) usize {
    return @as(usize, cache.selection_cols_start.items[row_idx]);
}

fn rowSelectionEnd(cache: *const RenderCache, row_idx: usize) usize {
    return @as(usize, cache.selection_cols_end.items[row_idx]);
}

fn planViewportTextureShift(
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

fn chooseTextureUpdatePlan(
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

fn markPartialPlanRows(
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
        if (partial_cols_start[affect_row] > col_start_u16) {
            partial_cols_start[affect_row] = col_start_u16;
        }
        if (partial_cols_end[affect_row] < col_end_u16) {
            partial_cols_end[affect_row] = col_end_u16;
        }
    }
}

fn markAllRowsFullWidthPartialPlan(
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

fn addBlinkRowsToPartialPlan(
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

fn spansOverlap(start_a: usize, end_a: usize, start_b: usize, end_b: usize) bool {
    return start_a <= end_b and start_b <= end_a;
}

fn rowSlice(cells: []const Cell, cols_count: usize, row: usize) []const Cell {
    const row_start = row * cols_count;
    if (row_start + cols_count > cells.len) return cells[0..0];
    return cells[row_start .. row_start + cols_count];
}

pub fn drawPrepared(
    self: anytype,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    input: shared_types.input.InputSnapshot,
    preparation: DrawPreparation,
) DrawOutcome {
    const draw_start = preparation.draw_start;
    const lock_ms: f64 = preparation.lock_ms;
    const cache_copy_ms: f64 = preparation.lock_ms;
    var texture_update_ms: f64 = 0.0;
    var overlay_ms: f64 = 0.0;
    var render_phase_start = draw_start;
    var outcome = DrawOutcome{ .presented = preparation.presented };
    defer {
        const draw_end = app_shell.getTime();
        const draw_ms_total = time_utils.secondsToMs(draw_end - draw_start);
        const render_ms = time_utils.secondsToMs(draw_end - render_phase_start);
        publishFrameLatencyMetrics(
            self.draw_cache.generation,
            lock_ms,
            cache_copy_ms,
            texture_update_ms,
            overlay_ms,
            render_ms,
            draw_ms_total,
        );
    }

    const r = shell.rendererPtr();
    const cache = &self.draw_cache;
    var alt_exit = false;
    var alt_state_changed = false;
    alt_state_changed = self.last_alt_active != cache.alt_active;
    alt_exit = self.last_alt_active and !cache.alt_active;
    self.last_alt_active = cache.alt_active;
    render_phase_start = app_shell.getTime();

    const sync_updates = cache.sync_updates_active;
    const screen_reverse = cache.screen_reverse;
    const blink_style = self.blink_style;
    const blink_time = app_shell.getTime();
    if (sync_updates and cache.cells.items.len > 0) {
        const view_cells = cache.cells.items;
        const bg_color = if (view_cells.len > 0) blk: {
            const cell = view_cells[0];
            const reversed = cell.attrs.reverse != screen_reverse;
            const bg = if (reversed) cell.attrs.fg else cell.attrs.bg;
            break :blk Color{
                .r = bg.r,
                .g = bg.g,
                .b = bg.b,
            };
        } else r.theme.background;
        r.drawRect(
            @intFromFloat(x),
            @intFromFloat(y),
            @intFromFloat(width),
            @intFromFloat(height),
            bg_color,
        );
        r.drawTerminalTexture(x, y);
        return outcome;
    }
    const draw_start_time = if (alt_exit) app_shell.getTime() else 0;
    const rows = cache.rows;
    const cols = cache.cols;
    const history_len = cache.history_len;
    const total_lines = cache.total_lines;
    const scroll_offset = cache.scroll_offset;
    const viewport_shift_rows = cache.viewport_shift_rows;
    const max_scroll_offset = if (total_lines > rows) total_lines - rows else 0;
    const end_line = total_lines - scroll_offset;
    const start_line = if (end_line > rows) end_line - rows else 0;
    var draw_cursor = scroll_offset == 0 and cache.cursor_visible;
    const cursor = if (draw_cursor) cache.cursor else CursorPos{ .row = rows + 1, .col = cols + 1 };
    const cursor_style = cache.cursor_style;
    if (draw_cursor and self.ui_focused and cursor_style.blink) {
        if (blink_time >= self.cursor_blink_pause_until) {
            const period: f64 = 0.5;
            const phase = @mod(blink_time, period * 2.0);
            draw_cursor = phase < period;
        }
    }
    const selection_active = cache.selection_active;
    const kitty_generation = cache.kitty_generation;
    const has_blink = blink_style != .off and cache.has_blink;
    const blink_phase_changed = self.blink_phase_changed_pending;
    self.blink_phase_changed_pending = false;
    const blink_requires_partial = has_blink and blink_phase_changed;

    self.kitty.updateViews(self.session.allocator, rows, cols, cache.kitty_images.items, cache.kitty_placements.items);

    var upload_stats: kitty_mod.KittyState.UploadStats = .{};
    if (self.kitty.images_view.items.len > 0) {
        self.kitty.primeUploads(self.session.allocator);
        upload_stats = self.kitty.processPendingUploads(shell);
    }

    const view_cells = cache.cells.items;
    const view_dirty_rows = cache.dirty_rows.items;
    var dirty_rows_count: usize = 0;
    var damage_row_span: usize = 0;
    var damage_col_span: usize = 0;
    if (cache.dirty != .none) {
        for (view_dirty_rows) |row_dirty| {
            if (row_dirty) dirty_rows_count += 1;
        }
        if (cache.damage.end_row >= cache.damage.start_row) {
            damage_row_span = cache.damage.end_row - cache.damage.start_row + 1;
        }
        if (cache.damage.end_col >= cache.damage.start_col) {
            damage_col_span = cache.damage.end_col - cache.damage.start_col + 1;
        }
    }
    const has_kitty = self.kitty.hasKitty();
    const bg_color = if (view_cells.len > 0) Color{
        .r = view_cells[0].attrs.bg.r,
        .g = view_cells[0].attrs.bg.g,
        .b = view_cells[0].attrs.bg.b,
    } else r.theme.background;
    r.drawRect(
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(width),
        @intFromFloat(height),
        bg_color,
    );

    // No clipping - let icons overflow freely
    // (sidebar draws last to cover any left overflow, right overflow goes into empty space)

    const base_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(x)))));
    const base_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(y)))));

    const scale = shell.uiScaleFactor();
    const scrollbar_base_w: f32 = common.scrollbarWidth(scale);
    const scrollbar_hover_w: f32 = common.scrollbarHoverWidth(scale);
    const scrollbar_hit_margin: f32 = common.scrollbarHitMargin(scale);
    const scrollbar_proximity: f32 = common.scrollbarProximityRange(scale);
    const mouse = input.mouse_pos;
    const in_scroll_y = mouse.y >= y and mouse.y <= y + height;
    const dist_from_right = (x + width) - mouse.x;
    const proximity_raw: f32 = if (in_scroll_y and dist_from_right <= scrollbar_proximity and dist_from_right >= -scrollbar_hit_margin)
        (1.0 - std.math.clamp(dist_from_right / scrollbar_proximity, 0.0, 1.0))
    else
        0.0;
    const show_scrollbar = !cache.alt_active and !cache.mouse_reporting_active and total_lines > rows;
    const proximity_t = common.smoothstep01(proximity_raw);
    const hover_target: f32 = if (show_scrollbar)
        (if (self.scrollbar_drag_active) 1.0 else proximity_t)
    else
        0.0;
    const anim_dt: f32 = blk: {
        if (self.scrollbar_anim_last_time <= 0) {
            self.scrollbar_anim_last_time = blink_time;
            break :blk 0;
        }
        const dt = std.math.clamp(blink_time - self.scrollbar_anim_last_time, 0.0, 0.1);
        self.scrollbar_anim_last_time = blink_time;
        break :blk @floatCast(dt);
    };
    self.scrollbar_hover_anim = common.expApproach(self.scrollbar_hover_anim, hover_target, anim_dt, 18.0);
    const scrollbar_w: f32 = common.lerp(scrollbar_base_w, scrollbar_hover_w, self.scrollbar_hover_anim);
    const scrollbar_x = x + width - scrollbar_w;
    const scrollbar_y = y;
    const scrollbar_h = height;
    self.hover.dirty = false;
    const hover_link_id = hover_mod.hoverLinkId(&self.hover);

    var updated = false;
    var texture_full_update = false;
    var texture_partial_update = false;
    var full_reason_recreated = false;
    var full_reason_cell_metrics = false;
    var full_reason_scale = false;
    var full_reason_dirty_full = false;
    const texture_phase_start = app_shell.getTime();
    if (rows > 0 and cols > 0) {
        const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
        const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
        const cell_metrics_changed = cell_w_i != self.last_cell_w_i or cell_h_i != self.last_cell_h_i;
        const render_scale_changed = r.render_scale != self.last_render_scale;
        const padding_x_i: i32 = @max(2, @divTrunc(cell_w_i, 2));
        const texture_w = cell_w_i * @as(i32, @intCast(cols)) + padding_x_i;
        const texture_h = cell_h_i * @as(i32, @intCast(rows));
        const recreated = r.ensureTerminalTexture(texture_w, texture_h);
        const gen_changed = cache.generation != self.last_render_generation;
        full_reason_recreated = recreated;
        full_reason_cell_metrics = cell_metrics_changed;
        full_reason_scale = render_scale_changed;
        full_reason_dirty_full = cache.dirty == .full;
        const update_plan = chooseTextureUpdatePlan(
            cache.dirty,
            full_reason_recreated,
            full_reason_cell_metrics,
            full_reason_scale,
            blink_requires_partial,
            self.terminal_texture_ready,
        );
        const needs_full = update_plan.needs_full;
        var needs_partial = update_plan.needs_partial;
        var shifted_rows: usize = 0;
        var shift_requires_fullwidth_partial = false;
        switch (planViewportTextureShift(
            r.terminalTextureShiftEnabled(),
            gen_changed,
            viewport_shift_rows,
            cache.viewport_shift_exposed_only,
            scroll_offset,
            needs_full,
            self.terminal_texture_ready,
            rows,
        )) {
            .attempt => |shift_rows| {
                const dy_pixels: i32 = -viewport_shift_rows * cell_h_i;
                if (r.scrollTerminalTexture(0, dy_pixels)) {
                    needs_partial = true;
                    shifted_rows = shift_rows;
                } else {
                    shifted_rows = 0;
                    if (cache.viewport_shift_exposed_only) {
                        needs_partial = true;
                        shift_requires_fullwidth_partial = true;
                    }
                }
            },
            .none => {
                if (cache.viewport_shift_exposed_only) {
                    needs_partial = true;
                    shift_requires_fullwidth_partial = true;
                }
            },
        }
        texture_full_update = needs_full;
        texture_partial_update = needs_partial;

        if ((needs_full or needs_partial) and r.beginTerminalTexture()) {
            // Disable scissor while updating the offscreen texture.
            // The main draw pass will restore the clip for on-screen drawing.
            r.endClip();
            const base_x_local: f32 = 0;
            const base_y_local: f32 = 0;

            if (needs_full) {
                const bg = if (view_cells.len > 0) blk: {
                    const cell = view_cells[0];
                    const reversed = cell.attrs.reverse != screen_reverse;
                    const base_bg = if (reversed) cell.attrs.fg else cell.attrs.bg;
                    break :blk Color{
                        .r = base_bg.r,
                        .g = base_bg.g,
                        .b = base_bg.b,
                    };
                } else r.theme.background;
                r.beginTerminalBatch();
                r.addTerminalRect(0, 0, texture_w, texture_h, bg);
                var row: usize = 0;
                while (row < rows) : (row += 1) {
                    drawRowBackgrounds(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, true, screen_reverse);
                }
                r.flushTerminalBatch();
                if (has_kitty) {
                    self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, false, start_line, rows, cols);
                }
                r.beginTerminalGlyphBatch();
                row = 0;
                while (row < rows) : (row += 1) {
                    drawRowGlyphs(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.terminal_disable_ligatures);
                }
                r.flushTerminalGlyphBatch();
                if (has_kitty) {
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, true, start_line, rows, cols);
                }
            } else if (needs_partial) {
                self.partial_draw_rows.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=rows rows={d} err={s}", .{ rows, @errorName(err) });
                    r.endTerminalTexture();
                    return outcome;
                };
                self.partial_draw_cols_start.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=cols_start rows={d} err={s}", .{ rows, @errorName(err) });
                    r.endTerminalTexture();
                    return outcome;
                };
                self.partial_draw_cols_end.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=cols_end rows={d} err={s}", .{ rows, @errorName(err) });
                    r.endTerminalTexture();
                    return outcome;
                };

                for (self.partial_draw_rows.items) |*row_draw| {
                    row_draw.* = false;
                }
                for (self.partial_draw_cols_start.items, self.partial_draw_cols_end.items) |*col_start, *col_end| {
                    col_start.* = if (cols > 0) @intCast(cols) else 0;
                    col_end.* = 0;
                }

                var row: usize = 0;
                if (shift_requires_fullwidth_partial) {
                    markAllRowsFullWidthPartialPlan(
                        self.partial_draw_rows.items,
                        self.partial_draw_cols_start.items,
                        self.partial_draw_cols_end.items,
                        rows,
                        cols,
                    );
                } else {
                    const shift_up = viewport_shift_rows > 0;
                    while (row < rows) : (row += 1) {
                        const is_shift_row = shifted_rows > 0 and (if (shift_up) row >= rows - shifted_rows else row < shifted_rows);
                        if (!((row < view_dirty_rows.len and view_dirty_rows[row]) or is_shift_row)) continue;

                        var col_start: usize = 0;
                        var col_end: usize = cols - 1;
                        if (!is_shift_row and row < cache.dirty_cols_start.items.len and row < cache.dirty_cols_end.items.len) {
                            col_start = @min(@as(usize, cache.dirty_cols_start.items[row]), cols - 1);
                            col_end = @min(@as(usize, cache.dirty_cols_end.items[row]), cols - 1);
                        }
                        markPartialPlanRows(
                            self.partial_draw_rows.items,
                            self.partial_draw_cols_start.items,
                            self.partial_draw_cols_end.items,
                            rows,
                            row,
                            col_start,
                            col_end,
                        );
                    }
                }
                if (blink_requires_partial) {
                    addBlinkRowsToPartialPlan(
                        cache,
                        self.partial_draw_rows.items,
                        self.partial_draw_cols_start.items,
                        self.partial_draw_cols_end.items,
                    );
                }

                r.beginTerminalBatch();
                row = 0;
                while (row < rows) : (row += 1) {
                    if (!self.partial_draw_rows.items[row]) continue;
                    const col_start = @min(@as(usize, self.partial_draw_cols_start.items[row]), cols - 1);
                    const col_end = @min(@as(usize, self.partial_draw_cols_end.items[row]), cols - 1);
                    const draw_padding = col_end >= cols - 1;
                    drawRowBackgrounds(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, draw_padding, screen_reverse);
                }
                r.flushTerminalBatch();
                if (has_kitty) {
                    self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, false, start_line, rows, cols);
                }
                r.beginTerminalGlyphBatch();
                row = 0;
                while (row < rows) : (row += 1) {
                    if (!self.partial_draw_rows.items[row]) continue;
                    const col_start = @min(@as(usize, self.partial_draw_cols_start.items[row]), cols - 1);
                    const col_end = @min(@as(usize, self.partial_draw_cols_end.items[row]), cols - 1);
                    drawRowGlyphs(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.terminal_disable_ligatures);
                }
                r.flushTerminalGlyphBatch();
                if (has_kitty) {
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, true, start_line, rows, cols);
                }
            }
            r.endTerminalTexture();
            if (kitty_generation != self.kitty.last_generation) {
                self.kitty.last_generation = kitty_generation;
            }
            self.terminal_texture_ready = true;
            self.last_render_generation = cache.generation;
            self.last_cell_w_i = cell_w_i;
            self.last_cell_h_i = cell_h_i;
            self.last_render_scale = r.render_scale;
            const base_x_i: i32 = @intFromFloat(std.math.round(base_x));
            const base_y_i: i32 = @intFromFloat(std.math.round(base_y));
            const clip_w_i: i32 = @min(@as(i32, @intFromFloat(std.math.round(width))), cell_w_i * @as(i32, @intCast(cols)));
            const clip_h_i: i32 = @min(@as(i32, @intFromFloat(std.math.round(height))), @as(i32, @intFromFloat(std.math.round(r.terminal_cell_height))) * @as(i32, @intCast(rows)));
            r.beginClip(
                base_x_i,
                base_y_i,
                clip_w_i,
                clip_h_i,
            );
            updated = true;
        }
        if (rows > 0 and cols > 0) {
            const bg = if (view_cells.len > 0) blk: {
                const cell = view_cells[0];
                const reversed = cell.attrs.reverse != screen_reverse;
                const base_bg = if (reversed) cell.attrs.fg else cell.attrs.bg;
                break :blk Color{
                    .r = base_bg.r,
                    .g = base_bg.g,
                    .b = base_bg.b,
                    .a = base_bg.a,
                };
            } else r.theme.background;
            r.drawRect(
                @intFromFloat(base_x),
                @intFromFloat(base_y),
                @intFromFloat(width),
                @intFromFloat(height),
                bg,
            );
        }
        r.drawTerminalTexture(base_x, base_y);
    }
    texture_update_ms = time_utils.secondsToMs(app_shell.getTime() - texture_phase_start);
    const overlay_phase_start = app_shell.getTime();
    if (!has_kitty and self.kitty.textures.count() > 0) {
        self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
    }

    if (rows > 0 and cols > 0 and selection_active) {
        const selection_rows = cache.selection_rows.items;
        if (selection_rows.len == rows) {
            const selection_color = softSelectionColor(r.theme.selection);
            const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
            const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
            const base_x_i: i32 = @intFromFloat(std.math.round(base_x));
            const base_y_i: i32 = @intFromFloat(std.math.round(base_y));

            var row_idx: usize = 0;
            while (row_idx < rows) : (row_idx += 1) {
                if (!selection_rows[row_idx]) continue;
                const col_start = @as(usize, cache.selection_cols_start.items[row_idx]);
                const col_end = @as(usize, cache.selection_cols_end.items[row_idx]);
                if (col_end < col_start or col_end >= cols) continue;

                const rect_x = base_x_i + @as(i32, @intCast(col_start)) * cell_w_i;
                const rect_y = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;
                const rect_w = cell_w_i * @as(i32, @intCast(col_end - col_start + 1));
                const rect_h = cell_h_i;

                const has_prev = row_idx > 0 and selection_rows[row_idx - 1];
                const has_next = row_idx + 1 < rows and selection_rows[row_idx + 1];
                const edge_tolerance: usize = 1;

                const top_left_exposed = !has_prev or !rowSelectionNearColumn(cache, selection_rows, row_idx - 1, col_start, edge_tolerance);
                const top_right_exposed = !has_prev or !rowSelectionNearColumn(cache, selection_rows, row_idx - 1, col_end, edge_tolerance);
                const bottom_left_exposed = !has_next or !rowSelectionNearColumn(cache, selection_rows, row_idx + 1, col_start, edge_tolerance);
                const bottom_right_exposed = !has_next or !rowSelectionNearColumn(cache, selection_rows, row_idx + 1, col_end, edge_tolerance);
                const top_left_inward = has_prev and rowSelectionNearColumn(cache, selection_rows, row_idx - 1, col_start, edge_tolerance) and rowSelectionStart(cache, row_idx - 1) + edge_tolerance < col_start;
                const top_right_inward = has_prev and rowSelectionNearColumn(cache, selection_rows, row_idx - 1, col_end, edge_tolerance) and rowSelectionEnd(cache, row_idx - 1) > col_end + edge_tolerance;
                const bottom_left_inward = has_next and rowSelectionNearColumn(cache, selection_rows, row_idx + 1, col_start, edge_tolerance) and rowSelectionStart(cache, row_idx + 1) + edge_tolerance < col_start;
                const bottom_right_inward = has_next and rowSelectionNearColumn(cache, selection_rows, row_idx + 1, col_end, edge_tolerance) and rowSelectionEnd(cache, row_idx + 1) > col_end + edge_tolerance;

                drawSoftSelectionRect(
                    r,
                    rect_x,
                    rect_y,
                    rect_w,
                    rect_h,
                    selection_color,
                    .{
                        .top_left_outward = top_left_exposed,
                        .top_right_outward = top_right_exposed,
                        .bottom_left_outward = bottom_left_exposed,
                        .bottom_right_outward = bottom_right_exposed,
                        .top_left_inward = top_left_inward,
                        .top_right_inward = top_right_inward,
                        .bottom_left_inward = bottom_left_inward,
                        .bottom_right_inward = bottom_right_inward,
                    },
                );
            }
        }
    }

    hover_mod.drawHoverUnderlineOverlay(r, base_x, base_y, rows, cols, hover_link_id, view_cells);

    if (draw_cursor and rows > 0 and cols > 0 and cursor.row < rows and cursor.col < cols and view_cells.len >= rows * cols) {
        const cursor_log = app_logger.logger("terminal.cursor");
        cursor_log.logf(
            .info,
            "cursor draw ui_focused={d} shape={s} blink={d} visible={d} row={d} col={d}",
            .{
                @intFromBool(self.ui_focused),
                @tagName(cursor_style.shape),
                @intFromBool(cursor_style.blink),
                @intFromBool(draw_cursor),
                cursor.row,
                cursor.col,
            },
        );
        const row_cells = rowSlice(view_cells, cols, cursor.row);
        if (row_cells.len != 0) {
            const cell = row_cells[cursor.col];
            const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
            const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
            const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
            const base_x_i: i32 = @intFromFloat(std.math.round(base_x));
            const base_y_i: i32 = @intFromFloat(std.math.round(base_y));
            const cell_x_i = base_x_i + @as(i32, @intCast(cursor.col)) * cell_w_i;
            const cell_y_i = base_y_i + @as(i32, @intCast(cursor.row)) * cell_h_i;
            const cell_x = @as(f32, @floatFromInt(cell_x_i));
            const cell_y = @as(f32, @floatFromInt(cell_y_i));
            const cursor_edge_inset: i32 = @max(0, @as(i32, @intFromFloat(std.math.floor(r.uiScaleFactor() * 0.5))));
            const cursor_stroke: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(r.uiScaleFactor()))));

            var fg = Color{
                .r = cell.attrs.fg.r,
                .g = cell.attrs.fg.g,
                .b = cell.attrs.fg.b,
                .a = cell.attrs.fg.a,
            };
            const bg = Color{
                .r = cell.attrs.bg.r,
                .g = cell.attrs.bg.g,
                .b = cell.attrs.bg.b,
                .a = cell.attrs.bg.a,
            };
            const underline_color = Color{
                .r = cell.attrs.underline_color.r,
                .g = cell.attrs.underline_color.g,
                .b = cell.attrs.underline_color.b,
                .a = cell.attrs.underline_color.a,
            };
            if (cell.attrs.link_id != 0) {
                fg = r.theme.link;
            }
            var underline = cell.attrs.underline;
            if (cell.attrs.link_id != 0) {
                underline = cell.attrs.link_id == hover_link_id;
            }

            const cell_reverse = cell.attrs.reverse != screen_reverse;
            const followed_by_space = blk: {
                const next_col = cursor.col + cell_width_units;
                if (next_col < cols) {
                    const next_cell = row_cells[next_col];
                    break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                }
                break :blk true;
            };

            const cursor_w_i: i32 = cell_w_i * @as(i32, @intCast(cell_width_units));
            if (!self.ui_focused) {
                const border_w: i32 = 1;
                const box_x = cell_x_i + cursor_edge_inset;
                const box_y = cell_y_i + cursor_edge_inset;
                const box_w = @max(border_w * 2, cursor_w_i - cursor_edge_inset * 2);
                const box_h = @max(border_w * 2, cell_h_i - cursor_edge_inset * 2);
                r.drawRect(box_x, box_y, box_w, border_w, r.theme.cursor);
                r.drawRect(box_x, box_y + box_h - border_w, box_w, border_w, r.theme.cursor);
                r.drawRect(box_x, box_y, border_w, box_h, r.theme.cursor);
                r.drawRect(box_x + box_w - border_w, box_y, border_w, box_h, r.theme.cursor);
            } else switch (cursor_style.shape) {
                .block => {
                    if (cell.combining_len > 0) {
                        r.drawTerminalCellGrapheme(
                            cell.codepoint,
                            cell.combining[0..@intCast(cell.combining_len)],
                            cell_x,
                            cell_y,
                            @as(f32, @floatFromInt(cursor_w_i)),
                            @as(f32, @floatFromInt(cell_h_i)),
                            if (cell_reverse) bg else fg,
                            if (cell_reverse) fg else bg,
                            underline_color,
                            cell.attrs.bold,
                            underline,
                            true,
                            followed_by_space,
                            true,
                        );
                    } else {
                        r.drawTerminalCell(
                            cell.codepoint,
                            cell_x,
                            cell_y,
                            @as(f32, @floatFromInt(cursor_w_i)),
                            @as(f32, @floatFromInt(cell_h_i)),
                            if (cell_reverse) bg else fg,
                            if (cell_reverse) fg else bg,
                            underline_color,
                            cell.attrs.bold,
                            underline,
                            true,
                            followed_by_space,
                            true,
                        );
                    }
                },
                .underline => {
                    const draw_x = cell_x_i + cursor_edge_inset;
                    const draw_w = @max(1, cursor_w_i - cursor_edge_inset * 2);
                    const draw_y = cell_y_i + cell_h_i - cursor_stroke - cursor_edge_inset;
                    r.drawRect(draw_x, draw_y, draw_w, cursor_stroke, r.theme.cursor);
                },
                .bar => {
                    const draw_x = cell_x_i + cursor_edge_inset;
                    const draw_h = @max(1, cell_h_i - cursor_edge_inset * 2);
                    const draw_y = cell_y_i + @divFloor(cell_h_i - draw_h, 2);
                    r.drawRect(draw_x, draw_y, cursor_stroke, draw_h, r.theme.cursor);
                },
            }
            const composing_cells: usize = if (input.composing_active and input.composing_text.len > 0) blk: {
                var count: usize = 0;
                var count_iter = std.unicode.Utf8Iterator{ .bytes = input.composing_text, .i = 0 };
                while (count_iter.nextCodepoint()) |_| {
                    count += 1;
                }
                break :blk count;
            } else 0;
            const cursor_rect_w = if (composing_cells > 0)
                @as(i32, @intCast(@max(@as(usize, 1), composing_cells))) * cell_w_i
            else
                cell_w_i;
            shell.setTextInputRect(
                cell_x_i,
                cell_y_i,
                cursor_rect_w,
                cell_h_i,
            );

            if (composing_cells > 0) {
                var iter = std.unicode.Utf8Iterator{ .bytes = input.composing_text, .i = 0 };
                var comp_col: usize = 0;
                while (iter.nextCodepoint()) |cp| {
                    const comp_x = cell_x + @as(f32, @floatFromInt(@as(i32, @intCast(comp_col)) * cell_w_i));
                    r.drawTerminalCell(
                        cp,
                        comp_x,
                        cell_y,
                        @as(f32, @floatFromInt(cell_w_i)),
                        @as(f32, @floatFromInt(cell_h_i)),
                        r.theme.foreground,
                        bg,
                        underline_color,
                        false,
                        true,
                        false,
                        true,
                        false,
                    );
                    comp_col += 1;
                }
                const underline_w = @as(i32, @intCast(@max(@as(usize, 1), comp_col))) * cell_w_i;
                r.drawRect(cell_x_i, cell_y_i + cell_h_i - 2, underline_w, 2, r.theme.selection);
            }
        }
    }

    if (show_scrollbar and height > 0 and width > 0) {
        const track_h = scrollbar_h;
        const min_thumb_h: f32 = 18;
        const ratio = common.scrollbarTrackRatio(max_scroll_offset, scroll_offset);
        const thumb = common.computeScrollbarThumb(scrollbar_y, track_h, rows, total_lines, min_thumb_h, ratio);

        const show_track = self.scrollbar_drag_active or self.scrollbar_hover_anim > 0.05;
        if (show_track) {
            r.drawRect(
                @intFromFloat(scrollbar_x),
                @intFromFloat(scrollbar_y),
                @intFromFloat(scrollbar_w),
                @intFromFloat(scrollbar_h),
                r.theme.line_number_bg,
            );
        }
        const thumb_inset = if (show_track) @max(1.0, scrollbar_w * 0.25) else 0;
        const thumb_w = @max(1.0, scrollbar_w - thumb_inset * 2);
        r.drawRect(
            @intFromFloat(scrollbar_x + thumb_inset),
            @intFromFloat(thumb.thumb_y),
            @intFromFloat(thumb_w),
            @intFromFloat(thumb.thumb_h),
            r.theme.selection,
        );

        // Scrollbar only; no debug chip.
    }

    if (scroll_offset > 0 and width > 0 and height > 0) {
        var label_buf: [48]u8 = undefined;
        const label = std.fmt.bufPrint(&label_buf, "SCROLLBACK {d}", .{scroll_offset}) catch "SCROLLBACK";
        const padding_x: f32 = 6;
        const padding_y: f32 = 3;
        const text_w = @as(f32, @floatFromInt(label.len)) * r.char_width;
        const box_w = text_w + padding_x * 2;
        const box_h = r.char_height + padding_y * 2;
        const desired_x = x + width - scrollbar_w - box_w - 6;
        const box_x = @max(x + 4, desired_x);
        const box_y = y + 6;

        const bg = Color{
            .r = r.theme.line_number_bg.r,
            .g = r.theme.line_number_bg.g,
            .b = r.theme.line_number_bg.b,
            .a = 220,
        };

        r.drawRect(
            @intFromFloat(box_x),
            @intFromFloat(box_y),
            @intFromFloat(box_w),
            @intFromFloat(box_h),
            bg,
        );
        r.drawText(
            label,
            box_x + padding_x,
            box_y + padding_y,
            r.theme.foreground,
        );
    }

    if (updated or cache.dirty == .none) {
        outcome.texture_updated = updated;
    }
    overlay_ms = time_utils.secondsToMs(app_shell.getTime() - overlay_phase_start);

    if (alt_exit) {
        outcome.alt_exit_info = .{
            .draw_ms = (app_shell.getTime() - draw_start_time) * 1000.0,
            .rows = rows,
            .cols = cols,
            .history_len = history_len,
            .scroll_offset = scroll_offset,
        };
    }

    const draw_log = app_logger.logger("terminal.ui.redraw");
    const perf_log = app_logger.logger("terminal.ui.perf");
    const now = app_shell.getTime();
    const elapsed_ms = time_utils.secondsToMs(now - draw_start);
    const has_kitty_images = self.kitty.images_view.items.len > 0;
    if ((elapsed_ms >= 4.0 or has_kitty_images) and (now - self.last_draw_log_time) >= 0.1) {
        self.last_draw_log_time = now;
        draw_log.logf(
            .info,
            "draw_ms={d:.2} rows={d} cols={d} history={d} cells={d} kitty_images={d} kitty_placements={d}",
            .{
                elapsed_ms,
                rows,
                cols,
                history_len,
                rows * cols,
                self.kitty.images_view.items.len,
                self.kitty.placements_view.items.len,
            },
        );
        perf_log.logf(
            .info,
            "draw_ms={d:.2} lock_ms={d:.2} cache_copy_ms={d:.2} texture_update_ms={d:.2} overlay_ms={d:.2} full={d} partial={d} updated={d} sync={d} clear_ok={d} dirty={s} dirty_rows={d} damage_rows={d} damage_cols={d} blink_cells={d} blink_phase_changed={d} full_reasons={d}/{d}/{d}/{d} full_dirty_reason={s} full_dirty_seq={d} rows={d} cols={d}",
            .{
                elapsed_ms,
                lock_ms,
                cache_copy_ms,
                texture_update_ms,
                overlay_ms,
                @intFromBool(texture_full_update),
                @intFromBool(texture_partial_update),
                @intFromBool(updated),
                @intFromBool(sync_updates),
                @intFromBool(outcome.presented != null and (outcome.texture_updated or cache.dirty == .none)),
                @tagName(cache.dirty),
                dirty_rows_count,
                damage_row_span,
                damage_col_span,
                @intFromBool(has_blink),
                @intFromBool(blink_phase_changed),
                @intFromBool(full_reason_recreated),
                @intFromBool(full_reason_cell_metrics),
                @intFromBool(full_reason_scale),
                @intFromBool(full_reason_dirty_full),
                @tagName(cache.full_dirty_reason),
                cache.full_dirty_seq,
                rows,
                cols,
            },
        );
    }

    if (self.bench_enabled) {
        const bench_log = app_logger.logger("terminal.ui.bench");
        if ((now - self.last_bench_log_time) >= 0.1) {
            self.last_bench_log_time = now;
            bench_log.logf(
                .info,
                "draw_ms={d:.2} rows={d} cols={d} upload_images={d} upload_bytes={d}",
                .{ elapsed_ms, rows, cols, upload_stats.images, upload_stats.bytes },
            );
        }
    }
    return outcome;
}

fn jitterDebugEnabled() bool {
    if (jitter_debug_enabled_cache) |cached| return cached;
    const raw = std.c.getenv("ZIDE_TERMINAL_FONT_JITTER");
    if (raw == null) {
        jitter_debug_enabled_cache = false;
        return false;
    }
    const value = std.mem.sliceTo(raw.?, 0);
    if (value.len == 0) {
        jitter_debug_enabled_cache = true;
        return true;
    }
    if (std.ascii.eqlIgnoreCase(value, "0") or
        std.ascii.eqlIgnoreCase(value, "false") or
        std.ascii.eqlIgnoreCase(value, "off") or
        std.ascii.eqlIgnoreCase(value, "no"))
    {
        jitter_debug_enabled_cache = false;
        return false;
    }
    jitter_debug_enabled_cache = true;
    return true;
}

test "viewport texture shift attempts only when fast path is eligible" {
    switch (planViewportTextureShift(true, true, 2, false, 0, false, true, 24)) {
        .attempt => |rows| try std.testing.expectEqual(@as(usize, 2), rows),
        else => return error.ExpectedShiftAttempt,
    }
}

test "viewport texture shift disable falls back to standard damage path" {
    const plan = planViewportTextureShift(false, true, 2, false, 0, false, true, 24);
    try std.testing.expectEqual(ViewportTextureShiftPlan.none, plan);
}

test "viewport texture shift oversize scroll falls back to standard damage path" {
    const plan = planViewportTextureShift(true, true, 24, false, 0, false, true, 24);
    try std.testing.expectEqual(ViewportTextureShiftPlan.none, plan);
}

test "viewport texture shift does not attempt while already forced full" {
    const plan = planViewportTextureShift(true, true, 2, false, 0, true, true, 24);
    try std.testing.expectEqual(ViewportTextureShiftPlan.none, plan);
}

test "viewport texture shift ignores scrollback view movement" {
    const plan = planViewportTextureShift(true, true, 2, false, 3, false, true, 24);
    try std.testing.expectEqual(ViewportTextureShiftPlan.none, plan);
}

test "viewport texture shift allows explicit scrollback remap path" {
    switch (planViewportTextureShift(true, true, 2, true, 3, false, true, 24)) {
        .attempt => |rows| try std.testing.expectEqual(@as(usize, 2), rows),
        else => return error.ExpectedShiftAttempt,
    }
}

test "texture update plan keeps partial redraws eligible while scrolled" {
    const plan = chooseTextureUpdatePlan(
        .partial,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
    );
    try std.testing.expect(!plan.needs_full);
    try std.testing.expect(plan.needs_partial);
}

test "texture update plan forces full redraw when texture is not ready" {
    const plan = chooseTextureUpdatePlan(
        .partial,
        false,
        false,
        false,
        false,
        false,
    );
    try std.testing.expect(plan.needs_full);
    try std.testing.expect(!plan.needs_partial);
}

test "texture update plan stays idle when dirty state is clean" {
    const plan = chooseTextureUpdatePlan(
        .none,
        false,
        false,
        false,
        true,
    );
    try std.testing.expect(!plan.needs_full);
    try std.testing.expect(!plan.needs_partial);
}

test "texture update plan keeps partial redraw for normal partial damage" {
    const plan = chooseTextureUpdatePlan(
        .partial,
        false,
        false,
        false,
        true,
    );
    try std.testing.expect(!plan.needs_full);
    try std.testing.expect(plan.needs_partial);
}

test "texture update plan uses partial redraw for blink-only changes" {
    const plan = chooseTextureUpdatePlan(
        .none,
        false,
        false,
        false,
        true,
        true,
    );
    try std.testing.expect(!plan.needs_full);
    try std.testing.expect(plan.needs_partial);
}

test "full-width partial plan marks every row" {
    var rows = [_]bool{ false, false, false };
    var cols_start = [_]u16{ 9, 9, 9 };
    var cols_end = [_]u16{ 0, 0, 0 };

    markAllRowsFullWidthPartialPlan(&rows, &cols_start, &cols_end, 3, 5);

    for (rows) |row_marked| {
        try std.testing.expect(row_marked);
    }
    for (cols_start) |start| {
        try std.testing.expectEqual(@as(u16, 0), start);
    }
    for (cols_end) |end| {
        try std.testing.expectEqual(@as(u16, 4), end);
    }
}
