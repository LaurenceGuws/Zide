//! Terminal widget draw path: **generation** truth for publication vs last surface draw
//! lives in `surface_contract` (via presentation delta / cache). **Pipeline** vs **host
//! target** legs and their **full attachment** conjunction are `surface_attachment_contract`
//! (`TerminalWidgetSurfaceState`: `terminalPresentablePipelineReady`, `hostSurfaceTargetAvailable`,
//! `notePresentableAvailability`).
//! **Conjunction propagation (`CZH-S22`, **canonical route CZH-791**):** this draw module
//! does **not** compute or store the conjunction; presentation runtime does exclusively via
//! **canonical helper** `TerminalWidgetSurfaceState.notePresentableAvailability()` (calls
//! `surface_attachment_contract.hostSharedSurfaceAttachmentReady`). Runtime stores conjunction on
//! `PresentationPresentState` and `TerminalPresentResult`. This module orchestrates draw and
//! delegates presentation to `terminal_widget_presentation_runtime` (`CZH-S16`, vocabulary lock `CZH-S18`).
//!
//! **Observability (`CZH-B24`, alias lock `CZH-B25`):** glyph-prep adopt warnings label
//! raster/publication-stage generation; attachment legs on widget state use dominant field names
//! `terminal_presentable_pipeline_ready` and `host_surface_target_available` — keep those distinct
//! in operator-facing strings. **Present-result ownership (`CZH-B26`):** do not treat host-target
//! availability alone as full attachment when reading `TerminalPresentResult` / reuse outcomes.
//! **Reporting carrier (`CZH-S23`):** draw does not emit `renderer.terminal_present`; conjunction in
//! that log is owned by presentation runtime (`PresentationPresentState.shared_surface_attachment_ready`).
//! **Draw vs runtime (`CZH-S24`, **single-derivation-story enforcement CZH-S26**):** this module
//! **consumes** surface/presentation cache state for raster work; **`terminal_widget_presentation_runtime`**
//! owns present-time leg updates, reporting snapshots, and **`TerminalPresentResult`** folds — draw does
//! not re-derive aggregation fields, re-compute conjunction, or parallel-derive outcome state.
const std = @import("std");
const surface_attachment_contract = @import("../../terminal/surface_attachment_contract.zig");
const app_shell = @import("../../app_shell.zig");
const publication_capture = @import("../../terminal/core/publication/publication_capture.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const font_manager = @import("../renderer/font_manager.zig");
const draw_grid = @import("terminal_widget_draw_grid.zig");
const draw_overlay = @import("terminal_widget_draw_overlay.zig");
const draw_presentation = @import("terminal_widget_draw_plan.zig");
const draw_metrics = @import("terminal_widget_draw_metrics.zig");
const presentation_runtime = @import("terminal_widget_presentation_runtime.zig");
const view_state = @import("terminal_widget_view_state.zig");
const renderer_presentable_host = @import("../renderer/renderer_presentable_host.zig");

const hover_mod = @import("terminal_widget_hover.zig");
const Shell = app_shell.Shell;
const CursorPos = terminal_publication.CursorPos;
const PresentationCapture = publication_capture.PresentationCapture;
const PresentedRenderCache = terminal_publication.PresentedRenderCache;
const PresentationFeedback = terminal_publication.PresentationFeedback;
pub const FrameLatencyMetrics = draw_metrics.FrameLatencyMetrics;

pub const DrawOutcome = PresentationFeedback;
const drawRowBackgrounds = draw_grid.drawRowBackgrounds;
const drawRowGlyphs = draw_grid.drawRowGlyphs;
const drawOverlays = draw_overlay.drawOverlays;
const TerminalGlyphPrepEntry = @import("../renderer.zig").TerminalGlyphPrepEntry;
const TerminalGlyphPrepResult = @import("../renderer.zig").TerminalGlyphPrepResult;

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

const ViewportPresentationShiftPlan = draw_presentation.ViewportPresentShiftPlan;

pub fn latestFrameLatencyMetrics() FrameLatencyMetrics {
    return draw_metrics.latestFrameLatencyMetrics();
}

fn spansOverlap(start_a: usize, end_a: usize, start_b: usize, end_b: usize) bool {
    return start_a <= end_b and start_b <= end_a;
}

fn terminalGlyphPrepRenderScaleMilli(renderer: anytype) u32 {
    const scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    return @intFromFloat(@max(1.0, std.math.round(scale * 1000.0)));
}

fn terminalGlyphPrepCommittedRasterSize(renderer: anytype) u32 {
    const scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    return @intFromFloat(@max(1.0, std.math.round(renderer.terminal_font_size * scale)));
}

fn stageVisibleTerminalGlyphPrepRequest(
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    hover_link_id: u32,
    screen_reverse_mode: bool,
    blink_style: anytype,
    blink_time: f64,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: anytype,
) void {
    if (terminal_view.rows == 0 or terminal_view.cols == 0) return;
    const committed_raster_size_px = terminalGlyphPrepCommittedRasterSize(renderer);
    const render_scale_milli = terminalGlyphPrepRenderScaleMilli(renderer);

    renderer.lockTerminalGlyphPrepRuntime();
    const should_collect = renderer.shouldCollectTerminalGlyphPrepEntries(
        terminal_view.generation,
        terminal_view.rows,
        terminal_view.cols,
        committed_raster_size_px,
        render_scale_milli,
    );
    renderer.unlockTerminalGlyphPrepRuntime();
    if (!should_collect) return;

    var entries: std.ArrayListUnmanaged(TerminalGlyphPrepEntry) = .{};
    defer entries.deinit(renderer.allocator);
    draw_grid.collectVisibleTerminalGlyphPrepEntries(
        renderer.allocator,
        renderer,
        terminal_view.cells,
        terminal_view.rows,
        terminal_view.cols,
        hover_link_id,
        screen_reverse_mode,
        blink_style,
        blink_time,
        draw_cursor,
        cursor,
        cursor_style,
        renderer.font_config.terminal_disable_ligatures,
        &entries,
    ) catch return;

    const request_hash = std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(entries.items));
    renderer.lockTerminalGlyphPrepRuntime();
    defer renderer.unlockTerminalGlyphPrepRuntime();
    renderer.noteTerminalGlyphPrepCollection(
        terminal_view.generation,
        terminal_view.rows,
        terminal_view.cols,
        committed_raster_size_px,
        render_scale_milli,
    );
    const stage_outcome = renderer.stageTerminalGlyphPrepRequest(
        committed_raster_size_px,
        render_scale_milli,
        request_hash,
        entries.items,
    ) catch return;
    if (!stage_outcome.staged) return;
    renderer.signalTerminalGlyphPrepRuntime();
}

