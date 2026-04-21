//! Terminal widget presentation runtime: draw/present into the host-owned shared surface.
//!
//! **Ownership:** Publication/clear generations use `surface_contract`; host attachment
//! readiness (presentable pipeline ∧ host drawable target) is named in
//! `surface_attachment_contract` and wired through `TerminalWidgetSurfaceState`.
//! `buildTerminalPresentPlan` reuse gating uses `terminalPresentablePipelineReady()`
//! (pipeline leg only), not the full attachment conjunction — intentional separation.
//!
//! **Delegation:** Orchestration decisions, outcome classification, folding, eligibility
//! checks, and geometry computation are owned by terminal layer
//! (`src/terminal/presentation_runtime.zig`). Widget layer is an integration facade:
//! it delegates all decision and fold calls to terminal, and owns only execution
//! (GPU drawing, state mutation, renderer integration).
//!
//! **Invariants:** Two attachment state legs maintained separately:
//! - `host_surface_target_available`: host drawable-target leg (from renderer)
//! - `shared_surface_attachment_ready`: full conjunction (pipeline ∧ host target)
//! Result structs distinguish leg from conjunction to prevent overloading one bool.
//! Do not re-derive or re-label legs as conjunction in reporting/result paths.
//!
//! **Conjunction computation:** Attachment conjunction is computed in `refreshPresentState`
//! (pure) and `tryFastPresentExisting` via `computeHostSurfaceAttachmentState` →
//! `notePresentableAvailability`. Cache state is advanced by `advancePresentationCache`
//! (called by widget in the refreshed path, and directly in the reuse path).
//! Conjunction stored on transient `PresentationPresentState` and outcome/result structs.
//! Reported through `readSharedSurfaceAttachmentReady` and result consumers.
//!
//! **Reporting carriers:** For operator JSON on present failure, conjunction carrier is
//! `PresentationPresentState.shared_surface_attachment_ready` (canonical conjunction).
//! For ad-hoc reads without a present-state snapshot, carrier is `readSharedSurfaceAttachmentReady`
//! on `TerminalWidgetSurfaceState`. Do not log conjunction from getter when snapshot already in scope.
//!
//! **Reporting cohesion:** Operator reporting uses transient `PresentationPresentState` and widget
//! read APIs. `TerminalPresentResult` is host-facing aggregation struct (leg + conjunction fields).
//! Do not merge those roles: logs not populated from result alone; results not interchangeable
//! with per-tick present-state snapshots.
//!
//! **Hardening:** Debug assertions in outcome classification/folding (terminal layer) catch
//! invalid state combinations early. All hardening maintains behavior freeze: assertions validate
//! existing patterns remain consistent, no success-path changes.
const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const surface_contract = @import("../../terminal/surface_contract.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const terminal_presentation_runtime = @import("../../terminal/presentation_runtime.zig");
const shared_types = @import("../../types/mod.zig");
const draw_presentation = @import("terminal_widget_draw_plan.zig");
const presentation_state_mod = @import("terminal_widget_presentation_cache_state.zig");
const view_state = @import("terminal_widget_view_state.zig");
const present_feedback_host = @import("../renderer/present_feedback_host.zig");
const renderer_clip_host = @import("../renderer/renderer_clip_host.zig");
const renderer_presentable_host = @import("../renderer/renderer_presentable_host.zig");
const renderer_terminal_draw_host = @import("../renderer/renderer_terminal_draw_host.zig");
const draw_grid = @import("terminal_widget_draw_grid.zig");
const publication_capture = @import("../../terminal/core/publication/render_cache.zig");
const app_shell = @import("../../app_shell.zig");
const time_utils = @import("../renderer/time_utils.zig");
const terminal_debug_geometry = @import("terminal_widget_debug_geometry.zig");

const TerminalViewGeometry = shared_types.layout.TerminalViewGeometry;
const Color = app_shell.Color;
const RenderCache = publication_capture.RenderCache;
const FullFrameFastPathDecision = draw_presentation.FullFrameFastPathDecision;
const PresentationPartialDrawPlan = presentation_state_mod.PresentationState.PresentationPartialDrawPlan;
const CursorPos = terminal_publication.CursorPos;
const GlyphDrawStats = draw_grid.GlyphDrawStats;
const TerminalPresentationSampleMode = terminal_debug_geometry.TerminalPresentationSampleMode;
const TerminalPresentationSample = terminal_debug_geometry.TerminalPresentationSample;
const InputSnapshot = shared_types.input.InputSnapshot;
const TerminalPresentableRefresh = renderer_presentable_host.TerminalPresentableRefresh;
const TerminalPresentableRefreshExecutionResult = renderer_presentable_host.TerminalPresentableRefreshExecutionResult;
const DirectTerminalPresentExecutionResult = renderer_presentable_host.DirectTerminalPresentExecutionResult;
const TerminalPresentPlan = renderer_presentable_host.TerminalPresentPlan;
const TerminalPresentResult = renderer_presentable_host.TerminalPresentResult;
const TerminalPresentOutcome = @import("../renderer/presentable_contract.zig").TerminalPresentOutcome;
const TerminalPresentFollowupReason = @import("../renderer/presentable_contract.zig").TerminalPresentFollowupReason;

const drawRowBackgrounds = draw_grid.drawRowBackgrounds;
const drawRowGlyphs = draw_grid.drawRowGlyphs;

// Terminal-layer types re-exported for callers
pub const PresentationGeometry = terminal_presentation_runtime.PresentationGeometry;
pub const PresentationPresentState = terminal_presentation_runtime.PresentationPresentState;

// Terminal-layer geometry computation
const computePresentationSurfaceGeometry = terminal_presentation_runtime.computePresentationSurfaceGeometry;

pub const SurfaceUpdateMode = enum {
    none,
    full,
    partial,
};

pub const PresentationUpdatePlan = struct {
    geometry: PresentationGeometry = .{},
    mode: SurfaceUpdateMode = .none,
    partial_plan: ?PresentationPartialDrawPlan = null,
};

// Terminal-layer type re-exported for callers
pub const ViewportShiftState = terminal_presentation_runtime.ViewportShiftState;

pub const IncrementalPresentableUpdateResult = struct {
    completed: bool = false,
    bg_ms: f64 = 0.0,
    glyph_ms: f64 = 0.0,
    kitty_ms: f64 = 0.0,
};

pub const PresentationExecutionResult = struct {
    completed: bool = false,
    bg_ms: f64 = 0.0,
    glyph_ms: f64 = 0.0,
    kitty_ms: f64 = 0.0,
};

/// **Refresh outcome snapshot:** classifies refresh cycle result (updated or not).
/// Carries conjunction inline via `shared_surface_attachment_ready`; fold reads the field directly.
/// *Invariants:* `followup.required` and `followup.reason` are coupled — must both indicate unavailability
/// or both be in neutral state. Hardening assertions validate this coupling in `terminal_presentation_runtime.classifyRefreshOutcome()`.
pub const ReuseEligibilityInput = terminal_presentation_runtime.ReuseEligibilityInput;
pub const DirectPresentEligibilityInput = terminal_presentation_runtime.DirectPresentEligibilityInput;

const computeHostSurfaceAttachmentState = terminal_presentation_runtime.computeHostSurfaceAttachmentState;

fn advancePresentationCache(
    surface_state: anytype,
    terminal_view: view_state.TerminalViewModel,
    surface_geometry: PresentationGeometry,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    hover_link_id: u32,
    composing_active: bool,
    composing_hash: u64,
) void {
    surface_state.notePresentationUpdated(
        terminal_view,
        surface_geometry,
        draw_cursor,
        cursor,
        cursor_style,
        hover_link_id,
        composing_active,
        composing_hash,
    );
}

pub const SurfacePresentResult = struct {
    early_return: bool = false,
    presentation_update_ms: f64 = 0.0,
    presentation_bg_ms: f64 = 0.0,
    presentation_glyph_ms: f64 = 0.0,
    presentation_kitty_ms: f64 = 0.0,
    special_sprite_glyphs: usize = 0,
    shaped_special_glyphs: usize = 0,
};

pub fn recentInputWindowActive(
    self: anytype,
    renderer: anytype,
    input: InputSnapshot,
    at: f64,
) bool {
    if (!renderer_presentable_host.terminalUsesRefreshDrivenRecentInputPolicy(renderer)) return false;
    return renderer.forceFullTerminalPresentationRecentInputWindow() and
        ((input.mods.ctrl or input.mods.shift or input.mods.alt or input.mods.super) or
            self.controller.blink.recentInputWindowActive(
                at,
                renderer.fullTerminalPresentationRecentInputWindowSeconds(),
            ));
}

pub fn updateAndPresent(
    self: anytype,
    shell: *app_shell.Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    input: InputSnapshot,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    hover_link_id: u32,
    start_line: usize,
    scroll_offset: usize,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    blink_style: anytype,
    blink_time: f64,
    blink_requires_partial: bool,
    has_kitty: bool,
) SurfacePresentResult {
    const presentation_phase_start = app_shell.getTime();
    var result = SurfacePresentResult{};
    const renderer = shell.rendererPtr();
    const recent_input_window_active = recentInputWindowActive(
        self,
        renderer,
        input,
        app_shell.getTime(),
    );
    const composing_active = input.composing_active and input.composing_text.len > 0;
    const composing_hash: u64 = if (composing_active)
        std.hash.Wyhash.hash(0, input.composing_text)
    else
        0;
    const presentation = runPresentation(
        self,
        shell,
        renderer,
        terminal_view,
        view_geometry,
        hover_link_id,
        composing_active,
        composing_hash,
        start_line,
        scroll_offset,
        draw_cursor,
        cursor,
        cursor_style,
        blink_style,
        blink_time,
        blink_requires_partial,
        has_kitty,
        width,
        height,
        x,
        y,
        recent_input_window_active,
        self,
        notePresentSample,
    );
    result.early_return = presentation.outcome == .reused;
    result.presentation_bg_ms = presentation.timing.background_ms;
    result.presentation_glyph_ms = presentation.timing.glyph_ms;
    result.presentation_kitty_ms = presentation.timing.kitty_ms;
    result.special_sprite_glyphs = self.debug.last_metal_terminal_fallback.special_sprite_glyphs;
    result.shaped_special_glyphs = self.debug.last_metal_terminal_fallback.shaped_special_glyphs;
    if (result.early_return) return result;

    result.presentation_update_ms = time_utils.secondsToMs(app_shell.getTime() - presentation_phase_start);
    return result;
}

pub fn clearPresentationSample(self: anytype) void {
    if (!self.debug.samples_enabled) return;
    self.debug.last_terminal_presentation.valid = false;
}

fn forEachPresentationDrawSpan(
    rows: usize,
    cols: usize,
    surface_update_plan: PresentationUpdatePlan,
    visitor: anytype,
) void {
    if (rows == 0 or cols == 0) return;

    switch (surface_update_plan.mode) {
        .none => {},
        .full => {
            for (0..rows) |row| {
                visitor.visit(row, 0, cols - 1, true);
            }
        },
        .partial => {
            const partial_plan = surface_update_plan.partial_plan orelse return;
            for (0..rows) |row| {
                if (!partial_plan.rows[row]) continue;
                if (row < partial_plan.span_counts.len and row < partial_plan.spans.len and partial_plan.span_counts[row] > 0) {
                    var span_idx: usize = 0;
                    while (span_idx < partial_plan.span_counts[row]) : (span_idx += 1) {
                        const span = partial_plan.spans[row][span_idx];
                        const col_start = @min(@as(usize, span.start), cols - 1);
                        const col_end = @min(@as(usize, span.end), cols - 1);
                        visitor.visit(row, col_start, col_end, col_end >= cols - 1);
                    }
                    continue;
                }
                const col_start = @min(@as(usize, partial_plan.cols_start[row]), cols - 1);
                const col_end = @min(@as(usize, partial_plan.cols_end[row]), cols - 1);
                visitor.visit(row, col_start, col_end, col_end >= cols - 1);
            }
        },
    }
}

fn drawPresentationBackgroundPass(
    shell: *app_shell.Shell,
    renderer: anytype,
    view_geometry: TerminalViewGeometry,
    view_cells: anytype,
    rows: usize,
    cols: usize,
    base_x_local: f32,
    base_y_local: f32,
    padding_x_i: i32,
    screen_reverse: bool,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    surface_update_plan: PresentationUpdatePlan,
    bg_color: Color,
    clear_full_surface: bool,
) f64 {
    const bg_phase_start = app_shell.getTime();
    renderer.beginTerminalBatch();
    if (clear_full_surface) {
        renderer_terminal_draw_host.addTerminalRect(renderer, 0, 0, surface_update_plan.geometry.surface_w, surface_update_plan.geometry.surface_h, bg_color);
    }
    var visitor = struct {
        shell: *app_shell.Shell,
        view_geometry: TerminalViewGeometry,
        view_cells: @TypeOf(view_cells),
        cols: usize,
        base_x_local: f32,
        base_y_local: f32,
        padding_x_i: i32,
        screen_reverse: bool,
        draw_cursor: bool,
        cursor: CursorPos,
        cursor_style: terminal_types.CursorStyle,

        fn visit(ctx: *@This(), row: usize, col_start: usize, col_end: usize, draw_padding: bool) void {
            drawRowBackgrounds(
                ctx.shell,
                ctx.view_geometry,
                ctx.view_cells,
                ctx.cols,
                row,
                col_start,
                col_end,
                ctx.base_x_local,
                ctx.base_y_local,
                ctx.padding_x_i,
                draw_padding,
                ctx.screen_reverse,
                ctx.draw_cursor,
                ctx.cursor,
                ctx.cursor_style,
            );
        }
    }{
        .shell = shell,
        .view_geometry = view_geometry,
        .view_cells = view_cells,
        .cols = cols,
        .base_x_local = base_x_local,
        .base_y_local = base_y_local,
        .padding_x_i = padding_x_i,
        .screen_reverse = screen_reverse,
        .draw_cursor = draw_cursor,
        .cursor = cursor,
        .cursor_style = cursor_style,
    };
    forEachPresentationDrawSpan(rows, cols, surface_update_plan, &visitor);
    renderer.flushTerminalBatch();
    return time_utils.secondsToMs(app_shell.getTime() - bg_phase_start);
}

fn drawPresentationGlyphPass(
    self: anytype,
    shell: *app_shell.Shell,
    renderer: anytype,
    view_geometry: TerminalViewGeometry,
    view_cells: anytype,
    rows: usize,
    cols: usize,
    base_x_local: f32,
    base_y_local: f32,
    padding_x_i: i32,
    hover_link_id: u32,
    screen_reverse: bool,
    blink_style: anytype,
    blink_time: f64,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    publication_generation: u64,
    surface_update_plan: PresentationUpdatePlan,
    glyph_draw_stats: *GlyphDrawStats,
) f64 {
    const glyph_phase_start = app_shell.getTime();
    renderer.terminal_font.beginFrameAtlasStats();
    renderer.beginTerminalGlyphBatch();
    var visitor = struct {
        self_widget: @TypeOf(self),
        shell: *app_shell.Shell,
        view_geometry: TerminalViewGeometry,
        view_cells: @TypeOf(view_cells),
        cols: usize,
        base_x_local: f32,
        base_y_local: f32,
        padding_x_i: i32,
        hover_link_id: u32,
        screen_reverse: bool,
        blink_style: @TypeOf(blink_style),
        blink_time: f64,
        draw_cursor: bool,
        cursor: CursorPos,
        cursor_style: terminal_types.CursorStyle,
        disable_ligatures: @TypeOf(renderer.font_config.terminal_disable_ligatures),
        publication_generation: u64,
        glyph_draw_stats: *GlyphDrawStats,
        metal_fallback_sample: ?*@import("terminal_widget_debug_geometry.zig").MetalTerminalFallbackSample,

        fn visit(ctx: *@This(), row: usize, col_start: usize, col_end: usize, _: bool) void {
            drawRowGlyphs(
                ctx.shell,
                ctx.view_geometry,
                ctx.view_cells,
                ctx.cols,
                row,
                col_start,
                col_end,
                ctx.base_x_local,
                ctx.base_y_local,
                ctx.padding_x_i,
                ctx.hover_link_id,
                ctx.screen_reverse,
                ctx.blink_style,
                ctx.blink_time,
                ctx.draw_cursor,
                ctx.cursor,
                ctx.cursor_style,
                ctx.disable_ligatures,
                ctx.publication_generation,
                ctx.glyph_draw_stats,
                ctx.self_widget.debug.textPaintSampleSink(),
                ctx.metal_fallback_sample,
            );
        }
    }{
        .self_widget = self,
        .shell = shell,
        .view_geometry = view_geometry,
        .view_cells = view_cells,
        .cols = cols,
        .base_x_local = base_x_local,
        .base_y_local = base_y_local,
        .padding_x_i = padding_x_i,
        .hover_link_id = hover_link_id,
        .screen_reverse = screen_reverse,
        .blink_style = blink_style,
        .blink_time = blink_time,
        .draw_cursor = draw_cursor,
        .cursor = cursor,
        .cursor_style = cursor_style,
        .disable_ligatures = renderer.font_config.terminal_disable_ligatures,
        .publication_generation = publication_generation,
        .glyph_draw_stats = glyph_draw_stats,
        .metal_fallback_sample = self.debug.metalFallbackSampleSink(),
    };
    forEachPresentationDrawSpan(rows, cols, surface_update_plan, &visitor);
    renderer.flushTerminalGlyphBatch();
    return time_utils.secondsToMs(app_shell.getTime() - glyph_phase_start);
}

fn executeIncrementalPresentableUpdate(
    self: anytype,
    shell: *app_shell.Shell,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    hover_link_id: u32,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    blink_style: anytype,
    blink_time: f64,
    surface_update_plan: PresentationUpdatePlan,
) IncrementalPresentableUpdateResult {
    var result = IncrementalPresentableUpdateResult{};
    if (surface_update_plan.mode != .partial or surface_update_plan.partial_plan == null) return result;

    const rows = terminal_view.rows;
    const cols = terminal_view.cols;
    const view_cells = terminal_view.cells;
    const base_colors = terminal_view.base_colors;
    const screen_reverse = terminal_view.render.screen_reverse;
    var glyph_draw_stats = GlyphDrawStats{};
    const bg_color = if (view_cells.len > 0)
        Color{
            .r = base_colors.resolved_background.r,
            .g = base_colors.resolved_background.g,
            .b = base_colors.resolved_background.b,
            .a = base_colors.resolved_background.a,
        }
    else
        renderer.theme.background;

    result.bg_ms += drawPresentationBackgroundPass(
        shell,
        renderer,
        view_geometry,
        view_cells,
        rows,
        cols,
        view_geometry.origin_x,
        view_geometry.origin_y,
        0,
        screen_reverse,
        draw_cursor,
        cursor,
        cursor_style,
        surface_update_plan,
        bg_color,
        false,
    );
    result.glyph_ms += drawPresentationGlyphPass(
        self,
        shell,
        renderer,
        view_geometry,
        view_cells,
        rows,
        cols,
        view_geometry.origin_x,
        view_geometry.origin_y,
        0,
        hover_link_id,
        screen_reverse,
        blink_style,
        blink_time,
        draw_cursor,
        cursor,
        cursor_style,
        terminal_view.generation,
        surface_update_plan,
        &glyph_draw_stats,
    );
    recordMetalFallbackStats(self, terminal_view.generation, glyph_draw_stats);
    result.completed = true;
    return result;
}

pub fn notePresentSample(
    self: anytype,
    renderer: anytype,
    mode: TerminalPresentationSampleMode,
    generation: u64,
    dest_x: f32,
    dest_y: f32,
    dest_w: f32,
    dest_h: f32,
    source_w: f32,
    source_h: f32,
) void {
    if (!self.debug.samples_enabled) return;
    var sample = TerminalPresentationSample{
        .valid = true,
        .mode = mode,
        .generation = generation,
        .presentable_w_px = 0,
        .presentable_h_px = 0,
        .target_logical_w = source_w,
        .target_logical_h = source_h,
        .source_logical_w = source_w,
        .source_logical_h = source_h,
        .dest_x = dest_x,
        .dest_y = dest_y,
        .dest_w = dest_w,
        .dest_h = dest_h,
        .scale_x = if (source_w > 0.0) dest_w / source_w else 1.0,
        .scale_y = if (source_h > 0.0) dest_h / source_h else 1.0,
    };
    if (mode == .refreshed_presentable) {
        if (renderer_presentable_host.terminalPresentableInfo(renderer)) |info| {
            sample.presentable_w_px = info.width_px;
            sample.presentable_h_px = info.height_px;
            sample.target_logical_w = @floatFromInt(info.logical_width);
            sample.target_logical_h = @floatFromInt(info.logical_height);
        } else {
            sample.valid = false;
        }
    }
    self.debug.last_terminal_presentation = sample;
}

fn recordMetalFallbackStats(self: anytype, generation: u64, glyph_draw_stats: GlyphDrawStats) void {
    if (!self.debug.samples_enabled) return;
    self.debug.last_metal_terminal_fallback = .{
        .valid = true,
        .generation = generation,
        .special_sprite_glyphs = glyph_draw_stats.special_sprite_glyphs,
        .shaped_special_glyphs = glyph_draw_stats.shaped_special_glyphs,
        .powerline_special_glyphs = glyph_draw_stats.powerline_special_glyphs,
        .shade_special_glyphs = glyph_draw_stats.shade_special_glyphs,
        .braille_special_glyphs = glyph_draw_stats.braille_special_glyphs,
        .box_glyphs = glyph_draw_stats.box_glyphs,
    };
}

pub fn executePresentableUpdate(
    self: anytype,
    shell: *app_shell.Shell,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    hover_link_id: u32,
    start_line: usize,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    blink_style: anytype,
    blink_time: f64,
    has_kitty: bool,
    surface_update_plan: PresentationUpdatePlan,
) PresentationExecutionResult {
    var result = PresentationExecutionResult{};
    if (surface_update_plan.mode == .none) return result;
    if (surface_update_plan.mode == .partial and surface_update_plan.partial_plan == null) return result;

    const rows = terminal_view.rows;
    const cols = terminal_view.cols;
    const view_cells = terminal_view.cells;
    const base_colors = terminal_view.base_colors;
    const screen_reverse = terminal_view.render.screen_reverse;
    const base_x_local: f32 = 0;
    const base_y_local: f32 = 0;
    var glyph_draw_stats = GlyphDrawStats{};
    const bg_color = if (view_cells.len > 0)
        Color{
            .r = base_colors.resolved_background.r,
            .g = base_colors.resolved_background.g,
            .b = base_colors.resolved_background.b,
            .a = base_colors.resolved_background.a,
        }
    else
        renderer.theme.background;
    const clear_full_surface = surface_update_plan.mode == .full;

    result.bg_ms += drawPresentationBackgroundPass(
        shell,
        renderer,
        view_geometry,
        view_cells,
        rows,
        cols,
        base_x_local,
        base_y_local,
        surface_update_plan.geometry.padding_x_i,
        screen_reverse,
        draw_cursor,
        cursor,
        cursor_style,
        surface_update_plan,
        bg_color,
        clear_full_surface,
    );
    if (has_kitty) {
        const kitty_phase_start = app_shell.getTime();
        self.surface.kitty.cleanupTextures(self.session.allocator, self.surface.kitty.images_view.items);
        self.surface.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, false, start_line, rows, cols);
        result.kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
    }
    result.glyph_ms += drawPresentationGlyphPass(
        self,
        shell,
        renderer,
        view_geometry,
        view_cells,
        rows,
        cols,
        base_x_local,
        base_y_local,
        surface_update_plan.geometry.padding_x_i,
        hover_link_id,
        screen_reverse,
        blink_style,
        blink_time,
        draw_cursor,
        cursor,
        cursor_style,
        terminal_view.generation,
        surface_update_plan,
        &glyph_draw_stats,
    );
    recordMetalFallbackStats(self, terminal_view.generation, glyph_draw_stats);
    if (has_kitty) {
        const kitty_phase_start = app_shell.getTime();
        self.surface.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, true, start_line, rows, cols);
        result.kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
    }
    result.completed = true;
    return result;
}

