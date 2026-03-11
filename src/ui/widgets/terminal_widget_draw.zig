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
const draw_overlay = @import("terminal_widget_draw_overlay.zig");
const draw_texture = @import("terminal_widget_draw_texture.zig");

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
const drawOverlays = draw_overlay.drawOverlays;

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

const ViewportTextureShiftPlan = draw_texture.ViewportTextureShiftPlan;
const TextureUpdatePlan = draw_texture.TextureUpdatePlan;

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
    var partial_plan_rows_count: usize = 0;
    var partial_plan_row_span: usize = 0;
    var partial_plan_col_span: usize = 0;
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

                const partial_plan_bounds = buildPartialPlan(
                    cache,
                    self.partial_draw_rows.items,
                    self.partial_draw_cols_start.items,
                    self.partial_draw_cols_end.items,
                    shifted_rows,
                    viewport_shift_rows,
                    shift_requires_fullwidth_partial,
                    blink_requires_partial,
                );
                for (self.partial_draw_rows.items) |row_draw| {
                    if (row_draw) partial_plan_rows_count += 1;
                }
                if (partial_plan_bounds) |bounds| {
                    partial_plan_row_span = bounds.end_row - bounds.start_row + 1;
                    partial_plan_col_span = bounds.end_col - bounds.start_col + 1;
                }

                r.beginTerminalBatch();
                for (0..rows) |row| {
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
                for (0..rows) |row| {
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

    drawOverlays(
        self,
        shell,
        base_x,
        base_y,
        width,
        height,
        input,
        cache,
        view_cells,
        rows,
        cols,
        scroll_offset,
        total_lines,
        max_scroll_offset,
        screen_reverse,
        hover_link_id,
        draw_cursor,
        cursor,
        cursor_style,
    );

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
            "draw_ms={d:.2} lock_ms={d:.2} cache_copy_ms={d:.2} texture_update_ms={d:.2} overlay_ms={d:.2} full={d} partial={d} updated={d} sync={d} clear_ok={d} dirty={s} dirty_rows={d} damage_rows={d} damage_cols={d} plan_rows={d} plan_row_span={d} plan_col_span={d} blink_cells={d} blink_phase_changed={d} full_reasons={d}/{d}/{d}/{d} full_dirty_reason={s} full_dirty_seq={d} rows={d} cols={d}",
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
                partial_plan_rows_count,
                partial_plan_row_span,
                partial_plan_col_span,
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
const planViewportTextureShift = draw_texture.planViewportTextureShift;
const chooseTextureUpdatePlan = draw_texture.chooseTextureUpdatePlan;
const buildPartialPlan = draw_texture.buildPartialPlan;
const markAllRowsFullWidthPartialPlan = draw_texture.markAllRowsFullWidthPartialPlan;
