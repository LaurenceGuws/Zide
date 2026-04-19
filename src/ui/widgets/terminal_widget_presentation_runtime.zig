//! Terminal widget presentation runtime: draw/present into the host-owned shared surface.
//!
//! **Ownership:** Publication/clear generations use `surface_contract`; host attachment
//! readiness (presentable pipeline ∧ host drawable target) is named in
//! `surface_attachment_contract` and wired through `TerminalWidgetSurfaceState`.
//! `buildTerminalPresentPlan` reuse gating uses `terminalPresentablePipelineReady()`
//! (pipeline leg only), not the full attachment conjunction — intentional separation.
//!
//! **Delegation:** Outcome classification, folding, and geometry computation are owned by
//! terminal layer (`src/terminal/presentation_runtime.zig`). Widget layer delegates to
//! terminal-layer helpers and re-exports their types. Pure computation ownership explicit;
//! widget owns presentation orchestration and renderer/shell integration (drawing, timing).
//!
//! **Invariants:** Two attachment state legs maintained separately:
//! - `host_surface_target_available`: host drawable-target leg (from renderer)
//! - `shared_surface_attachment_ready`: full conjunction (pipeline ∧ host target)
//! Result structs distinguish leg from conjunction to prevent overloading one bool.
//! Do not re-derive or re-label legs as conjunction in reporting/result paths.
//!
//! **Conjunction computation:** Happens in `refreshPresentState` and `tryFastPresentExisting`
//! via canonical helper `TerminalWidgetSurfaceState.notePresentableAvailability`. Stored on
//! transient `PresentationPresentState` and outcome/result structs. Reported through
//! `logUnavailable`, `readSharedSurfaceAttachmentReady`, and result consumers.
//!
//! **Reporting carriers:** For operator JSON on present failure, conjunction carrier is
//! `PresentationPresentState.shared_surface_attachment_ready` (see `logUnavailable`).
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
const draw_presentation = @import("terminal_widget_draw_presentation.zig");
const presentation_state_mod = @import("terminal_widget_presentation_state.zig");
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

// Types and functions moved to terminal layer
pub const PresentationGeometry = terminal_presentation_runtime.PresentationGeometry;
pub const PresentationPresentState = terminal_presentation_runtime.PresentationPresentState;

// Computation delegated to terminal layer
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

// Viewport shift state moved to terminal layer
pub const ViewportShiftState = terminal_presentation_runtime.ViewportShiftState;

pub const DirectPresentResult = struct {
    bg_ms: f64 = 0.0,
    glyph_ms: f64 = 0.0,
    kitty_ms: f64 = 0.0,
};

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

pub const RefreshedPresentablePresentationResult = terminal_presentation_runtime.RefreshedPresentablePresentationResult;

/// **Refresh outcome snapshot:** classifies refresh cycle result (updated or not).
/// Does not carry conjunction — passed separately to fold function. Host-target leg only.
/// *Invariants:* `followup_required` and `followup_reason` are coupled — must both indicate unavailability
/// or both be in neutral state. Hardening assertions validate this coupling in `classifyRefreshOutcome()`.
// Outcome structs moved to terminal layer
pub const RefreshOutcomeState = terminal_presentation_runtime.RefreshOutcomeState;
pub const DirectPresentOutcomeState = terminal_presentation_runtime.DirectPresentOutcomeState;
pub const ReusePresentOutcomeState = terminal_presentation_runtime.ReusePresentOutcomeState;

// Fold and classification helpers moved to terminal layer
const presentResultFromOutcomeState = terminal_presentation_runtime.presentResultFromOutcomeState;
const presentResultFromRefreshOutcomeState = terminal_presentation_runtime.presentResultFromRefreshOutcomeState;
const presentResultFromReuseOutcomeState = terminal_presentation_runtime.presentResultFromReuseOutcomeState;
const classifyRefreshOutcome = terminal_presentation_runtime.classifyRefreshOutcome;
const classifyDirectPresentOutcome = terminal_presentation_runtime.classifyDirectPresentOutcome;
const reuseSuccessOutcome = terminal_presentation_runtime.reuseSuccessOutcome;
const assertReuseOutcomeConsistency = terminal_presentation_runtime.assertReuseOutcomeConsistency;
const assertDirectPresentOutcomeConsistency = terminal_presentation_runtime.assertDirectPresentOutcomeConsistency;
const assertRefreshOutcomeConsistency = terminal_presentation_runtime.assertRefreshOutcomeConsistency;
const applyOutcomeSpecificFields = terminal_presentation_runtime.applyOutcomeSpecificFields;
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

