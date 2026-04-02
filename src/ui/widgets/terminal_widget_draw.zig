const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const retained_targets_runtime = @import("../renderer/retained_targets_runtime.zig");
const scene_frame_runtime = @import("../renderer/scene_frame_runtime.zig");
const draw_grid = @import("terminal_widget_draw_grid.zig");
const draw_overlay = @import("terminal_widget_draw_overlay.zig");
const draw_texture = @import("terminal_widget_draw_texture.zig");
const draw_metrics = @import("terminal_widget_draw_metrics.zig");
const view_state = @import("terminal_widget_view_state.zig");

const hover_mod = @import("terminal_widget_hover.zig");
const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_publication.CursorPos;
const Cell = terminal_publication.Cell;
const Rgba = terminal_font_mod.Rgba;

const RenderCache = render_cache_mod.RenderCache;
const PresentationCapture = terminal_publication.PresentationCapture;
const PresentedRenderCache = terminal_publication.PresentedRenderCache;
const PresentationFeedback = terminal_publication.PresentationFeedback;
pub const FrameLatencyMetrics = draw_metrics.FrameLatencyMetrics;

pub const DrawOutcome = PresentationFeedback;
const drawRowBackgrounds = draw_grid.drawRowBackgrounds;
const drawRowGlyphs = draw_grid.drawRowGlyphs;
const drawOverlays = draw_overlay.drawOverlays;
const GlyphDrawStats = draw_grid.GlyphDrawStats;

pub const DrawPreparation = struct {
    draw_start: f64,
    lock_ms: f64,
    lock_wait_ms: f64,
    lock_hold_ms: f64,
    view_cache_ms: f64,
    cache_copy_ms: f64,
    presented: PresentedRenderCache,

    pub fn fromCapture(draw_start: f64, capture: PresentationCapture) DrawPreparation {
        return .{
            .draw_start = draw_start,
            .lock_ms = capture.lock_ms,
            .lock_wait_ms = capture.lock_wait_ms,
            .lock_hold_ms = capture.lock_hold_ms,
            .view_cache_ms = capture.view_cache_ms,
            .cache_copy_ms = capture.cache_copy_ms,
            .presented = capture.presented,
        };
    }
};

const ViewportTextureShiftPlan = draw_texture.ViewportTextureShiftPlan;
const TextureUpdatePlan = draw_texture.TextureUpdatePlan;
const FullFrameFastPathDecision = draw_texture.FullFrameFastPathDecision;

const ViewportShiftState = struct {
    rows: i32 = 0,
    exposed_only: bool = false,
};

pub fn latestFrameLatencyMetrics() FrameLatencyMetrics {
    return draw_metrics.latestFrameLatencyMetrics();
}

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

fn toShellColor(color: terminal_publication.Color) Color {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
}