fn adoptPreparedTerminalGlyphResult(renderer: anytype, result: *TerminalGlyphPrepResult) void {
    const log = app_logger.logger("renderer.font");
    const current_render_scale_milli = terminalGlyphPrepRenderScaleMilli(renderer);
    if (result.render_scale_milli != current_render_scale_milli) return;

    const render_scale = @as(f32, @floatFromInt(result.render_scale_milli)) / 1000.0;
    const target_font = font_manager.ensureCommittedTerminalFontCacheEntry(
        renderer,
        result.committed_raster_size_px,
        render_scale,
    ) orelse {
        log.logf(.warning, "terminal_glyph_prep_adopt_target_missing publication_generation={d} raster={d} scale_milli={d} glyphs={d}", .{
            result.generation,
            result.committed_raster_size_px,
            result.render_scale_milli,
            result.glyphs.len,
        });
        return;
    };

    for (result.glyphs) |*glyph| {
        const face = target_font.faceForSlot(glyph.entry.face_slot) orelse {
            continue;
        };
        if (target_font.hasGlyphCachedById(face, glyph.entry.glyph_id, glyph.entry.want_color, glyph.entry.italic)) {
            continue;
        }
        target_font.adoptPreparedGlyph(
            face,
            glyph.entry.glyph_id,
            glyph.entry.want_color,
            glyph.entry.italic,
            glyph.raster,
            true,
        ) catch {
            continue;
        };
        if (glyph.raster.data.len > 0) renderer.allocator.free(glyph.raster.data);
        glyph.raster.data = &.{};
    }
}