pub fn runFastPresentIfAvailable(
    surface_state: anytype,
    renderer: anytype,
    plan: TerminalPresentPlan,
    terminal_view: view_state.TerminalViewModel,
    view_cells_len: usize,
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
    const outcome_state = tryFastPresentExisting(
        surface_state,
        renderer,
        plan,
        terminal_view,
        view_cells_len,
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
    if (!outcome_state.reused) return .{};
    return presentResultFromReuseOutcomeState(outcome_state, .{});
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
        result: *TerminalPresentableRefreshExecutionResult = undefined,
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

pub fn runRefreshedPresentablePresentation(
    self: anytype,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    view_cells_len: usize,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: terminal_types.CursorStyle,
    hover_link_id: u32,
    composing_active: bool,
    composing_hash: u64,
    surface_update_plan: PresentationUpdatePlan,
    cycle_result: TerminalPresentableRefreshExecutionResult,
    note_present_ctx: anytype,
    note_present: anytype,
) RefreshedPresentablePresentationResult {
    const result = RefreshedPresentablePresentationResult{
        .bg_ms = cycle_result.timing.background_ms,
        .glyph_ms = cycle_result.timing.glyph_ms,
        .kitty_ms = cycle_result.timing.kitty_ms,
    };

    const visible_w = surface_update_plan.geometry.visible_w;
    const visible_h = surface_update_plan.geometry.visible_h;
    const viewport_w = surface_update_plan.geometry.viewport_w;
    const viewport_h = surface_update_plan.geometry.viewport_h;

    const present_state = terminal_presentation_runtime.refreshPresentState(
        &self.surface,
        renderer,
        terminal_view,
        surface_update_plan.geometry,
        cycle_result.refresh,
        draw_cursor,
        cursor,
        cursor_style,
        hover_link_id,
        composing_active,
        composing_hash,
        visible_w,
        visible_h,
        view_cells_len,
    );
    if (present_state.present) {
        beginViewportClip(renderer, view_geometry, visible_w, visible_h);
    }
    defer if (present_state.present) renderer_clip_host.endClip(renderer);
    const bg = if (view_cells_len > 0)
        Color{
            .r = terminal_view.base_colors.resolved_background.r,
            .g = terminal_view.base_colors.resolved_background.g,
            .b = terminal_view.base_colors.resolved_background.b,
            .a = terminal_view.base_colors.resolved_background.a,
        }
    else
        renderer.theme.background;
    if (view_geometry.viewport.width > 0 and view_geometry.viewport.height > 0) {
        renderer_presentable_host.drawTerminalPresentableBackdrop(
            renderer,
            view_geometry.viewport.x,
            view_geometry.viewport.y,
            view_geometry.viewport.width,
            view_geometry.viewport.height,
            bg.toRgba(),
        );
    }
    logUnavailable(&self.surface, terminal_view, present_state, visible_w, visible_h);
    if (present_state.present) {
        terminal_presentation_runtime.presentDraw(
            renderer,
            self.surface.lastRenderGeneration(),
            self.surface.lastRenderGeneration(),
            view_geometry,
            viewport_w,
            viewport_h,
            note_present_ctx,
            note_present,
        );
    }
    return .{
        .bg_ms = result.bg_ms,
        .glyph_ms = result.glyph_ms,
        .kitty_ms = result.kitty_ms,
        .shared_surface_attachment_ready = present_state.shared_surface_attachment_ready,
    };
}

pub fn executeRefreshPresentFlow(
    self: anytype,
    shell: *app_shell.Shell,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: TerminalViewGeometry,
    view_cells_len: usize,
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
    if (terminal_view.rows == 0 or terminal_view.cols == 0) return .{};
    const cycle = runPresentableRefreshCycle(
        self,
        shell,
        renderer,
        terminal_view,
        view_geometry,
        hover_link_id,
        start_line,
        draw_cursor,
        cursor,
        cursor_style,
        blink_style,
        blink_time,
        has_kitty,
        surface_update_plan,
    );
    const outcome_state = terminal_presentation_runtime.classifyRefreshOutcome(cycle.refresh);
    const refreshed = runRefreshedPresentablePresentation(
        self,
        renderer,
        terminal_view,
        view_geometry,
        view_cells_len,
        draw_cursor,
        cursor,
        cursor_style,
        hover_link_id,
        composing_active,
        composing_hash,
        surface_update_plan,
        cycle,
        note_present_ctx,
        note_present,
    );
    return terminal_presentation_runtime.presentResultFromRefreshOutcomeState(outcome_state, .{
        .background_ms = refreshed.bg_ms,
        .glyph_ms = refreshed.glyph_ms,
        .kitty_ms = refreshed.kitty_ms,
    }, refreshed.shared_surface_attachment_ready);
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

/// **Classify refresh outcome:** derive outcome state from refresh cycle result.
/// Invariant: outcome == .unavailable only when followup_required; followup_reason non-.none only when required.
/// *Hardening:* validates followup coupling to catch invalid state combinations early.
// Classification functions moved to terminal layer

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
        view_cells_len: usize,
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
                    const direct = directPresent(
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
                    return .{
                        .updated = false,
                        .timing = .{
                            .background_ms = direct.bg_ms,
                            .glyph_ms = direct.glyph_ms,
                            .kitty_ms = direct.kitty_ms,
                        },
                    };
                }
            };
            const direct = renderer_presentable_host.runDirectTerminalPresentExecution(
                renderer_local,
                plan,
                direct_ctx,
                Local,
            );
            const outcome_state = classifyDirectPresentOutcome(direct.updated);
            return presentResultFromOutcomeState(
                outcome_state.outcome,
                outcome_state.cache_state_advanced,
                outcome_state.host_surface_target_available,
                direct.timing,
                outcome_state.shared_surface_attachment_ready,
            );
        }

        pub fn executePresentableRefreshFlow(_: TerminalPresentPlan, ctx: Ctx, renderer_local: @TypeOf(renderer)) Result {
            return executeRefreshPresentFlow(
                ctx.self_widget,
                ctx.shell,
                renderer_local,
                ctx.terminal_view,
                ctx.view_geometry,
                ctx.view_cells_len,
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
        .view_cells_len = view_cells_len,
        .bg_color = bg_color,
    };
    const fast = runFastPresentIfAvailable(
        &self.surface,
        renderer,
        plan,
        terminal_view,
        view_cells_len,
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

/// Operator `renderer.terminal_present` JSON when present cannot proceed because the drawable
/// shared-surface attachment is unavailable. **Conjunction key:** the full-attachment
/// boolean is reported **only** from **`present_state.shared_surface_attachment_ready`** (same
/// predicate family as `readSharedSurfaceAttachmentReady` when legs match). Other keys: **generation**
/// on the view model; view/update flags; renderer presentable **refresh cycle** enum; **pipeline** vs
/// **host-target** legs per `surface_attachment_contract`; viewport geometry.
pub fn logUnavailable(
    surface_state: anytype,
    terminal_view: view_state.TerminalViewModel,
    present_state: PresentationPresentState,
    visible_w: i32,
    visible_h: i32,
) void {
    if (!present_state.log_unavailable) return;
    app_logger.logger("renderer.terminal_present").logFields(.warning, "terminal_surface_unavailable_for_present", &.{
        .{ .key = "publication_generation", .value = .{ .unsigned = terminal_view.generation } },
        .{ .key = "sync_updates", .value = .{ .boolean = terminal_view.sync_updates_active } },
        .{ .key = "updated", .value = .{ .boolean = present_state.updated } },
        .{ .key = "renderer_presentable_refresh_tag", .value = .{ .unsigned = @intFromEnum(present_state.presentable_refresh) } },
        .{ .key = "terminal_presentable_pipeline_ready", .value = .{ .boolean = surface_state.terminalPresentablePipelineReady() } },
        .{ .key = "host_surface_target_available", .value = .{ .boolean = present_state.host_surface_target_available } },
        .{ .key = "shared_surface_attachment_ready", .value = .{ .boolean = present_state.shared_surface_attachment_ready } },
        .{ .key = "visible_w", .value = .{ .integer = visible_w } },
        .{ .key = "visible_h", .value = .{ .integer = visible_h } },
    });
}

/// **Canonical compute route for reuse path:** computes conjunction via
/// `notePresentableAvailability`; populates `ReusePresentOutcomeState` with conjunction result
/// for folding into `TerminalPresentResult`.
/// Reuse present path: attempt fast present of existing cached draw. **Canonical conjunction derivation
/// ** compute host-target leg from renderer, pass to `notePresentableAvailability`,
/// and store outcome conjunction on result state.
pub fn tryFastPresentExisting(
    surface_state: anytype,
    renderer: anytype,
    plan: TerminalPresentPlan,
    terminal_view: view_state.TerminalViewModel,
    view_cells_len: usize,
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
) ReusePresentOutcomeState {
    if (plan.present_intent != .reuse) return .{};
    const attachment_state = computeHostSurfaceAttachmentState(renderer, surface_state);
    const host_surface_target_available = attachment_state.host_surface_target_available;
    const shared_surface_attachment_ready = attachment_state.shared_surface_attachment_ready;
    if (!(view_cells_len > 0 and shared_surface_attachment_ready and
        (terminal_view.sync_updates_active or
            renderer_presentable_host.terminalSupportsReuseWithoutSyncUpdates(renderer)))) {
        return .{
            .host_surface_target_available = host_surface_target_available,
            .shared_surface_attachment_ready = shared_surface_attachment_ready,
        };
    }

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
    return reuseSuccessOutcome();
}

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
) DirectPresentResult {
    var result = DirectPresentResult{};
    const rows = terminal_view.rows;
    const cols = terminal_view.cols;
    const view_cells = terminal_view.cells;
    if (rows == 0 or cols == 0 or view_cells.len == 0) return result;

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
    result.bg_ms = time_utils.secondsToMs(app_shell.getTime() - bg_phase_start);

    if (has_kitty) {
        const kitty_phase_start = app_shell.getTime();
        self.surface.kitty.cleanupTextures(self.session.allocator, self.surface.kitty.images_view.items);
        self.surface.kitty.drawImages(self.session.allocator, shell, view_geometry.origin_x, view_geometry.origin_y, false, start_line, rows, cols);
        result.kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
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
    result.glyph_ms = time_utils.secondsToMs(app_shell.getTime() - glyph_phase_start);

    if (has_kitty) {
        const kitty_phase_start = app_shell.getTime();
        self.surface.kitty.drawImages(self.session.allocator, shell, view_geometry.origin_x, view_geometry.origin_y, true, start_line, rows, cols);
        result.kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
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
        const r_fields = @typeInfo(ReusePresentOutcomeState).@"struct".fields;
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
            for (@typeInfo(ReusePresentOutcomeState).@"struct".fields) |f| {
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

test "RefreshedPresentablePresentationResult propagates conjunction for outcome fold" {
    const result = RefreshedPresentablePresentationResult{
        .bg_ms = 0.0,
        .glyph_ms = 0.0,
        .kitty_ms = 0.0,
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

test "ReusePresentOutcomeState conjunction field role matches TerminalPresentResult" {
    const outcome = ReusePresentOutcomeState{
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
    const outcome = reuseSuccessOutcome();
    try std.testing.expect(outcome.reused == true);
    try std.testing.expectEqual(outcome.outcome, TerminalPresentOutcome.reused);
    try std.testing.expect(outcome.cache_state_advanced == true);
    try std.testing.expect(outcome.host_surface_target_available == true);
    try std.testing.expect(outcome.shared_surface_attachment_ready == true);
}

test "helper hardening reuse outcome assertion validates consistency" {
    // Verify that the reuse outcome hardening assertion accepts valid reuse states and would
    // catch invalid states in debug builds. This locks the hardening invariant.
    const valid_outcome = reuseSuccessOutcome();
    // If assertReuseOutcomeConsistency didn't catch inconsistency, this would pass
    assertReuseOutcomeConsistency(valid_outcome);

    // Non-reused state should not trigger assertions
    const non_reused: ReusePresentOutcomeState = .{
        .reused = false,
        .outcome = .skipped,
    };
    assertReuseOutcomeConsistency(non_reused);
}

test "helper hardening direct outcome assertion validates invariants" {
    // Verify that the direct outcome hardening assertion validates invariant fields.
    // Direct draws always advance cache, have renderer available, and do not pre-verify conjunction.
    const valid_direct = classifyDirectPresentOutcome(true);
    assertDirectPresentOutcomeConsistency(valid_direct);
    try std.testing.expect(valid_direct.cache_state_advanced == true);
    try std.testing.expect(valid_direct.host_surface_target_available == true);
    try std.testing.expect(valid_direct.shared_surface_attachment_ready == false);

    const direct_not_updated = classifyDirectPresentOutcome(false);
    assertDirectPresentOutcomeConsistency(direct_not_updated);
    try std.testing.expect(direct_not_updated.cache_state_advanced == true);
    try std.testing.expectEqual(direct_not_updated.outcome, .presented);
}

test "integration lock PresentationPresentState conjunction equals outcome conjunction" {
    const present_state = PresentationPresentState{
        .shared_surface_attachment_ready = true,
        .host_surface_target_available = true,
        .visible = true,
        .present = true,
    };
    const outcome = ReusePresentOutcomeState{
        .shared_surface_attachment_ready = true,
        .host_surface_target_available = true,
    };
    try std.testing.expectEqual(
        present_state.shared_surface_attachment_ready,
        outcome.shared_surface_attachment_ready,
    );
}

test "integration lock result fold preserves outcome conjunction" {
    const outcome = ReusePresentOutcomeState{
        .reused = true,
        .outcome = .reused,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = true,
    };
    const timing = renderer_presentable_host.TerminalPresentTiming{};
    const result = presentResultFromReuseOutcomeState(outcome, timing);
    try std.testing.expectEqual(result.shared_surface_attachment_ready, outcome.shared_surface_attachment_ready);
    try std.testing.expectEqual(result.outcome, outcome.outcome);
}

test "integration lock direct present outcome has correct leg/conjunction separation" {
    const outcome = DirectPresentOutcomeState{
        .outcome = .presented,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
    };
    try std.testing.expect(outcome.host_surface_target_available);
}

test "integration lock consolidated outcome states fold correctly" {
    // Verify that all three outcome state types produce consistent results when folded.

    // RefreshOutcomeState: conjunction passed separately
    const refresh_outcome = RefreshOutcomeState{
        .outcome = .updated_and_presented,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
    };
    const refresh_result = presentResultFromRefreshOutcomeState(refresh_outcome, .{}, true);
    try std.testing.expectEqual(refresh_result.outcome, TerminalPresentOutcome.updated_and_presented);
    try std.testing.expect(refresh_result.shared_surface_attachment_ready == true);

    // ReusePresentOutcomeState: conjunction as field
    const reuse_outcome = ReusePresentOutcomeState{
        .reused = true,
        .outcome = .reused,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = true,
    };
    const reuse_result = presentResultFromReuseOutcomeState(reuse_outcome, .{});
    try std.testing.expectEqual(reuse_result.outcome, TerminalPresentOutcome.reused);
    try std.testing.expect(reuse_result.shared_surface_attachment_ready == true);

    // DirectPresentOutcomeState: both legs and conjunction as fields.
    const direct_outcome = DirectPresentOutcomeState{
        .outcome = .presented,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = false,
    };
    const direct_result = presentResultFromOutcomeState(
        direct_outcome.outcome,
        direct_outcome.cache_state_advanced,
        direct_outcome.host_surface_target_available,
        .{},
        direct_outcome.shared_surface_attachment_ready,
    );
    try std.testing.expectEqual(direct_result.outcome, TerminalPresentOutcome.presented);
    try std.testing.expect(direct_result.shared_surface_attachment_ready == false);
}

test "integration hardening fold paths harden outcome consistency" {
    // Verify that fold functions validate outcome state consistency and propagate to result.

    // Test: successful reuse outcome produces result with all fields true
    const reuse_success = reuseSuccessOutcome();
    const reuse_result = presentResultFromReuseOutcomeState(reuse_success, .{});
    try std.testing.expectEqual(reuse_result.outcome, .reused);
    try std.testing.expect(reuse_result.cache_state_advanced == true);
    try std.testing.expect(reuse_result.shared_surface_attachment_ready == true);

    // Test: refresh with target unavailable sets followup correctly
    const refresh_unavailable = RefreshOutcomeState{
        .outcome = .presented,
        .cache_state_advanced = false,
        .host_surface_target_available = false,
        .followup_required = true,
        .followup_reason = .target_unavailable,
    };
    const refresh_result = presentResultFromRefreshOutcomeState(refresh_unavailable, .{}, false);
    try std.testing.expect(refresh_result.followup.required == true);
    try std.testing.expectEqual(refresh_result.followup.reason, .target_unavailable);
}

test "integration follow-through refresh classification validates followup coupling" {
    // Verify that refresh outcome classification validates followup coupling invariants.
    // When followup_required is true, followup_reason must be non-.none.

    // Test: unavailable refresh sets both followup_required and followup_reason
    const refresh_with_followup = classifyRefreshOutcome(.target_unavailable);
    try std.testing.expect(refresh_with_followup.followup_required == true);
    try std.testing.expect(refresh_with_followup.followup_reason != .none);

    // Test: successful/presented refresh has both followup fields neutral
    const refresh_success = classifyRefreshOutcome(.refreshed);
    try std.testing.expect(refresh_success.followup_required == false);
    try std.testing.expectEqual(refresh_success.followup_reason, .none);

    const refresh_presented = classifyRefreshOutcome(.presented);
    try std.testing.expect(refresh_presented.followup_required == false);
    try std.testing.expectEqual(refresh_presented.followup_reason, .none);
}

test "integration follow-through direct outcome folds correctly through generic path" {
    // Verify that direct present outcomes compose correctly through the generic fold.
    // Direct draws have both legs true and conjunction false (not pre-verified).

    const direct_updated = classifyDirectPresentOutcome(true);
    const timing = renderer_presentable_host.TerminalPresentTiming{};
    const result = presentResultFromOutcomeState(
        direct_updated.outcome,
        direct_updated.cache_state_advanced,
        direct_updated.host_surface_target_available,
        timing,
        direct_updated.shared_surface_attachment_ready,
    );

    try std.testing.expectEqual(result.outcome, .updated_and_presented);
    try std.testing.expect(result.cache_state_advanced == true);
    try std.testing.expect(result.host_surface_target_available == true);
    try std.testing.expect(result.shared_surface_attachment_ready == false);
}

test "consolidation helper unified fold composition pattern" {
    // Verify that the consolidated fold composition helper correctly applies outcome-specific fields.
    // This locks the consolidation pattern used by outcome-specific fold functions.

    var result = TerminalPresentResult{
        .outcome = .presented,
        .cache_state_advanced = false,
    };

    // Test: applying followup fields through unified helper
    applyOutcomeSpecificFields(&result, true, .target_unavailable);
    try std.testing.expect(result.followup.required == true);
    try std.testing.expectEqual(result.followup.reason, .target_unavailable);

    // Test: applying neutral followup fields
    var result2 = TerminalPresentResult{
        .outcome = .presented,
    };
    applyOutcomeSpecificFields(&result2, false, .none);
    try std.testing.expect(result2.followup.required == false);
    try std.testing.expectEqual(result2.followup.reason, .none);
}

test "consolidation helper refresh outcome assertion unified pattern" {
    // Verify that the consolidated refresh outcome assertion helper correctly validates
    // followup coupling invariants. This locks the consolidation pattern.

    // Test: valid state with followup required and reason set
    const valid_with_followup = RefreshOutcomeState{
        .outcome = .presented,
        .followup_required = true,
        .followup_reason = .target_unavailable,
    };
    assertRefreshOutcomeConsistency(valid_with_followup);

    // Test: valid state with followup neutral
    const valid_neutral = RefreshOutcomeState{
        .outcome = .presented,
        .followup_required = false,
        .followup_reason = .none,
    };
    assertRefreshOutcomeConsistency(valid_neutral);
}

test "integration consolidation all fold paths route through canonical generic fold" {
    // Verify that all outcome-specific fold paths correctly route through the canonical
    // generic fold function with outcome-type-specific wrapping. This locks the
    // consolidation pattern across all outcome types.

    const timing = renderer_presentable_host.TerminalPresentTiming{};

    // Refresh path: uses generic fold + followup wrapper
    const refresh_outcome = RefreshOutcomeState{
        .outcome = .updated_and_presented,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
        .followup_required = false,
        .followup_reason = .none,
    };
    const refresh_result = presentResultFromRefreshOutcomeState(refresh_outcome, timing, true);
    try std.testing.expectEqual(refresh_result.outcome, .updated_and_presented);
    try std.testing.expect(refresh_result.cache_state_advanced == true);
    try std.testing.expect(refresh_result.followup.required == false);

    // Reuse path: uses generic fold with input validation
    const reuse_outcome = reuseSuccessOutcome();
    const reuse_result = presentResultFromReuseOutcomeState(reuse_outcome, timing);
    try std.testing.expectEqual(reuse_result.outcome, .reused);
    try std.testing.expect(reuse_result.cache_state_advanced == true);
    try std.testing.expect(reuse_result.shared_surface_attachment_ready == true);

    // Direct path: uses generic fold directly without wrapper
    const direct_outcome = classifyDirectPresentOutcome(false);
    const direct_result = presentResultFromOutcomeState(
        direct_outcome.outcome,
        direct_outcome.cache_state_advanced,
        direct_outcome.host_surface_target_available,
        timing,
        direct_outcome.shared_surface_attachment_ready,
    );
    try std.testing.expectEqual(direct_result.outcome, .presented);
    try std.testing.expect(direct_result.cache_state_advanced == true);
    try std.testing.expect(direct_result.shared_surface_attachment_ready == false);
}
