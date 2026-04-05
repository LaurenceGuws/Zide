const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const shared_types = @import("../../types/mod.zig");
const draw_presentation = @import("terminal_widget_draw_presentation.zig");
const presentation_state_mod = @import("terminal_widget_presentation_state.zig");
const view_state = @import("terminal_widget_view_state.zig");
const presentation_target_runtime = @import("terminal_widget_presentation_target_runtime.zig");
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

const drawRowBackgrounds = draw_grid.drawRowBackgrounds;
const drawRowGlyphs = draw_grid.drawRowGlyphs;

pub const PresentationGeometry = struct {
    render_scale: f32 = 1.0,
    cell_w_i: i32 = 0,
    cell_h_i: i32 = 0,
    padding_x_i: i32 = 0,
    surface_w: i32 = 0,
    surface_h: i32 = 0,
    visible_w: i32 = 0,
    visible_h: i32 = 0,
    viewport_w: f32 = 0.0,
    viewport_h: f32 = 0.0,
};

pub const PresentationPresentState = struct {
    updated: bool = false,
    target_available: bool = false,
    ready: bool = false,
    visible: bool = false,
    present: bool = false,
    log_unavailable: bool = false,
};

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

pub const ViewportShiftState = struct {
    rows: i32 = 0,
    exposed_only: bool = false,
};

pub const DirectPresentResult = struct {
    bg_ms: f64 = 0.0,
    glyph_ms: f64 = 0.0,
    kitty_ms: f64 = 0.0,
};

pub fn beginViewportClip(
    renderer: anytype,
    view_geometry: TerminalViewGeometry,
    visible_w: i32,
    visible_h: i32,
) void {
    if (visible_w <= 0 or visible_h <= 0) return;
    renderer.beginClip(
        @intFromFloat(std.math.round(view_geometry.origin_x)),
        @intFromFloat(std.math.round(view_geometry.origin_y)),
        visible_w,
        visible_h,
    );
}

pub fn refreshPresentState(
    surface_state: anytype,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    surface_geometry: PresentationGeometry,
    view_geometry: TerminalViewGeometry,
    presentation_update_completed: bool,
    visible_w: i32,
    visible_h: i32,
    view_cells_len: usize,
) PresentationPresentState {
    var state = PresentationPresentState{
        .updated = presentation_update_completed,
        .visible = visible_w > 0 and visible_h > 0,
    };

    if (presentation_update_completed) {
        surface_state.notePresentationUpdated(terminal_view, surface_geometry);
    }

    state.target_available = presentation_target_runtime.presentableAvailable(renderer);
    state.ready = surface_state.notePresentableAvailability(state.target_available);
    state.present = state.ready and state.visible;
    state.log_unavailable = !state.ready and terminal_view.rows > 0 and terminal_view.cols > 0 and view_cells_len > 0 and state.visible;

    if (state.present) {
        beginViewportClip(renderer, view_geometry, visible_w, visible_h);
    }

    return state;
}

pub fn logUnavailable(
    surface_state: anytype,
    terminal_view: view_state.TerminalViewModel,
    present_state: PresentationPresentState,
    visible_w: i32,
    visible_h: i32,
) void {
    if (!present_state.log_unavailable) return;
    app_logger.logger("renderer.terminal_present").logFields(.warning, "terminal_surface_unavailable_for_present", &.{
        .{ .key = "generation", .value = .{ .unsigned = terminal_view.generation } },
        .{ .key = "sync_updates", .value = .{ .boolean = terminal_view.sync_updates_active } },
        .{ .key = "updated", .value = .{ .boolean = present_state.updated } },
        .{ .key = "presentable_ready", .value = .{ .boolean = surface_state.presentableReady() } },
        .{ .key = "target_available", .value = .{ .boolean = present_state.target_available } },
        .{ .key = "visible_w", .value = .{ .integer = visible_w } },
        .{ .key = "visible_h", .value = .{ .integer = visible_h } },
    });
}

pub fn presentDraw(
    renderer: anytype,
    sample_generation: u64,
    surface_generation: u64,
    view_geometry: TerminalViewGeometry,
    viewport_w: f32,
    viewport_h: f32,
    note_present_ctx: anytype,
    note_present: anytype,
) void {
    note_present(
        note_present_ctx,
        renderer,
        .retained_surface,
        sample_generation,
        view_geometry.origin_x,
        view_geometry.origin_y,
        viewport_w,
        viewport_h,
        viewport_w,
        viewport_h,
    );
    presentation_target_runtime.drawPresentable(renderer, .{
        .x = view_geometry.origin_x,
        .y = view_geometry.origin_y,
        .width = viewport_w,
        .height = viewport_h,
        .source_width = viewport_w,
        .source_height = viewport_h,
        .generation = surface_generation,
    });
}