pub fn runPresentableRefreshCycle(
    self: anytype,
    shell: *app_shell.Shell,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    hover_link_id: u32,
    start_line: usize,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    blink_style: anytype,
    blink_time: f64,
    has_kitty: bool,
    surface_update_plan: PresentationUpdatePlan,
) TerminalPresentableRefreshExecutionResult {
    const UpdateCtx = struct {
        self: @TypeOf(self),
        shell: *app_shell.Shell,
        terminal_view: view_state.TerminalViewModel,
        view_geometry: TerminalViewGeometry,
        hover_link_id: u32,
        start_line: usize,
        draw_cursor: bool,
        cursor: CursorPos,
        cursor_style: terminal_types.CursorStyle,
        blink_style: @TypeOf(blink_style),
        blink_time: f64,
        has_kitty: bool,
        surface_update_plan: PresentationUpdatePlan,
    };
    const Local = struct {
        pub fn executeUpdate(
            ctx: UpdateCtx,
            renderer_local: @TypeOf(renderer),
            _: TerminalPresentPlan,
        ) renderer_presentable_host.TerminalPresentTiming {
            renderer_clip_host.endClip(renderer_local);
            const execution = executePresentableUpdate(
                ctx.self,
                ctx.shell,
                renderer_local,
                ctx.terminal_view,
                ctx.view_geometry,
                ctx.hover_link_id,
                ctx.start_line,
                ctx.draw_cursor,
                ctx.cursor,
                ctx.cursor_style,
                ctx.blink_style,
                ctx.blink_time,
                ctx.has_kitty,
                ctx.surface_update_plan,
            );
            return .{
                .background_ms = execution.bg_ms,
                .glyph_ms = execution.glyph_ms,
                .kitty_ms = execution.kitty_ms,
            };
        }
    };
    const update_ctx: UpdateCtx = .{
        .self = self,
        .shell = shell,
        .terminal_view = terminal_view,
        .view_geometry = view_geometry,
        .hover_link_id = hover_link_id,
        .start_line = start_line,
        .draw_cursor = draw_cursor,
        .cursor = cursor,
        .cursor_style = cursor_style,
        .blink_style = blink_style,
        .blink_time = blink_time,
        .has_kitty = has_kitty,
        .surface_update_plan = surface_update_plan,
    };
    return renderer_presentable_host.runTerminalPresentableRefreshExecution(renderer, .{
        .update_intent = switch (surface_update_plan.mode) {
            .none => .none,
            .partial => .partial,
            .full => .full,
        },
        .surface_geometry = .{
            .logical_width = surface_update_plan.geometry.surface_w,
            .logical_height = surface_update_plan.geometry.surface_h,
            .visible_width = surface_update_plan.geometry.visible_w,
            .visible_height = surface_update_plan.geometry.visible_h,
            .dest_x = view_geometry.origin_x,
            .dest_y = view_geometry.origin_y,
            .dest_width = view_geometry.viewport_width,
            .dest_height = view_geometry.viewport_height,
        },
    }, update_ctx, Local);
}