fn spansOverlap(start_a: usize, end_a: usize, start_b: usize, end_b: usize) bool {
    return start_a <= end_b and start_b <= end_a;
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
    const lock_wait_ms: f64 = preparation.lock_wait_ms;
    const lock_hold_ms: f64 = preparation.lock_hold_ms;
    const view_cache_ms: f64 = preparation.view_cache_ms;
    const cache_copy_ms: f64 = preparation.cache_copy_ms;
    var texture_update_ms: f64 = 0.0;
    var texture_bg_ms: f64 = 0.0;
    var texture_glyph_ms: f64 = 0.0;
    var texture_kitty_ms: f64 = 0.0;
    var glyph_draw_stats = GlyphDrawStats{};
    var overlay_ms: f64 = 0.0;
    var render_phase_start = draw_start;
    var outcome = DrawOutcome{ .presented = preparation.presented };
    defer {
        const draw_end = app_shell.getTime();
        const draw_ms_total = time_utils.secondsToMs(draw_end - draw_start);
        const render_ms = time_utils.secondsToMs(draw_end - render_phase_start);
        draw_metrics.publishFrameLatencyMetrics(
            view_state.drawStateInfo(&self.draw_cache).generation,
            lock_ms,
            lock_wait_ms,
            lock_hold_ms,
            view_cache_ms,
            cache_copy_ms,
            texture_update_ms,
            texture_bg_ms,
            texture_glyph_ms,
            texture_kitty_ms,
            overlay_ms,
            render_ms,
            draw_ms_total,
        );
    }

    const r = shell.rendererPtr();
    const cache = &self.draw_cache;
    const lifecycle_transition = view_state.lifecycleTransitionInfo(self.retained.last_alt_active, cache);
    const alt_exit = lifecycle_transition.exited;
    self.retained.last_alt_active = lifecycle_transition.current_alt_active;
    render_phase_start = app_shell.getTime();

    const draw_state = view_state.drawStateInfo(cache);
    const render_state = draw_state.render;
    const sync_updates = draw_state.sync_updates_active;
    const retained_surface_ready = self.retained.terminal_texture_ready and retained_targets_runtime.terminalSurfaceAvailable(r);
    const screen_reverse = render_state.screen_reverse;
    const blink_style = self.blink_style;
    const blink_time = app_shell.getTime();
    const rows = draw_state.rows;
    const cols = draw_state.cols;
    const view_cells = draw_state.cells;
    const base_colors = view_state.baseColorInfo(cache);
    if (sync_updates and view_cells.len > 0 and retained_surface_ready) {
        const bg_color = if (view_cells.len > 0) toShellColor(base_colors.resolved_background) else r.theme.background;
        r.drawRect(
            @intFromFloat(x),
            @intFromFloat(y),
            @intFromFloat(width),
            @intFromFloat(height),
            bg_color,
        );
        retained_targets_runtime.drawTerminalSurface(r, x, y, width, height, self.retained.last_render_generation);
        return outcome;
    }
    const draw_start_time = if (alt_exit) app_shell.getTime() else 0;
    const viewport = draw_state.viewport;
    const history_len = viewport.history_len;
    const scroll_offset = viewport.scroll_offset;
    const start_line = viewport.start_line;
    var draw_cursor = render_state.draw_cursor_visible;
    const cursor = if (draw_cursor) draw_state.cursor else CursorPos{ .row = rows + 1, .col = cols + 1 };
    const cursor_style = render_state.cursor_style;
    if (draw_cursor and self.ui_focused and cursor_style.blink) {
        if (blink_time >= self.cursor_blink_pause_until) {
            const period: f64 = 0.5;
            const phase = @mod(blink_time, period * 2.0);
            draw_cursor = phase < period;
        }
    }
    const kitty_generation = draw_state.kitty_generation;
    const has_blink = blink_style != .off and render_state.has_blinking_cells;
    const blink_phase_changed = self.blink_phase_changed_pending;
    self.blink_phase_changed_pending = false;
    const blink_requires_partial = has_blink and blink_phase_changed;

    const has_kitty = self.kitty.prepareForDraw(
        self.session.allocator,
        shell,
        rows,
        cols,
        draw_state.kitty_images,
        draw_state.kitty_placements,
    );
    const bg_color = if (view_cells.len > 0) toShellColor(base_colors.background) else r.theme.background;
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

    self.hover.dirty = false;
    const hover_link_id = hover_mod.hoverLinkId(&self.hover);

    var updated = false;
    var viewport_shift = ViewportShiftState{};
    var cell_w_i: i32 = 0;
    var cell_h_i: i32 = 0;
    var visible_w: i32 = 0;
    var visible_h: i32 = 0;
    var viewport_w: f32 = 0;
    var viewport_h: f32 = 0;
    const texture_phase_start = app_shell.getTime();
    if (rows > 0 and cols > 0) {
        const geom = r.terminalCellGeometry();
        cell_w_i = geom.cell_width_device_px;
        cell_h_i = geom.cell_height_device_px;
        const cell_metrics_changed = cell_w_i != self.retained.last_cell_w_i or cell_h_i != self.retained.last_cell_h_i;
        const render_scale_changed = r.scale.render_scale != self.retained.last_render_scale;
        const padding_x_i: i32 = @max(2, @divTrunc(cell_w_i, 2));
        const scale = if (r.scale.render_scale > 0.0) r.scale.render_scale else 1.0;
        const texture_w = @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(cell_w_i * @as(i32, @intCast(cols)) + padding_x_i)) / scale)));
        const texture_h = @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(cell_h_i * @as(i32, @intCast(rows)))) / scale)));
        const clip_w = @min(width, geom.cell_width_logical_exact * @as(f32, @floatFromInt(cols)));
        const clip_h = @min(height, geom.cell_height_logical_exact * @as(f32, @floatFromInt(rows)));
        const visible_cols: i32 = if (geom.cell_width_logical_exact > 0) @intFromFloat(std.math.floor(clip_w / geom.cell_width_logical_exact)) else 0;
        const visible_rows: i32 = if (geom.cell_height_logical_exact > 0) @intFromFloat(std.math.floor(clip_h / geom.cell_height_logical_exact)) else 0;
        visible_w = @intFromFloat(std.math.round(@as(f32, @floatFromInt(visible_cols * geom.cell_width_device_px)) / scale));
        visible_h = @intFromFloat(std.math.round(@as(f32, @floatFromInt(visible_rows * geom.cell_height_device_px)) / scale));
        viewport_w = @as(f32, @floatFromInt(visible_w));
        viewport_h = @as(f32, @floatFromInt(visible_h));
        const recreated = retained_targets_runtime.ensureTerminalSurface(r, texture_w, texture_h);
        const gen_changed = draw_state.generation != self.retained.last_render_generation;
        const clear_generation_changed = draw_state.clear_generation != self.retained.last_render_clear_generation;
        var update_plan = chooseTextureUpdatePlan(
            cache.dirty,
            recreated,
            clear_generation_changed,
            cell_metrics_changed,
            render_scale_changed,
            blink_requires_partial,
            self.retained.terminal_texture_ready,
        );
        const plan_time = app_shell.getTime();
        const recent_input_window_active = r.forceFullTerminalTexturePublicationRecentInputWindow() and
            ((input.mods.ctrl or input.mods.shift or input.mods.alt or input.mods.super) or
                (self.last_terminal_input_time > 0 and
                    plan_time >= self.last_terminal_input_time and
                    (plan_time - self.last_terminal_input_time) <= r.fullTerminalTexturePublicationRecentInputWindowSeconds()));
        update_plan = forceFullTextureUpdatePlanEveryFrame(
            update_plan,
            recent_input_window_active,
        );
        var needs_full = update_plan.needs_full;
        var needs_partial = update_plan.needs_partial;
        const partial_capture = view_state.partialCaptureInfo(cache);
        viewport_shift.rows = partial_capture.active_viewport_shift_rows;
        viewport_shift.exposed_only = partial_capture.shift_exposed_only;
        var shifted_rows: usize = 0;
        var shift_requires_fullwidth_partial = false;
        switch (planViewportTextureShift(
            r.terminalTextureShiftEnabled(),
            gen_changed,
            viewport_shift.rows,
            viewport_shift.exposed_only,
            scroll_offset,
            needs_full,
            self.retained.terminal_texture_ready,
            rows,
        )) {
            .attempt => |shift_rows| {
                const dy_pixels: i32 = -viewport_shift.rows * cell_h_i;
                if (retained_targets_runtime.scrollTerminalSurface(r, 0, dy_pixels)) {
                    needs_partial = true;
                    shifted_rows = shift_rows;
                } else {
                    shifted_rows = 0;
                    if (viewport_shift.exposed_only) {
                        needs_partial = true;
                        shift_requires_fullwidth_partial = true;
                    }
                }
            },
            .none => {
                if (viewport_shift.exposed_only) {
                    needs_partial = true;
                    shift_requires_fullwidth_partial = true;
                }
            },
        }
        if (!needs_full and needs_partial) {
            const fullframe_fastpath_decision: FullFrameFastPathDecision = draw_texture.decideFullFrameFastPath(
                cache,
                shifted_rows,
                viewport_shift.rows,
                shift_requires_fullwidth_partial,
                blink_requires_partial,
                0.85,
            );
            if (fullframe_fastpath_decision.threshold_hit) {
                needs_full = true;
                needs_partial = false;
            }
        }
        if (!needs_full and needs_partial) {
            self.retained.partial_draw_rows.resize(self.session.allocator, rows) catch |err| {
                const log = app_logger.logger("terminal.ui.redraw");
                log.logf(.warning, "partial row plan resize failed field=rows rows={d} err={s}", .{ rows, @errorName(err) });
                needs_full = true;
                needs_partial = false;
            };
            self.retained.partial_draw_cols_start.resize(self.session.allocator, rows) catch |err| {
                const log = app_logger.logger("terminal.ui.redraw");
                log.logf(.warning, "partial row plan resize failed field=cols_start rows={d} err={s}", .{ rows, @errorName(err) });
                needs_full = true;
                needs_partial = false;
            };
            self.retained.partial_draw_cols_end.resize(self.session.allocator, rows) catch |err| {
                const log = app_logger.logger("terminal.ui.redraw");
                log.logf(.warning, "partial row plan resize failed field=cols_end rows={d} err={s}", .{ rows, @errorName(err) });
                needs_full = true;
                needs_partial = false;
            };
            self.retained.partial_draw_span_counts.resize(self.session.allocator, rows) catch |err| {
                const log = app_logger.logger("terminal.ui.redraw");
                log.logf(.warning, "partial row plan resize failed field=span_counts rows={d} err={s}", .{ rows, @errorName(err) });
                needs_full = true;
                needs_partial = false;
            };
            self.retained.partial_draw_spans.resize(self.session.allocator, rows) catch |err| {
                const log = app_logger.logger("terminal.ui.redraw");
                log.logf(.warning, "partial row plan resize failed field=spans rows={d} err={s}", .{ rows, @errorName(err) });
                needs_full = true;
                needs_partial = false;
            };
            if (!needs_full and needs_partial) {
                _ = buildPartialPlan(
                    cache,
                    self.retained.partial_draw_rows.items,
                    self.retained.partial_draw_span_counts.items,
                    self.retained.partial_draw_spans.items,
                    self.retained.partial_draw_cols_start.items,
                    self.retained.partial_draw_cols_end.items,
                    shifted_rows,
                    viewport_shift.rows,
                    shift_requires_fullwidth_partial,
                    blink_requires_partial,
                );
            }
        }
        if ((needs_full or needs_partial) and retained_targets_runtime.beginTerminalSurface(r)) {
            // Disable scissor while updating the offscreen texture.
            // The main draw pass will restore the clip for on-screen drawing.
            r.endClip();
            const base_x_local: f32 = 0;
            const base_y_local: f32 = 0;

            if (needs_full) {
                const bg_phase_start = app_shell.getTime();
                const bg = if (view_cells.len > 0) toShellColor(base_colors.resolved_background) else r.theme.background;
                r.beginTerminalBatch();
                r.addTerminalRect(0, 0, texture_w, texture_h, bg);
                var row: usize = 0;
                while (row < rows) : (row += 1) {
                    drawRowBackgrounds(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, true, screen_reverse, draw_cursor, cursor, cursor_style);
                }
                r.flushTerminalBatch();
                texture_bg_ms += time_utils.secondsToMs(app_shell.getTime() - bg_phase_start);
                if (has_kitty) {
                    const kitty_phase_start = app_shell.getTime();
                    self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, false, start_line, rows, cols);
                    texture_kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
                }
                const glyph_phase_start = app_shell.getTime();
                r.terminal_font.beginFrameAtlasStats();
                r.beginTerminalGlyphBatch();
                row = 0;
                while (row < rows) : (row += 1) {
                    drawRowGlyphs(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.font_config.terminal_disable_ligatures, &glyph_draw_stats);
                }
                r.flushTerminalGlyphBatch();
                texture_glyph_ms += time_utils.secondsToMs(app_shell.getTime() - glyph_phase_start);
                if (has_kitty) {
                    const kitty_phase_start = app_shell.getTime();
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, true, start_line, rows, cols);
                    texture_kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
                }
            } else if (needs_partial) {
                self.retained.partial_draw_rows.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=rows rows={d} err={s}", .{ rows, @errorName(err) });
                    scene_frame_runtime.restoreMainCompositionTarget(r);
                    return outcome;
                };
                self.retained.partial_draw_cols_start.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=cols_start rows={d} err={s}", .{ rows, @errorName(err) });
                    scene_frame_runtime.restoreMainCompositionTarget(r);
                    return outcome;
                };
                self.retained.partial_draw_cols_end.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=cols_end rows={d} err={s}", .{ rows, @errorName(err) });
                    scene_frame_runtime.restoreMainCompositionTarget(r);
                    return outcome;
                };

                self.retained.partial_draw_span_counts.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=span_counts rows={d} err={s}", .{ rows, @errorName(err) });
                    scene_frame_runtime.restoreMainCompositionTarget(r);
                    return outcome;
                };
                self.retained.partial_draw_spans.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=spans rows={d} err={s}", .{ rows, @errorName(err) });
                    scene_frame_runtime.restoreMainCompositionTarget(r);
                    return outcome;
                };

                _ = buildPartialPlan(
                    cache,
                    self.retained.partial_draw_rows.items,
                    self.retained.partial_draw_span_counts.items,
                    self.retained.partial_draw_spans.items,
                    self.retained.partial_draw_cols_start.items,
                    self.retained.partial_draw_cols_end.items,
                    shifted_rows,
                    viewport_shift.rows,
                    shift_requires_fullwidth_partial,
                    blink_requires_partial,
                );

                const bg_phase_start = app_shell.getTime();
                r.beginTerminalBatch();
                for (0..rows) |row| {
                    if (!self.retained.partial_draw_rows.items[row]) continue;
                    if (row < self.retained.partial_draw_span_counts.items.len and row < self.retained.partial_draw_spans.items.len and self.retained.partial_draw_span_counts.items[row] > 0) {
                        var span_idx: usize = 0;
                        while (span_idx < self.retained.partial_draw_span_counts.items[row]) : (span_idx += 1) {
                            const span = self.retained.partial_draw_spans.items[row][span_idx];
                            const col_start = @min(@as(usize, span.start), cols - 1);
                            const col_end = @min(@as(usize, span.end), cols - 1);
                            const draw_padding = col_end >= cols - 1;
                            drawRowBackgrounds(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, draw_padding, screen_reverse, draw_cursor, cursor, cursor_style);
                        }
                        continue;
                    }
                    const col_start = @min(@as(usize, self.retained.partial_draw_cols_start.items[row]), cols - 1);
                    const col_end = @min(@as(usize, self.retained.partial_draw_cols_end.items[row]), cols - 1);
                    const draw_padding = col_end >= cols - 1;
                    drawRowBackgrounds(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, draw_padding, screen_reverse, draw_cursor, cursor, cursor_style);
                }
                r.flushTerminalBatch();
                texture_bg_ms += time_utils.secondsToMs(app_shell.getTime() - bg_phase_start);
                if (has_kitty) {
                    const kitty_phase_start = app_shell.getTime();
                    self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, false, start_line, rows, cols);
                    texture_kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
                }
                const glyph_phase_start = app_shell.getTime();
                r.terminal_font.beginFrameAtlasStats();
                r.beginTerminalGlyphBatch();
                for (0..rows) |row| {
                    if (!self.retained.partial_draw_rows.items[row]) continue;
                    if (row < self.retained.partial_draw_span_counts.items.len and row < self.retained.partial_draw_spans.items.len and self.retained.partial_draw_span_counts.items[row] > 0) {
                        var span_idx: usize = 0;
                        while (span_idx < self.retained.partial_draw_span_counts.items[row]) : (span_idx += 1) {
                            const span = self.retained.partial_draw_spans.items[row][span_idx];
                            const col_start = @min(@as(usize, span.start), cols - 1);
                            const col_end = @min(@as(usize, span.end), cols - 1);
                            drawRowGlyphs(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.font_config.terminal_disable_ligatures, &glyph_draw_stats);
                        }
                    } else {
                        const col_start = @min(@as(usize, self.retained.partial_draw_cols_start.items[row]), cols - 1);
                        const col_end = @min(@as(usize, self.retained.partial_draw_cols_end.items[row]), cols - 1);
                        drawRowGlyphs(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.font_config.terminal_disable_ligatures, &glyph_draw_stats);
                    }
                }
                r.flushTerminalGlyphBatch();
                texture_glyph_ms += time_utils.secondsToMs(app_shell.getTime() - glyph_phase_start);
                if (has_kitty) {
                    const kitty_phase_start = app_shell.getTime();
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, true, start_line, rows, cols);
                    texture_kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
                }
            }
            scene_frame_runtime.restoreMainCompositionTarget(r);
            self.retained.terminal_texture_ready = true;
            self.retained.last_render_generation = draw_state.generation;
            self.retained.last_render_clear_generation = draw_state.clear_generation;
            self.retained.last_cell_w_i = cell_w_i;
            self.retained.last_cell_h_i = cell_h_i;
            self.retained.last_render_scale = r.scale.render_scale;
            if (visible_w > 0 and visible_h > 0) {
                r.beginClip(
                    @intFromFloat(std.math.round(base_x)),
                    @intFromFloat(std.math.round(base_y)),
                    visible_w,
                    visible_h,
                );
            }
            updated = true;
        }
        const retained_surface_ready_after_update = self.retained.terminal_texture_ready and retained_targets_runtime.terminalSurfaceAvailable(r);
        if (!updated and retained_surface_ready_after_update and visible_w > 0 and visible_h > 0) {
            r.beginClip(
                @intFromFloat(std.math.round(base_x)),
                @intFromFloat(std.math.round(base_y)),
                visible_w,
                visible_h,
            );
        }
        if (rows > 0 and cols > 0) {
            const bg = if (view_cells.len > 0) toShellColor(base_colors.resolved_background) else r.theme.background;
            if (visible_w > 0 and visible_h > 0) {
                r.drawRectF(base_x, base_y, viewport_w, viewport_h, bg);
            }
        }
        if (retained_surface_ready_after_update and visible_w > 0 and visible_h > 0) {
            retained_targets_runtime.drawTerminalSurface(r, base_x, base_y, viewport_w, viewport_h, self.retained.last_render_generation);
        }
    }
    texture_update_ms = time_utils.secondsToMs(app_shell.getTime() - texture_phase_start);
    const overlay_phase_start = app_shell.getTime();
    self.kitty.finishDraw(self.session.allocator, kitty_generation, has_kitty);
    drawOverlays(
        self,
        shell,
        base_x,
        base_y,
        viewport_w,
        viewport_h,
        input,
        cache,
        view_cells,
        rows,
        cols,
        screen_reverse,
        hover_link_id,
        draw_cursor,
        cursor,
        cursor_style,
    );

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
    return outcome;
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
const useViewportShiftForPartialPlan = draw_texture.useViewportShiftForPartialPlan;
const chooseTextureUpdatePlan = draw_texture.chooseTextureUpdatePlan;
const forceFullTextureUpdatePlan = draw_texture.forceFullTextureUpdatePlan;
const forceFullTextureUpdatePlanEveryFrame = draw_texture.forceFullTextureUpdatePlanEveryFrame;
const buildPartialPlan = draw_texture.buildPartialPlan;
const markAllRowsFullWidthPartialPlan = draw_texture.markAllRowsFullWidthPartialPlan;

test "useViewportShiftForPartialPlan ignores stale shift metadata on clean frames" {
    try std.testing.expect(!useViewportShiftForPartialPlan(.none, 1));
    try std.testing.expect(!useViewportShiftForPartialPlan(.full, 1));
    try std.testing.expect(useViewportShiftForPartialPlan(.partial, 1));
}