pub fn tryFastPresentExisting(
    surface_state: anytype,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_cells_len: usize,
    bg_color: Color,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    view_geometry: TerminalViewGeometry,
    note_present_ctx: anytype,
    note_present: anytype,
) bool {
    const presentable_ready = surface_state.notePresentableAvailability(
        presentation_target_runtime.presentableAvailable(renderer),
    );
    if (!(terminal_view.sync_updates_active and view_cells_len > 0 and presentable_ready)) return false;

    renderer.drawRect(
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(width),
        @intFromFloat(height),
        bg_color,
    );
    presentDraw(
        renderer,
        terminal_view.generation,
        surface_state.lastRenderGeneration(),
        view_geometry,
        view_geometry.viewport_width,
        view_geometry.viewport_height,
        note_present_ctx,
        note_present,
    );
    return true;
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

    renderer.drawRect(
        @intFromFloat(std.math.round(view_geometry.origin_x)),
        @intFromFloat(std.math.round(view_geometry.origin_y)),
        @intFromFloat(std.math.round(viewport_w)),
        @intFromFloat(std.math.round(viewport_h)),
        bg_color,
    );
    note_present(
        note_present_ctx,
        renderer,
        .direct_main_target,
        terminal_view.generation,
        view_geometry.origin_x,
        view_geometry.origin_y,
        viewport_w,
        viewport_h,
        view_geometry.viewport_width,
        view_geometry.viewport_height,
    );
    self.surface.noteDirectPresentationReady(terminal_view);

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
            &self.debug.last_text_paint,
            &self.debug.last_metal_terminal_fallback,
        );
    }
    renderer.flushTerminalGlyphBatch();
    result.glyph_ms = time_utils.secondsToMs(app_shell.getTime() - glyph_phase_start);

    if (has_kitty) {
        const kitty_phase_start = app_shell.getTime();
        self.surface.kitty.drawImages(self.session.allocator, shell, view_geometry.origin_x, view_geometry.origin_y, true, start_line, rows, cols);
        result.kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
    }

    return result;
}

pub fn planUpdate(
    surface_state: anytype,
    allocator: std.mem.Allocator,
    renderer: anytype,
    cache: *const RenderCache,
    terminal_view: view_state.TerminalViewModel,
    width: f32,
    height: f32,
    blink_requires_partial: bool,
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

    const geom = renderer.terminalCellGeometry();
    plan.geometry.cell_w_i = geom.cell_width_device_px;
    plan.geometry.cell_h_i = geom.cell_height_device_px;
    plan.geometry.padding_x_i = @max(2, @divTrunc(plan.geometry.cell_w_i, 2));
    plan.geometry.render_scale = 1.0 / renderer.devicePixelStep();

    const scale = plan.geometry.render_scale;
    plan.geometry.surface_w = @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(plan.geometry.cell_w_i * @as(i32, @intCast(cols)) + plan.geometry.padding_x_i)) / scale)));
    plan.geometry.surface_h = @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(plan.geometry.cell_h_i * @as(i32, @intCast(rows)))) / scale)));

    const clip_w = @min(width, geom.cell_width_logical_exact * @as(f32, @floatFromInt(cols)));
    const clip_h = @min(height, geom.cell_height_logical_exact * @as(f32, @floatFromInt(rows)));
    const visible_cols: i32 = if (geom.cell_width_logical_exact > 0) @intFromFloat(std.math.floor(clip_w / geom.cell_width_logical_exact)) else 0;
    const visible_rows: i32 = if (geom.cell_height_logical_exact > 0) @intFromFloat(std.math.floor(clip_h / geom.cell_height_logical_exact)) else 0;
    plan.geometry.visible_w = @intFromFloat(std.math.round(@as(f32, @floatFromInt(visible_cols * geom.cell_width_device_px)) / scale));
    plan.geometry.visible_h = @intFromFloat(std.math.round(@as(f32, @floatFromInt(visible_rows * geom.cell_height_device_px)) / scale));
    plan.geometry.viewport_w = @as(f32, @floatFromInt(plan.geometry.visible_w));
    plan.geometry.viewport_h = @as(f32, @floatFromInt(plan.geometry.visible_h));

    const recreated = presentation_target_runtime.ensurePresentable(renderer, plan.geometry.surface_w, plan.geometry.surface_h);
    const presentation_delta = surface_state.presentationUpdateDelta(terminal_view, plan.geometry);

    var update_plan = draw_presentation.choosePresentationUpdatePlan(
        cache.dirty,
        recreated,
        presentation_delta.clear_generation_changed,
        presentation_delta.cell_metrics_changed,
        presentation_delta.render_scale_changed,
        blink_requires_partial,
        presentation_delta.presentable_ready,
    );
    update_plan = draw_presentation.forceFullPresentationUpdatePlanEveryFrame(update_plan, recent_input_window_active);

    var needs_full = update_plan.needs_full;
    var needs_partial = update_plan.needs_partial;
    const viewport_shift = ViewportShiftState{
        .rows = terminal_view.partial_capture.active_viewport_shift_rows,
        .exposed_only = terminal_view.partial_capture.shift_exposed_only,
    };
    var shifted_rows: usize = 0;
    var shift_requires_fullwidth_partial = false;
    switch (draw_presentation.planViewportPresentShift(
        renderer.terminalPresentationShiftEnabled(),
        presentation_delta.generation_changed,
        viewport_shift.rows,
        viewport_shift.exposed_only,
        scroll_offset,
        needs_full,
        presentation_delta.presentable_ready,
        rows,
    )) {
        .attempt => |shift_rows| {
            const dy_pixels: i32 = -viewport_shift.rows * plan.geometry.cell_h_i;
            if (presentation_target_runtime.scrollPresentable(renderer, 0, dy_pixels)) {
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