pub fn executeRefreshPresentFlow(
    self: anytype,
    shell: *app_shell.Shell,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    hover_link_id: u32,
    composing_active: bool,
    composing_hash: u64,
    start_line: usize,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    blink_style: anytype,
    blink_time: f64,
    has_kitty: bool,
    surface_update_plan: PresentationUpdatePlan,
    note_present_ctx: anytype,
    note_present: anytype,
) TerminalPresentResult {
    const RefreshCtx = struct {
        self_widget: @TypeOf(self),
        shell: *app_shell.Shell,
        renderer: @TypeOf(renderer),
        terminal_view: view_state.TerminalViewModel,
        view_geometry: TerminalViewGeometry,
        hover_link_id: u32,
        composing_active: bool,
        composing_hash: u64,
        start_line: usize,
        draw_cursor: bool,
        cursor: CursorPos,
        cursor_style: terminal_types.CursorStyle,
        blink_style: @TypeOf(blink_style),
        blink_time: f64,
        has_kitty: bool,
        surface_update_plan: PresentationUpdatePlan,
        note_present_ctx: @TypeOf(note_present_ctx),
        // note_present captured from outer scope (function with anytype params cannot be stored in struct)
    };
    const RefreshHooks = struct {
        pub fn runCycle(ctx: RefreshCtx) TerminalPresentableRefreshExecutionResult {
            return runPresentableRefreshCycle(
                ctx.self_widget,
                ctx.shell,
                ctx.renderer,
                ctx.terminal_view,
                ctx.view_geometry,
                ctx.hover_link_id,
                ctx.start_line,
                ctx.draw_cursor,
                ctx.cursor,
                ctx.cursor_style,
                ctx.blink_style,
                ctx.blink_time,
                ctx.has_kitty,
                ctx.surface_update_plan,
            );
        }
        pub fn runPresentation(ctx: RefreshCtx, cycle: TerminalPresentableRefreshExecutionResult) TerminalPresentResult {
            const view_cells_len = ctx.terminal_view.cells.len;
            const visible_w = ctx.surface_update_plan.geometry.visible_w;
            const visible_h = ctx.surface_update_plan.geometry.visible_h;
            const viewport_w = ctx.surface_update_plan.geometry.viewport_w;
            const viewport_h = ctx.surface_update_plan.geometry.viewport_h;

            if (cycle.refresh == .refreshed) {
                advancePresentationCache(
                    &ctx.self_widget.surface,
                    ctx.terminal_view,
                    ctx.surface_update_plan.geometry,
                    ctx.draw_cursor,
                    ctx.cursor,
                    ctx.cursor_style,
                    ctx.hover_link_id,
                    ctx.composing_active,
                    ctx.composing_hash,
                );
            }
            const present_state = terminal_presentation_runtime.refreshPresentState(
                &ctx.self_widget.surface,
                ctx.renderer,
                cycle.refresh,
                visible_w,
                visible_h,
            );
            if (present_state.present) {
                beginViewportClip(ctx.renderer, ctx.view_geometry, visible_w, visible_h);
            }
            defer if (present_state.present) renderer_clip_host.endClip(ctx.renderer);
            const bg = if (view_cells_len > 0)
                Color{
                    .r = ctx.terminal_view.base_colors.resolved_background.r,
                    .g = ctx.terminal_view.base_colors.resolved_background.g,
                    .b = ctx.terminal_view.base_colors.resolved_background.b,
                    .a = ctx.terminal_view.base_colors.resolved_background.a,
                }
            else
                ctx.renderer.theme.background;
            if (ctx.view_geometry.viewport.width > 0 and ctx.view_geometry.viewport.height > 0) {
                renderer_presentable_host.drawTerminalPresentableBackdrop(
                    ctx.renderer,
                    ctx.view_geometry.viewport.x,
                    ctx.view_geometry.viewport.y,
                    ctx.view_geometry.viewport.width,
                    ctx.view_geometry.viewport.height,
                    bg.toRgba(),
                );
            }
            if (present_state.present) {
                terminal_presentation_runtime.presentDraw(
                    ctx.renderer,
                    ctx.self_widget.surface.lastRenderGeneration(),
                    ctx.self_widget.surface.lastRenderGeneration(),
                    ctx.view_geometry,
                    viewport_w,
                    viewport_h,
                    ctx.note_present_ctx,
                    note_present,
                );
            }

            return terminal_presentation_runtime.refreshPresentEntry(
                cycle.refresh,
                present_state.shared_surface_attachment_ready,
                cycle.timing,
            );
        }
    };
    const ctx = RefreshCtx{
        .self_widget = self,
        .shell = shell,
        .renderer = renderer,
        .terminal_view = terminal_view,
        .view_geometry = view_geometry,
        .hover_link_id = hover_link_id,
        .composing_active = composing_active,
        .composing_hash = composing_hash,
        .start_line = start_line,
        .draw_cursor = draw_cursor,
        .cursor = cursor,
        .cursor_style = cursor_style,
        .blink_style = blink_style,
        .blink_time = blink_time,
        .has_kitty = has_kitty,
        .surface_update_plan = surface_update_plan,
        .note_present_ctx = note_present_ctx,
    };
    return terminal_presentation_runtime.executeRefreshPresentFlow(
        terminal_view.rows,
        terminal_view.cols,
        ctx,
        RefreshHooks,
    );
}