fn adoptAvailableTerminalGlyphPrepResult(renderer: anytype) void {
    var result = renderer.takeTerminalGlyphPrepResult() orelse return;
    defer result.deinit(renderer.allocator);
    adoptPreparedTerminalGlyphResult(renderer, &result);
    _ = font_manager.commitPreparedTerminalFontScale(renderer);
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
    const cache = self.publication.cacheConst();
    const terminal_view = self.publication.model();
    const lock_ms: f64 = preparation.lock_ms;
    const lock_wait_ms: f64 = preparation.lock_wait_ms;
    const lock_hold_ms: f64 = preparation.lock_hold_ms;
    const view_cache_ms: f64 = preparation.view_cache_ms;
    const cache_copy_ms: f64 = preparation.cache_copy_ms;
    var presentation_update_ms: f64 = 0.0;
    var presentation_bg_ms: f64 = 0.0;
    var presentation_glyph_ms: f64 = 0.0;
    var presentation_kitty_ms: f64 = 0.0;
    var overlay_ms: f64 = 0.0;
    var render_phase_start = draw_start;
    var outcome = DrawOutcome{ .presented = preparation.presented };
    const r = shell.rendererPtr();
    defer {
        const draw_end = app_shell.getTime();
        const draw_ms_total = time_utils.secondsToMs(draw_end - draw_start);
        const render_ms = time_utils.secondsToMs(draw_end - render_phase_start);
        draw_metrics.publishFrameLatencyMetrics(
            r.capabilities().terminal_presentation_mode,
            self.debug.last_terminal_presentation.mode,
            terminal_view.generation,
            lock_ms,
            lock_wait_ms,
            lock_hold_ms,
            view_cache_ms,
            cache_copy_ms,
            presentation_update_ms,
            presentation_bg_ms,
            presentation_glyph_ms,
            presentation_kitty_ms,
            overlay_ms,
            render_ms,
            draw_ms_total,
            self.debug.last_metal_terminal_fallback.special_sprite_glyphs,
            self.debug.last_metal_terminal_fallback.shaped_special_glyphs,
            self.debug.last_metal_terminal_fallback.powerline_special_glyphs,
            self.debug.last_metal_terminal_fallback.shade_special_glyphs,
            self.debug.last_metal_terminal_fallback.braille_special_glyphs,
            self.debug.last_metal_terminal_fallback.box_glyphs,
        );
    }

    const render_scale = 1.0 / r.devicePixelStep();
    const lifecycle_transition = self.surface.lifecycleTransition(terminal_view);
    const alt_exit = lifecycle_transition.exited;
    render_phase_start = app_shell.getTime();

    const render_state = terminal_view.render;
    const screen_reverse = render_state.screen_reverse;
    const blink_style = self.blink_style;
    const blink_time = app_shell.getTime();
    const rows = terminal_view.rows;
    const cols = terminal_view.cols;
    const view_geometry = shell.terminalViewGeometry(.{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    }, rows, cols);
    const draw_start_time = if (alt_exit) app_shell.getTime() else 0;
    const viewport = terminal_view.viewport;
    const history_len = viewport.history_len;
    const scroll_offset = viewport.scroll_offset;
    const start_line = viewport.start_line;
    var draw_cursor = render_state.draw_cursor_visible;
    const cursor = if (draw_cursor) terminal_view.cursor else CursorPos{ .row = rows + 1, .col = cols + 1 };
    const cursor_style = render_state.cursor_style;
    if (draw_cursor and self.controller.focus.isUiFocused() and cursor_style.blink) {
        if (blink_time >= self.controller.blink.cursorBlinkPauseUntil()) {
            const period: f64 = 0.5;
            const phase = @mod(blink_time, period * 2.0);
            draw_cursor = phase < period;
        }
    }
    const kitty_generation = terminal_view.kitty_generation;
    const has_blink = blink_style != .off and render_state.has_blinking_cells;
    const blink_phase_changed = self.controller.blink.takePhaseChangedPending();
    const blink_requires_partial = has_blink and blink_phase_changed;

    const has_kitty = self.surface.prepareKittyForDraw(
        self.session.allocator,
        shell,
        terminal_view,
    );
    self.debug.clearFrameSamples();

    self.controller.hover.dirty = false;
    const hover_link_id = hover_mod.hoverLinkId(&self.controller.hover);
    adoptAvailableTerminalGlyphPrepResult(r);
    stageVisibleTerminalGlyphPrepRequest(
        r,
        terminal_view,
        hover_link_id,
        screen_reverse,
        blink_style,
        blink_time,
        draw_cursor,
        cursor,
        cursor_style,
    );
    const surface_result = presentation_runtime.updateAndPresent(
        self,
        shell,
        x,
        y,
        width,
        height,
        input,
        terminal_view,
        view_geometry,
        hover_link_id,
        start_line,
        scroll_offset,
        draw_cursor,
        cursor,
        cursor_style,
        blink_style,
        blink_time,
        blink_requires_partial,
        has_kitty,
    );
    presentation_update_ms = surface_result.presentation_update_ms;
    presentation_bg_ms = surface_result.presentation_bg_ms;
    presentation_glyph_ms = surface_result.presentation_glyph_ms;
    presentation_kitty_ms = surface_result.presentation_kitty_ms;
    if (surface_result.early_return) return outcome;

    if (self.debug.samples_enabled) {
        self.debug.last_view_geometry = .{
            .valid = rows > 0 and cols > 0,
            .generation = terminal_view.generation,
            .base_x = view_geometry.origin_x,
            .base_y = view_geometry.origin_y,
            .viewport_w = view_geometry.viewport_width,
            .viewport_h = view_geometry.viewport_height,
            .rows = view_geometry.rows,
            .cols = view_geometry.cols,
            .ui_scale = shell.uiGeometryContext().ui_scale,
            .render_scale = render_scale,
            .cell_width_logical = view_geometry.cell_width,
            .cell_height_logical = view_geometry.cell_height,
            .cell_width_device = r.terminalCellGeometry().cell_width_device_px,
            .cell_height_device = r.terminalCellGeometry().cell_height_device_px,
            .baseline_logical = view_geometry.baseline_from_top,
        };
    }
    const overlay_phase_start = app_shell.getTime();
    self.surface.finishDraw(self.session.allocator, kitty_generation, has_kitty);
    drawOverlays(
        self,
        shell,
        view_geometry,
        input,
        cache,
        terminal_view.cells,
        screen_reverse,
        hover_link_id,
        draw_cursor,
        cursor,
        cursor_style,
        &self.debug.last_metal_terminal_fallback,
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

test "viewport present shift attempts only when fast path is eligible" {
    switch (planViewportPresentShift(true, true, 2, false, 0, false, true, 24)) {
        .attempt => |rows| try std.testing.expectEqual(@as(usize, 2), rows),
        else => return error.ExpectedShiftAttempt,
    }
}

test "viewport present shift disable falls back to standard damage path" {
    const plan = planViewportPresentShift(false, true, 2, false, 0, false, true, 24);
    try std.testing.expectEqual(ViewportPresentShiftPlan.none, plan);
}

test "viewport present shift oversize scroll falls back to standard damage path" {
    const plan = planViewportPresentShift(true, true, 24, false, 0, false, true, 24);
    try std.testing.expectEqual(ViewportPresentShiftPlan.none, plan);
}

test "viewport present shift does not attempt while already forced full" {
    const plan = planViewportPresentShift(true, true, 2, false, 0, true, true, 24);
    try std.testing.expectEqual(ViewportPresentShiftPlan.none, plan);
}

test "viewport present shift ignores scrollback view movement" {
    const plan = planViewportPresentShift(true, true, 2, false, 3, false, true, 24);
    try std.testing.expectEqual(ViewportPresentShiftPlan.none, plan);
}

test "viewport present shift allows explicit scrollback remap path" {
    switch (planViewportPresentShift(true, true, 2, true, 3, false, true, 24)) {
        .attempt => |rows| try std.testing.expectEqual(@as(usize, 2), rows),
        else => return error.ExpectedShiftAttempt,
    }
}

test "presentation update plan keeps partial redraws eligible while scrolled" {
    const plan = choosePresentationUpdatePlan(
        .partial,
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

test "presentation update plan forces full redraw when presentable is not ready" {
    const plan = choosePresentationUpdatePlan(
        .partial,
        false,
        false,
        false,
        false,
        false,
        false,
    );
    try std.testing.expect(plan.needs_full);
    try std.testing.expect(!plan.needs_partial);
}

test "presentation update plan stays idle when dirty state is clean" {
    const plan = choosePresentationUpdatePlan(
        .none,
        false,
        false,
        false,
        false,
        false,
        true,
    );
    try std.testing.expect(!plan.needs_full);
    try std.testing.expect(!plan.needs_partial);
}

test "presentation update plan keeps partial redraw for normal partial damage" {
    const plan = choosePresentationUpdatePlan(
        .partial,
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

test "presentation update plan uses partial redraw for blink-only changes" {
    const plan = choosePresentationUpdatePlan(
        .none,
        false,
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
    const max_spans = render_cache_mod.max_row_dirty_spans;
    var rows = [_]bool{ false, false, false };
    var span_counts = [_]u8{ 0, 0, 0 };
    var spans: [3][max_spans]render_cache_mod.RowDirtySpan = undefined;
    var cols_start = [_]u16{ 9, 9, 9 };
    var cols_end = [_]u16{ 0, 0, 0 };

    markAllRowsFullWidthPartialPlan(&rows, &span_counts, &spans, &cols_start, &cols_end, 3, 5);

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
const planViewportPresentShift = draw_presentation.planViewportPresentShift;
const ViewportPresentShiftPlan = draw_presentation.ViewportPresentShiftPlan;
const useViewportShiftForPartialPlan = draw_presentation.useViewportShiftForPartialPlan;
const choosePresentationUpdatePlan = draw_presentation.choosePresentationUpdatePlan;
const forceFullPresentationUpdatePlan = draw_presentation.forceFullPresentationUpdatePlan;
const forceFullPresentationUpdatePlanEveryFrame = draw_presentation.forceFullPresentationUpdatePlanEveryFrame;
const buildPartialPlan = draw_presentation.buildPartialPlan;
const markAllRowsFullWidthPartialPlan = draw_presentation.markAllRowsFullWidthPartialPlan;

test "useViewportShiftForPartialPlan ignores stale shift metadata on clean frames" {
    try std.testing.expect(!useViewportShiftForPartialPlan(.none, 1));
    try std.testing.expect(!useViewportShiftForPartialPlan(.full, 1));
    try std.testing.expect(useViewportShiftForPartialPlan(.partial, 1));
}

test "CZH-S15: presentation update plan full redraw when pipeline leg blocks partial" {
    const plan = choosePresentationUpdatePlan(
        .partial,
        false,
        false,
        false,
        false,
        false,
        false,
    );
    try std.testing.expect(plan.needs_full);
    try std.testing.expect(!surface_attachment_contract.hostSharedSurfaceAttachmentReady(true, false));
}