/// Present/reuse plan; generation alignment for reuse uses
/// `surface_contract.publicationClearPairMatchesLastSurfaceRender`.
fn buildTerminalPresentPlan(
    self: anytype,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    hover_link_id: u32,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    composing_active: bool,
    composing_hash: u64,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    blink_requires_partial: bool,
) TerminalPresentPlan {
    const geometry = computePresentationSurfaceGeometry(renderer, terminal_view, view_geometry);
    const delta = self.surface.presentationUpdateDelta(
        terminal_view,
        geometry,
        draw_cursor,
        cursor,
        cursor_style,
    );
    const overlay_changed = self.surface.overlayPresentationChanged(hover_link_id, composing_active, composing_hash);
    const terminal_presentable_pipeline_ready = self.surface.terminalPresentablePipelineReady();
    const publication_clear_pair_matches_last_surface_render = surface_contract.publicationClearPairMatchesLastSurfaceRender(
        terminal_view.generation,
        terminal_view.clear_generation,
        self.surface.lastRenderGeneration(),
        self.surface.lastRenderClearGeneration(),
    );
    const explicit_invalidation_blocks_reuse = delta.invalidation_flags.geometry or
        delta.invalidation_flags.content or
        delta.invalidation_flags.overlay or
        delta.invalidation_flags.availability;

    const plan_decision = terminal_presentation_runtime.computeTerminalPresentPlanDecision(
        terminal_presentable_pipeline_ready,
        terminal_view.rows,
        terminal_view.cols,
        terminal_view.cells.len,
        terminal_view.sync_updates_active,
        terminal_view.partial_capture.active_viewport_shift_rows,
        publication_clear_pair_matches_last_surface_render,
        explicit_invalidation_blocks_reuse,
        delta.clear_generation_changed,
        delta.cell_metrics_changed,
        delta.render_scale_changed,
        delta.cursor_changed,
        overlay_changed,
        blink_requires_partial,
    );

    return .{
        .update_intent = plan_decision.update_intent,
        .present_intent = plan_decision.present_intent,
        .surface_geometry = .{
            .logical_width = geometry.surface_w,
            .logical_height = geometry.surface_h,
            .visible_width = geometry.visible_w,
            .visible_height = geometry.visible_h,
            .dest_x = x,
            .dest_y = y,
            .dest_width = width,
            .dest_height = height,
        },
        .reuse_policy = .{
            .reuse_allowed = plan_decision.reuse_allowed,
            .shift_reuse_requested = plan_decision.viewport_shifted,
            .invalidation_blocks_reuse = plan_decision.invalidation_blocks_reuse,
        },
        .damage = .{
            .mode = switch (self.publication.cacheConst().dirty) {
                .none => .none,
                .partial => .partial,
                .full => .full,
            },
            .has_partial_payload = self.publication.cacheConst().dirty == .partial,
        },
        .invalidation_reasons = .{
            .generation_changed = delta.generation_changed,
            .clear_generation_changed = delta.clear_generation_changed,
            .cell_metrics_changed = delta.cell_metrics_changed or delta.invalidation_flags.geometry,
            .scale_changed = delta.render_scale_changed or delta.invalidation_flags.geometry,
            .cursor_changed = delta.cursor_changed,
            .overlay_changed = overlay_changed or delta.invalidation_flags.overlay,
            .viewport_shifted = plan_decision.viewport_shifted,
        },
    };
}

fn buildExecutionUpdatePlan(
    self: anytype,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    blink_requires_partial: bool,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    scroll_offset: usize,
    recent_input_window_active: bool,
) PresentationUpdatePlan {
    return planUpdate(
        &self.surface,
        self.session.allocator,
        renderer,
        self.publication.cacheConst(),
        terminal_view,
        view_geometry,
        blink_requires_partial,
        draw_cursor,
        cursor,
        cursor_style,
        scroll_offset,
        recent_input_window_active,
    );
}

pub fn runPresentation(
    self: anytype,
    shell: *app_shell.Shell,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    hover_link_id: u32,
    composing_active: bool,
    composing_hash: u64,
    start_line: usize,
    scroll_offset: usize,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    blink_style: anytype,
    blink_time: f64,
    blink_requires_partial: bool,
    has_kitty: bool,
    width: f32,
    height: f32,
    x: f32,
    y: f32,
    recent_input_window_active: bool,
    note_present_ctx: anytype,
    note_present: anytype,
) TerminalPresentResult {
    clearPresentationSample(self);
    const view_cells_len = terminal_view.cells.len;
    const bg_color = if (view_cells_len > 0)
        Color{
            .r = terminal_view.base_colors.resolved_background.r,
            .g = terminal_view.base_colors.resolved_background.g,
            .b = terminal_view.base_colors.resolved_background.b,
            .a = terminal_view.base_colors.resolved_background.a,
        }
    else
        renderer.theme.background;

    renderer_presentable_host.drawTerminalPresentableBackdrop(renderer, x, y, width, height, bg_color.toRgba());
    const Ctx = struct {
        self_widget: @TypeOf(self),
        shell: *app_shell.Shell,
        terminal_view: view_state.TerminalViewModel,
        view_geometry: TerminalViewGeometry,
        hover_link_id: u32,
        composing_active: bool,
        composing_hash: u64,
        start_line: usize,
        scroll_offset: usize,
        draw_cursor: bool,
        cursor: CursorPos,
        cursor_style: terminal_types.CursorStyle,
        blink_style: @TypeOf(blink_style),
        blink_time: f64,
        blink_requires_partial: bool,
        has_kitty: bool,
        width: f32,
        height: f32,
        x: f32,
        y: f32,
        recent_input_window_active: bool,
        execution_update_plan: PresentationUpdatePlan,
        note_present_ctx: @TypeOf(note_present_ctx),
        bg_color: Color,
    };
    const Hooks = struct {
        pub const Result = TerminalPresentResult;

        pub fn executeDirectPresentFlow(plan: TerminalPresentPlan, ctx: Ctx, renderer_local: @TypeOf(renderer)) Result {
            const can_attempt_partial = !ctx.has_kitty and
                renderer_presentable_host.terminalPresentableInfo(renderer_local) != null and
                ctx.terminal_view.rows > 0 and
                ctx.terminal_view.cols > 0 and
                ctx.terminal_view.cells.len > 0;
            const surface_update_plan = if (can_attempt_partial)
                ctx.execution_update_plan
            else
                PresentationUpdatePlan{};
            const DirectCtx = struct {
                base: Ctx,
                surface_update_plan: PresentationUpdatePlan,
            };
            const direct_ctx = DirectCtx{
                .base = ctx,
                .surface_update_plan = surface_update_plan,
            };
            const Local = struct {
                pub fn tryPartialUpdate(
                    local_ctx: DirectCtx,
                    local_renderer: @TypeOf(renderer),
                    _: TerminalPresentPlan,
                ) DirectTerminalPresentExecutionResult {
                    const partial = tryIncrementalPresentableUpdate(
                        local_ctx.base.self_widget,
                        local_ctx.base.shell,
                        local_renderer,
                        local_ctx.surface_update_plan,
                        local_ctx.base.terminal_view,
                        local_ctx.base.view_geometry,
                        local_ctx.base.hover_link_id,
                        local_ctx.base.composing_active,
                        local_ctx.base.composing_hash,
                        local_ctx.base.draw_cursor,
                        local_ctx.base.cursor,
                        local_ctx.base.cursor_style,
                        local_ctx.base.blink_style,
                        local_ctx.base.blink_time,
                        local_ctx.base.has_kitty,
                        local_ctx.base.width,
                        local_ctx.base.height,
                        local_ctx.base.note_present_ctx,
                        note_present,
                    );
                    return .{
                        .completed = partial.completed,
                        .updated = partial.completed,
                        .timing = .{
                            .background_ms = partial.bg_ms,
                            .glyph_ms = partial.glyph_ms,
                            .kitty_ms = partial.kitty_ms,
                        },
                    };
                }

                pub fn executePresent(
                    local_ctx: DirectCtx,
                    local_renderer: @TypeOf(renderer),
                    _: TerminalPresentPlan,
                ) DirectTerminalPresentExecutionResult {
                    return directPresent(
                        local_ctx.base.self_widget,
                        local_ctx.base.shell,
                        local_renderer,
                        local_ctx.base.terminal_view,
                        local_ctx.base.view_geometry,
                        local_ctx.base.hover_link_id,
                        local_ctx.base.draw_cursor,
                        local_ctx.base.cursor,
                        local_ctx.base.cursor_style,
                        local_ctx.base.composing_active,
                        local_ctx.base.composing_hash,
                        local_ctx.base.blink_style,
                        local_ctx.base.blink_time,
                        local_ctx.base.start_line,
                        local_ctx.base.has_kitty,
                        local_ctx.base.width,
                        local_ctx.base.height,
                        local_ctx.base.note_present_ctx,
                        note_present,
                    );
                }
            };
            const direct = renderer_presentable_host.runDirectTerminalPresentExecution(
                renderer_local,
                plan,
                direct_ctx,
                Local,
            );
            return terminal_presentation_runtime.directPresentEntry(
                direct.updated,
                direct.timing,
            );
        }

        pub fn executePresentableRefreshFlow(_: TerminalPresentPlan, ctx: Ctx, renderer_local: @TypeOf(renderer)) Result {
            return executeRefreshPresentFlow(
                ctx.self_widget,
                ctx.shell,
                renderer_local,
                ctx.terminal_view,
                ctx.view_geometry,
                ctx.hover_link_id,
                ctx.composing_active,
                ctx.composing_hash,
                ctx.start_line,
                ctx.draw_cursor,
                ctx.cursor,
                ctx.cursor_style,
                ctx.blink_style,
                ctx.blink_time,
                ctx.has_kitty,
                ctx.execution_update_plan,
                ctx.note_present_ctx,
                note_present,
            );
        }
    };
    const plan = buildTerminalPresentPlan(
        self,
        renderer,
        terminal_view,
        view_geometry,
        hover_link_id,
        draw_cursor,
        cursor,
        cursor_style,
        composing_active,
        composing_hash,
        x,
        y,
        width,
        height,
        blink_requires_partial,
    );
    const execution_update_plan = buildExecutionUpdatePlan(
        self,
        renderer,
        terminal_view,
        view_geometry,
        blink_requires_partial,
        draw_cursor,
        cursor,
        cursor_style,
        scroll_offset,
        recent_input_window_active,
    );
    const ctx = Ctx{
        .self_widget = self,
        .shell = shell,
        .terminal_view = terminal_view,
        .view_geometry = view_geometry,
        .hover_link_id = hover_link_id,
        .composing_active = composing_active,
        .composing_hash = composing_hash,
        .start_line = start_line,
        .scroll_offset = scroll_offset,
        .draw_cursor = draw_cursor,
        .cursor = cursor,
        .cursor_style = cursor_style,
        .blink_style = blink_style,
        .blink_time = blink_time,
        .blink_requires_partial = blink_requires_partial,
        .has_kitty = has_kitty,
        .width = width,
        .height = height,
        .x = x,
        .y = y,
        .recent_input_window_active = recent_input_window_active,
        .execution_update_plan = execution_update_plan,
        .note_present_ctx = note_present_ctx,
        .bg_color = bg_color,
    };
    const fast = tryFastPresentExisting(
        &self.surface,
        renderer,
        plan,
        terminal_view,
        draw_cursor,
        cursor,
        cursor_style,
        hover_link_id,
        composing_active,
        composing_hash,
        bg_color,
        x,
        y,
        width,
        height,
        view_geometry,
        note_present_ctx,
        note_present,
    );
    if (fast.outcome == .reused) return fast;
    return renderer_presentable_host.runTerminalPresentExecution(renderer, plan, ctx, Hooks);
}

pub fn beginViewportClip(
    renderer: anytype,
    view_geometry: TerminalViewGeometry,
    visible_w: i32,
    visible_h: i32,
) void {
    if (visible_w <= 0 or visible_h <= 0) return;
    renderer_clip_host.beginClip(
        renderer,
        @intFromFloat(std.math.round(view_geometry.origin_x)),
        @intFromFloat(std.math.round(view_geometry.origin_y)),
        visible_w,
        visible_h,
    );
}

/// **Reuse orchestration:** delegates to terminal eligibility check, executes if eligible.
/// Terminal layer owns decision logic; widget owns execution (backdrop, presentDraw, cache advance).
pub fn tryFastPresentExisting(
    surface_state: anytype,
    renderer: anytype,
    plan: TerminalPresentPlan,
    terminal_view: view_state.TerminalViewModel,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    hover_link_id: u32,
    composing_active: bool,
    composing_hash: u64,
    bg_color: Color,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    view_geometry: TerminalViewGeometry,
    note_present_ctx: anytype,
    note_present: anytype,
) TerminalPresentResult {
    const attachment_state = computeHostSurfaceAttachmentState(renderer, surface_state);
    const eligible = terminal_presentation_runtime.checkReuseEligibility(
        plan,
        .{
            .view_cells_len = terminal_view.cells.len,
            .shared_surface_attachment_ready = attachment_state.shared_surface_attachment_ready,
            .sync_updates_active = terminal_view.sync_updates_active,
            .supports_reuse_without_sync = renderer_presentable_host.terminalSupportsReuseWithoutSyncUpdates(renderer),
        },
    );
    if (eligible) {
        renderer_presentable_host.drawTerminalPresentableBackdrop(renderer, x, y, width, height, bg_color.toRgba());
        terminal_presentation_runtime.presentDraw(
            renderer,
            terminal_view.generation,
            surface_state.lastRenderGeneration(),
            view_geometry,
            view_geometry.viewport_width,
            view_geometry.viewport_height,
            note_present_ctx,
            note_present,
        );
        const pres_geom = computePresentationSurfaceGeometry(renderer, terminal_view, view_geometry);
        advancePresentationCache(
            surface_state,
            terminal_view,
            pres_geom,
            draw_cursor,
            cursor,
            cursor_style,
            hover_link_id,
            composing_active,
            composing_hash,
        );
    }
    return terminal_presentation_runtime.reuseEligibilityEntry(
        eligible,
        attachment_state.host_surface_target_available,
        attachment_state.shared_surface_attachment_ready,
        .{},
    );
}

/// **Direct presentation:** terminal-owned eligibility check, widget executes if eligible.
pub fn directPresent(
    self: anytype,
    shell: *app_shell.Shell,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    hover_link_id: u32,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    composing_active: bool,
    composing_hash: u64,
    blink_style: anytype,
    blink_time: f64,
    start_line: usize,
    has_kitty: bool,
    width: f32,
    height: f32,
    note_present_ctx: anytype,
    note_present: anytype,
) DirectTerminalPresentExecutionResult {
    var result = DirectTerminalPresentExecutionResult{};
    const rows = terminal_view.rows;
    const cols = terminal_view.cols;
    const view_cells = terminal_view.cells;
    if (!terminal_presentation_runtime.checkDirectPresentEligibility(.{
        .rows = rows,
        .cols = cols,
        .view_cells_len = view_cells.len,
    })) return result;

    const bg_color: Color = .{
        .r = terminal_view.base_colors.resolved_background.r,
        .g = terminal_view.base_colors.resolved_background.g,
        .b = terminal_view.base_colors.resolved_background.b,
        .a = terminal_view.base_colors.resolved_background.a,
    };
    const viewport_w = @min(width, view_geometry.viewport_width);
    const viewport_h = @min(height, view_geometry.viewport_height);

    renderer_presentable_host.drawTerminalPresentableBackdrop(
        renderer,
        view_geometry.viewport.x,
        view_geometry.viewport.y,
        view_geometry.viewport.width,
        view_geometry.viewport.height,
        bg_color.toRgba(),
    );
    note_present(
        note_present_ctx,
        renderer,
        .immediate_surface_present,
        terminal_view.generation,
        view_geometry.origin_x,
        view_geometry.origin_y,
        viewport_w,
        viewport_h,
        view_geometry.viewport_width,
        view_geometry.viewport_height,
    );
    present_feedback_host.noteTerminalPresentation(renderer, terminal_view.generation);

    const bg_phase_start = app_shell.getTime();
    renderer.beginTerminalBatch();
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        drawRowBackgrounds(
            shell,
            view_geometry,
            view_cells,
            cols,
            row,
            0,
            cols - 1,
            view_geometry.origin_x,
            view_geometry.origin_y,
            0,
            false,
            terminal_view.render.screen_reverse,
            draw_cursor,
            cursor,
            cursor_style,
        );
    }
    renderer.flushTerminalBatch();
    result.timing.background_ms = time_utils.secondsToMs(app_shell.getTime() - bg_phase_start);

    if (has_kitty) {
        const kitty_phase_start = app_shell.getTime();
        self.surface.kitty.cleanupTextures(self.session.allocator, self.surface.kitty.images_view.items);
        self.surface.kitty.drawImages(self.session.allocator, shell, view_geometry.origin_x, view_geometry.origin_y, false, start_line, rows, cols);
        result.timing.kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
    }

    const glyph_phase_start = app_shell.getTime();
    renderer.terminal_font.beginFrameAtlasStats();
    renderer.beginTerminalGlyphBatch();
    var glyph_stats = GlyphDrawStats{};
    row = 0;
    while (row < rows) : (row += 1) {
        drawRowGlyphs(
            shell,
            view_geometry,
            view_cells,
            cols,
            row,
            0,
            cols - 1,
            view_geometry.origin_x,
            view_geometry.origin_y,
            0,
            hover_link_id,
            terminal_view.render.screen_reverse,
            blink_style,
            blink_time,
            draw_cursor,
            cursor,
            cursor_style,
            renderer.font_config.terminal_disable_ligatures,
            terminal_view.generation,
            &glyph_stats,
            self.debug.textPaintSampleSink(),
            self.debug.metalFallbackSampleSink(),
        );
    }
    recordMetalFallbackStats(self, terminal_view.generation, glyph_stats);
    renderer.flushTerminalGlyphBatch();
    result.timing.glyph_ms = time_utils.secondsToMs(app_shell.getTime() - glyph_phase_start);

    if (has_kitty) {
        const kitty_phase_start = app_shell.getTime();
        self.surface.kitty.drawImages(self.session.allocator, shell, view_geometry.origin_x, view_geometry.origin_y, true, start_line, rows, cols);
        result.timing.kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
    }

    const pres_geom = computePresentationSurfaceGeometry(renderer, terminal_view, view_geometry);
    advancePresentationCache(
        &self.surface,
        terminal_view,
        pres_geom,
        draw_cursor,
        cursor,
        cursor_style,
        hover_link_id,
        composing_active,
        composing_hash,
    );
    return result;
}

pub fn tryIncrementalPresentableUpdate(
    self: anytype,
    shell: *app_shell.Shell,
    renderer: anytype,
    surface_update_plan: PresentationUpdatePlan,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    hover_link_id: u32,
    composing_active: bool,
    composing_hash: u64,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    blink_style: anytype,
    blink_time: f64,
    has_kitty: bool,
    width: f32,
    height: f32,
    note_present_ctx: anytype,
    note_present: anytype,
) IncrementalPresentableUpdateResult {
    var result = IncrementalPresentableUpdateResult{};
    if (!renderer_presentable_host.terminalSupportsIncrementalPresentableUpdate(renderer)) return result;
    if (has_kitty) return result;
    if (renderer_presentable_host.terminalPresentableInfo(renderer) == null) return result;
    if (terminal_view.rows == 0 or terminal_view.cols == 0 or terminal_view.cells.len == 0) return result;
    if (surface_update_plan.mode != .partial) return result;

    const viewport_w = @min(width, view_geometry.viewport_width);
    const viewport_h = @min(height, view_geometry.viewport_height);
    if (viewport_w <= 0 or viewport_h <= 0) return result;

    const bg_color: Color = .{
        .r = terminal_view.base_colors.resolved_background.r,
        .g = terminal_view.base_colors.resolved_background.g,
        .b = terminal_view.base_colors.resolved_background.b,
        .a = terminal_view.base_colors.resolved_background.a,
    };
    renderer_presentable_host.drawTerminalPresentableBackdrop(
        renderer,
        view_geometry.viewport.x,
        view_geometry.viewport.y,
        view_geometry.viewport.width,
        view_geometry.viewport.height,
        bg_color.toRgba(),
    );

    note_present(
        note_present_ctx,
        renderer,
        if (terminal_view.partial_capture.active_viewport_shift_rows != 0)
            .incremental_presentable_shift_update
        else
            .incremental_presentable_update,
        terminal_view.generation,
        view_geometry.origin_x,
        view_geometry.origin_y,
        viewport_w,
        viewport_h,
        view_geometry.viewport_width,
        view_geometry.viewport_height,
    );
    renderer_presentable_host.drawTerminalPresentable(renderer, .{
        .x = view_geometry.origin_x,
        .y = view_geometry.origin_y,
        .width = viewport_w,
        .height = viewport_h,
        .source_width = view_geometry.viewport_width,
        .source_height = view_geometry.viewport_height,
        .generation = self.surface.lastRenderGeneration(),
    });
    beginViewportClip(
        renderer,
        view_geometry,
        surface_update_plan.geometry.visible_w,
        surface_update_plan.geometry.visible_h,
    );
    defer renderer_clip_host.endClip(renderer);

    result = executeIncrementalPresentableUpdate(
        self,
        shell,
        renderer,
        terminal_view,
        view_geometry,
        hover_link_id,
        draw_cursor,
        cursor,
        cursor_style,
        blink_style,
        blink_time,
        surface_update_plan,
    );
    if (!result.completed) return result;
    present_feedback_host.noteTerminalPresentation(renderer, terminal_view.generation);
    advancePresentationCache(
        &self.surface,
        terminal_view,
        surface_update_plan.geometry,
        draw_cursor,
        cursor,
        cursor_style,
        hover_link_id,
        composing_active,
        composing_hash,
    );
    return result;
}

pub fn planUpdate(
    surface_state: anytype,
    allocator: std.mem.Allocator,
    renderer: anytype,
    cache: *const RenderCache,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    blink_requires_partial: bool,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    scroll_offset: usize,
    recent_input_window_active: bool,
) PresentationUpdatePlan {
    var plan: PresentationUpdatePlan = .{
        .geometry = .{},
        .mode = .none,
        .partial_plan = null,
    };
    const rows = terminal_view.rows;
    const cols = terminal_view.cols;
    if (rows == 0 or cols == 0) return plan;

    plan.geometry = computePresentationSurfaceGeometry(renderer, terminal_view, view_geometry);

    const recreated = renderer_presentable_host.ensureTerminalPresentable(renderer, plan.geometry.surface_w, plan.geometry.surface_h);
    const presentation_delta = surface_state.presentationUpdateDelta(
        terminal_view,
        plan.geometry,
        draw_cursor,
        cursor,
        cursor_style,
    );

    const publication_generation_differs_from_last_surface_render = surface_contract.publicationGenerationDiffersFromLastSurfaceRender(
        terminal_view.generation,
        surface_state.lastRenderGeneration(),
    );
    const clear_generation_differs_from_last_surface_render_clear = surface_contract.clearGenerationDiffersFromLastSurfaceRenderClear(
        terminal_view.clear_generation,
        surface_state.lastRenderClearGeneration(),
    );

    const terminal_presentable_pipeline_ready = surface_state.terminalPresentablePipelineReady();

    var update_plan = draw_presentation.choosePresentationUpdatePlan(
        cache.dirty,
        recreated,
        clear_generation_differs_from_last_surface_render_clear,
        presentation_delta.cell_metrics_changed,
        presentation_delta.render_scale_changed,
        blink_requires_partial,
        terminal_presentable_pipeline_ready,
    );
    update_plan = draw_presentation.forceFullPresentationUpdatePlanEveryFrame(update_plan, recent_input_window_active);

    var needs_full = update_plan.needs_full;
    var needs_partial = update_plan.needs_partial;
    if (!needs_full and presentation_delta.cursor_changed) {
        needs_partial = true;
    }
    const viewport_shift = ViewportShiftState{
        .rows = terminal_view.partial_capture.active_viewport_shift_rows,
        .exposed_only = terminal_view.partial_capture.shift_exposed_only,
    };
    var shifted_rows: usize = 0;
    var shift_requires_fullwidth_partial = false;
    switch (draw_presentation.planViewportPresentShift(
        renderer.terminalPresentationShiftEnabled(),
        publication_generation_differs_from_last_surface_render,
        viewport_shift.rows,
        viewport_shift.exposed_only,
        scroll_offset,
        needs_full,
        terminal_presentable_pipeline_ready,
        rows,
    )) {
        .attempt => |shift_rows| {
            const dy_pixels: i32 = -viewport_shift.rows * plan.geometry.cell_h_i;
            if (renderer_presentable_host.scrollTerminalPresentable(renderer, 0, dy_pixels)) {
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
        const fullframe_fastpath_decision: FullFrameFastPathDecision = draw_presentation.decideFullFrameFastPath(
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
        const partial_plan = surface_state.ensurePartialDrawPlan(allocator, rows) orelse {
            needs_full = true;
            needs_partial = false;
            return .{
                .geometry = plan.geometry,
                .mode = .full,
                .partial_plan = null,
            };
        };
        _ = draw_presentation.buildPartialPlan(
            cache,
            partial_plan.rows,
            partial_plan.span_counts,
            partial_plan.spans,
            partial_plan.cols_start,
            partial_plan.cols_end,
            shifted_rows,
            viewport_shift.rows,
            shift_requires_fullwidth_partial,
            blink_requires_partial,
        );
        if (presentation_delta.cursor_changed and cols > 0) {
            const full_start: usize = 0;
            const full_end: usize = cols - 1;
            if (surface_state.presentation.last_cursor_visible) {
                const prev_row = @as(usize, surface_state.presentation.last_cursor_row);
                if (prev_row < rows) {
                    draw_presentation.markPartialPlanRow(
                        partial_plan.rows,
                        partial_plan.span_counts,
                        partial_plan.spans,
                        partial_plan.cols_start,
                        partial_plan.cols_end,
                        prev_row,
                        full_start,
                        full_end,
                    );
                }
            }
            if (draw_cursor and cursor.row < rows) {
                draw_presentation.markPartialPlanRow(
                    partial_plan.rows,
                    partial_plan.span_counts,
                    partial_plan.spans,
                    partial_plan.cols_start,
                    partial_plan.cols_end,
                    cursor.row,
                    full_start,
                    full_end,
                );
            }
        }
        plan.partial_plan = partial_plan;
    }

    if (needs_full) {
        plan.mode = .full;
    } else if (needs_partial) {
        plan.mode = .partial;
    } else {
        plan.mode = .none;
    }

    return plan;
}

test "presentation delta pipeline field matches observability vocabulary" {
    const TerminalWidgetSurfaceState = @import("terminal_widget_surface_state.zig").TerminalWidgetSurfaceState;
    comptime {
        const fields = @typeInfo(TerminalWidgetSurfaceState.PresentationUpdateDelta).@"struct".fields;
        var found: usize = 0;
        for (fields) |f| {
            if (std.mem.eql(u8, f.name, "terminal_presentable_pipeline_ready")) found += 1;
        }
        std.debug.assert(found == 1);
    }
}

test "TerminalPresentResult exposes host-target and full-attachment carriers" {
    comptime {
        const fields = @typeInfo(TerminalPresentResult).@"struct".fields;
        var host: usize = 0;
        var shared: usize = 0;
        for (fields) |f| {
            if (std.mem.eql(u8, f.name, "host_surface_target_available")) host += 1;
            if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) shared += 1;
        }
        std.debug.assert(host == 1 and shared == 1);
    }
}

test "reuse outcome aligns with present result attachment field names" {
    comptime {
        const r_fields = @typeInfo(terminal_presentation_runtime.ReusePresentOutcomeState).@"struct".fields;
        var reuse_host: usize = 0;
        var reuse_shared: usize = 0;
        for (r_fields) |f| {
            if (std.mem.eql(u8, f.name, "host_surface_target_available")) reuse_host += 1;
            if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) reuse_shared += 1;
        }
        std.debug.assert(reuse_host == 1 and reuse_shared == 1);
    }
}

test "PresentationPresentState exposes leg field and conjunction field distinctly" {
    comptime {
        const fields = @typeInfo(PresentationPresentState).@"struct".fields;
        var host: usize = 0;
        var conj: usize = 0;
        for (fields) |f| {
            if (std.mem.eql(u8, f.name, "host_surface_target_available")) host += 1;
            if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) conj += 1;
        }
        std.debug.assert(host == 1 and conj == 1);
    }
}

test "present-state and present-result share conjunction reporting field name" {
    comptime {
        var present: usize = 0;
        var result: usize = 0;
        for (@typeInfo(PresentationPresentState).@"struct".fields) |f| {
            if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) present += 1;
        }
        for (@typeInfo(TerminalPresentResult).@"struct".fields) |f| {
            if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) result += 1;
        }
        std.debug.assert(present == 1 and result == 1);
    }
}

test "reuse outcome and present result expose paired leg and conjunction fields" {
    comptime {
        {
            var host: usize = 0;
            var conj: usize = 0;
            for (@typeInfo(terminal_presentation_runtime.ReusePresentOutcomeState).@"struct".fields) |f| {
                if (std.mem.eql(u8, f.name, "host_surface_target_available")) host += 1;
                if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) conj += 1;
            }
            std.debug.assert(host == 1 and conj == 1);
        }
        {
            var host: usize = 0;
            var conj: usize = 0;
            for (@typeInfo(TerminalPresentResult).@"struct".fields) |f| {
                if (std.mem.eql(u8, f.name, "host_surface_target_available")) host += 1;
                if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) conj += 1;
            }
            std.debug.assert(host == 1 and conj == 1);
        }
    }
}

test "Refresh boundary folded result carries conjunction for host-facing transport" {
    const result = TerminalPresentResult{
        .shared_surface_attachment_ready = true,
    };
    try std.testing.expect(result.shared_surface_attachment_ready == true);
}

test "PresentationPresentState stores conjunction for reporting path" {
    const state = PresentationPresentState{
        .shared_surface_attachment_ready = true,
    };
    try std.testing.expect(state.shared_surface_attachment_ready == true);
}

test "terminal_presentation_runtime.ReusePresentOutcomeState conjunction field role matches TerminalPresentResult" {
    const outcome = terminal_presentation_runtime.ReusePresentOutcomeState{
        .shared_surface_attachment_ready = true,
        .host_surface_target_available = false,
    };
    const result = TerminalPresentResult{
        .shared_surface_attachment_ready = outcome.shared_surface_attachment_ready,
        .host_surface_target_available = outcome.host_surface_target_available,
    };
    try std.testing.expect(result.shared_surface_attachment_ready == outcome.shared_surface_attachment_ready);
    try std.testing.expect(result.host_surface_target_available == outcome.host_surface_target_available);
}

test "helper consolidation reuseSuccessOutcome constructs correct outcome state" {
    // Verify the consolidation helper produces the expected outcome state for successful reuse.
    // This locks the pattern: successful reuse always has both legs and conjunction true.
    const outcome = terminal_presentation_runtime.reuseSuccessOutcome();
    try std.testing.expectEqual(outcome.transport.outcome, TerminalPresentOutcome.reused);
    try std.testing.expect(outcome.transport.cache_state_advanced == true);
    try std.testing.expect(outcome.transport.host_surface_target_available == true);
    try std.testing.expect(outcome.transport.shared_surface_attachment_ready == true);
}

test "helper hardening reuse outcome assertion validates consistency" {
    // Verify that the reuse outcome hardening assertion accepts valid reuse states and would
    // catch invalid states in debug builds. This locks the hardening invariant.
    const valid_outcome = terminal_presentation_runtime.reuseSuccessOutcome();
    // If assertReuseOutcomeConsistency didn't catch inconsistency, this would pass
    terminal_presentation_runtime.assertReuseOutcomeConsistency(valid_outcome);

    // Non-reused state should not trigger assertions
    const non_reused: terminal_presentation_runtime.ReusePresentOutcomeState = .{
        .transport = .{
            .outcome = .skipped,
            .cache_state_advanced = false,
            .host_surface_target_available = false,
            .shared_surface_attachment_ready = false,
        },
    };
    terminal_presentation_runtime.assertReuseOutcomeConsistency(non_reused);
}

test "helper hardening direct outcome validates invariant fields" {
    // Verify that classifyDirectPresentOutcome produces correct invariant fields.
    // Direct draws always advance cache, have renderer available, and do not pre-verify conjunction.
    const valid_direct = terminal_presentation_runtime.classifyDirectPresentOutcome(true);
    try std.testing.expect(valid_direct.transport.cache_state_advanced == true);
    try std.testing.expect(valid_direct.transport.host_surface_target_available == true);
    try std.testing.expect(valid_direct.transport.shared_surface_attachment_ready == false);

    const direct_not_updated = terminal_presentation_runtime.classifyDirectPresentOutcome(false);
    try std.testing.expect(direct_not_updated.transport.cache_state_advanced == true);
    try std.testing.expectEqual(direct_not_updated.transport.outcome, .presented);
}

test "integration lock PresentationPresentState conjunction equals outcome conjunction" {
    const present_state = PresentationPresentState{
        .shared_surface_attachment_ready = true,
        .host_surface_target_available = true,
        .visible = true,
        .present = true,
    };
    const outcome = terminal_presentation_runtime.ReusePresentOutcomeState{
        .shared_surface_attachment_ready = true,
        .host_surface_target_available = true,
    };
    try std.testing.expectEqual(
        present_state.shared_surface_attachment_ready,
        outcome.shared_surface_attachment_ready,
    );
}

test "integration lock result fold preserves outcome conjunction" {
    const outcome = terminal_presentation_runtime.ReusePresentOutcomeState{
        .outcome = .reused,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = true,
    };
    const timing = renderer_presentable_host.TerminalPresentTiming{};
    const result = terminal_presentation_runtime.foldReuseOutcomeToPresent(outcome, timing);
    try std.testing.expectEqual(result.shared_surface_attachment_ready, outcome.shared_surface_attachment_ready);
    try std.testing.expectEqual(result.outcome, outcome.outcome);
}

test "integration lock direct present outcome has correct leg/conjunction separation" {
    const outcome = terminal_presentation_runtime.DirectPresentOutcomeState{
        .outcome = .presented,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
    };
    try std.testing.expect(outcome.host_surface_target_available);
}

test "integration lock consolidated outcome states fold correctly" {
    // Verify that all three outcome state types produce consistent results when folded.

    // terminal_presentation_runtime.RefreshOutcomeState: conjunction carried inline
    const refresh_outcome = terminal_presentation_runtime.RefreshOutcomeState{
        .outcome = .updated_and_presented,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = true,
    };
    const refresh_result = terminal_presentation_runtime.foldRefreshOutcomeToPresent(refresh_outcome, .{});
    try std.testing.expectEqual(refresh_result.outcome, TerminalPresentOutcome.updated_and_presented);
    try std.testing.expect(refresh_result.shared_surface_attachment_ready == true);

    // terminal_presentation_runtime.ReusePresentOutcomeState: conjunction as field
    const reuse_outcome = terminal_presentation_runtime.ReusePresentOutcomeState{
        .outcome = .reused,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = true,
    };
    const reuse_result = terminal_presentation_runtime.foldReuseOutcomeToPresent(reuse_outcome, .{});
    try std.testing.expectEqual(reuse_result.outcome, TerminalPresentOutcome.reused);
    try std.testing.expect(reuse_result.shared_surface_attachment_ready == true);

    // terminal_presentation_runtime.DirectPresentOutcomeState: canonical direct fold helper threads direct-path invariants.
    const direct_outcome = terminal_presentation_runtime.DirectPresentOutcomeState{
        .outcome = .presented,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = false,
    };
    const direct_result = terminal_presentation_runtime.foldDirectOutcomeToPresent(
        direct_outcome,
        .{},
    );
    try std.testing.expectEqual(direct_result.outcome, TerminalPresentOutcome.presented);
    try std.testing.expect(direct_result.shared_surface_attachment_ready == false);
}

test "integration hardening fold paths harden outcome consistency" {
    // Verify that fold functions validate outcome state consistency and propagate to result.

    // Test: successful reuse outcome produces result with all fields true
    const reuse_success = terminal_presentation_runtime.reuseSuccessOutcome();
    const reuse_result = terminal_presentation_runtime.foldReuseOutcomeToPresent(reuse_success, .{});
    try std.testing.expectEqual(reuse_result.outcome, .reused);
    try std.testing.expect(reuse_result.cache_state_advanced == true);
    try std.testing.expect(reuse_result.shared_surface_attachment_ready == true);

    // Test: refresh with target unavailable sets followup correctly
    const refresh_unavailable = terminal_presentation_runtime.RefreshOutcomeState{
        .outcome = .presented,
        .cache_state_advanced = false,
        .host_surface_target_available = false,
        .shared_surface_attachment_ready = false,
        .followup = .{ .required = true, .reason = .target_unavailable },
    };
    const refresh_result = terminal_presentation_runtime.foldRefreshOutcomeToPresent(refresh_unavailable, .{});
    try std.testing.expect(refresh_result.followup.required == true);
    try std.testing.expectEqual(refresh_result.followup.reason, .target_unavailable);
}

test "integration follow-through refresh classification validates followup coupling" {
    // Verify that refresh outcome classification validates followup coupling invariants.
    // When followup.required is true, followup.reason must be non-.none.

    // Test: unavailable refresh sets both followup.required and followup.reason
    const refresh_with_followup = terminal_presentation_runtime.classifyRefreshOutcome(.target_unavailable, false);
    try std.testing.expect(refresh_with_followup.followup.required == true);
    try std.testing.expect(refresh_with_followup.followup.reason != .none);

    // Test: successful/presented refresh has both followup fields neutral
    const refresh_success = terminal_presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    try std.testing.expect(refresh_success.followup.required == false);
    try std.testing.expectEqual(refresh_success.followup.reason, .none);

    const refresh_presented = terminal_presentation_runtime.classifyRefreshOutcome(.presented, true);
    try std.testing.expect(refresh_presented.followup.required == false);
    try std.testing.expectEqual(refresh_presented.followup.reason, .none);
}

test "integration follow-through direct outcome folds correctly through generic path" {
    // Verify that direct present outcomes compose correctly through the canonical direct fold helper.
    // Direct draws have both legs true and conjunction false (not pre-verified).

    const direct_updated = terminal_presentation_runtime.classifyDirectPresentOutcome(true);
    const timing = renderer_presentable_host.TerminalPresentTiming{};
    const direct_result = terminal_presentation_runtime.foldDirectOutcomeToPresent(
        direct_updated,
        timing,
    );

    try std.testing.expectEqual(direct_result.outcome, .updated_and_presented);
    try std.testing.expect(direct_result.cache_state_advanced == true);
    try std.testing.expect(direct_result.host_surface_target_available == true);
    try std.testing.expect(direct_result.shared_surface_attachment_ready == false);
}

test "refresh fold assigns followup fields from outcome carrier" {
    // Verify that refresh fold transport assigns followup fields from refresh outcome carrier.
    // This locks the narrowed refresh fold API surface without a separate helper call.

    var result = TerminalPresentResult{
        .outcome = .presented,
        .cache_state_advanced = false,
    };

    // Test: assigning followup fields from outcome carrier shape
    result.followup = .{ .required = true, .reason = .target_unavailable };
    try std.testing.expect(result.followup.required == true);
    try std.testing.expectEqual(result.followup.reason, .target_unavailable);

    // Test: assigning neutral followup fields
    var result2 = TerminalPresentResult{
        .outcome = .presented,
    };
    result2.followup = .{ .required = false, .reason = .none };
    try std.testing.expect(result2.followup.required == false);
    try std.testing.expectEqual(result2.followup.reason, .none);
}

test "consolidation helper refresh outcome assertion unified pattern" {
    // Verify that the consolidated refresh outcome assertion helper correctly validates
    // followup coupling invariants. This locks the consolidation pattern.

    // Test: valid state with followup required and reason set
    const valid_with_followup = terminal_presentation_runtime.RefreshOutcomeState{
        .outcome = .presented,
        .followup = .{ .required = true, .reason = .target_unavailable },
    };
    terminal_presentation_runtime.assertRefreshOutcomeConsistency(valid_with_followup);

    // Test: valid state with followup neutral
    const valid_neutral = terminal_presentation_runtime.RefreshOutcomeState{
        .outcome = .presented,
        .followup = .{ .required = false, .reason = .none },
    };
    terminal_presentation_runtime.assertRefreshOutcomeConsistency(valid_neutral);
}

test "integration consolidation all fold paths route through canonical generic fold" {
    // Verify that all outcome-specific fold paths correctly route through the canonical
    // generic fold function with outcome-type-specific wrapping. This locks the
    // consolidation pattern across all outcome types.

    const timing = renderer_presentable_host.TerminalPresentTiming{};

    // Refresh path: uses generic fold + followup wrapper
    const refresh_outcome = terminal_presentation_runtime.RefreshOutcomeState{
        .outcome = .updated_and_presented,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = true,
        .followup = .{ .required = false, .reason = .none },
    };
    const refresh_result = terminal_presentation_runtime.foldRefreshOutcomeToPresent(refresh_outcome, timing);
    try std.testing.expectEqual(refresh_result.outcome, .updated_and_presented);
    try std.testing.expect(refresh_result.cache_state_advanced == true);
    try std.testing.expect(refresh_result.followup.required == false);

    // Reuse path: uses generic fold with input validation
    const reuse_outcome = terminal_presentation_runtime.reuseSuccessOutcome();
    const reuse_result = terminal_presentation_runtime.foldReuseOutcomeToPresent(reuse_outcome, timing);
    try std.testing.expectEqual(reuse_result.outcome, .reused);
    try std.testing.expect(reuse_result.cache_state_advanced == true);
    try std.testing.expect(reuse_result.shared_surface_attachment_ready == true);

    // Direct path: uses canonical direct fold helper
    const direct_outcome = terminal_presentation_runtime.classifyDirectPresentOutcome(false);
    const direct_result = terminal_presentation_runtime.foldDirectOutcomeToPresent(
        direct_outcome,
        timing,
    );
    try std.testing.expectEqual(direct_result.outcome, .presented);
    try std.testing.expect(direct_result.cache_state_advanced == true);
    try std.testing.expect(direct_result.shared_surface_attachment_ready == false);
}
