const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const retained_targets_runtime = @import("../renderer/retained_targets_runtime.zig");
const scene_frame_runtime = @import("../renderer/scene_frame_runtime.zig");
const draw_grid = @import("terminal_widget_draw_grid.zig");
const draw_texture = @import("terminal_widget_draw_texture.zig");
const presentation_state_mod = @import("terminal_widget_retained_state.zig");
const view_state = @import("terminal_widget_view_state.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_publication.CursorPos;
const PresentationPartialDrawPlan = presentation_state_mod.PresentationState.PresentationPartialDrawPlan;

const FullFrameFastPathDecision = draw_texture.FullFrameFastPathDecision;
const TerminalPresentationSampleMode = @import("terminal_widget_debug_geometry.zig").TerminalPresentationSampleMode;

const drawRowBackgrounds = draw_grid.drawRowBackgrounds;
const drawRowGlyphs = draw_grid.drawRowGlyphs;
const GlyphDrawStats = draw_grid.GlyphDrawStats;

pub const SurfacePresentResult = struct {
    early_return: bool = false,
    presentation_update_ms: f64 = 0.0,
    presentation_bg_ms: f64 = 0.0,
    presentation_glyph_ms: f64 = 0.0,
    presentation_kitty_ms: f64 = 0.0,
};

const ViewportShiftState = struct {
    rows: i32 = 0,
    exposed_only: bool = false,
};

const PresentationGeometry = struct {
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

const SurfaceUpdateMode = enum {
    none,
    full,
    partial,
};

const PresentationUpdatePlan = struct {
    geometry: PresentationGeometry = .{},
    mode: SurfaceUpdateMode = .none,
    partial_plan: ?PresentationPartialDrawPlan = null,
};

const PresentationPresentState = struct {
    updated: bool = false,
    target_available: bool = false,
    ready: bool = false,
    visible: bool = false,
    present: bool = false,
    log_unavailable: bool = false,
};

const PresentationExecutionResult = struct {
    completed: bool = false,
    bg_ms: f64 = 0.0,
    glyph_ms: f64 = 0.0,
    kitty_ms: f64 = 0.0,
};

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
    shell: *Shell,
    renderer: anytype,
    view_geometry: shared_types.layout.TerminalViewGeometry,
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
        renderer.addTerminalRect(0, 0, surface_update_plan.geometry.surface_w, surface_update_plan.geometry.surface_h, bg_color);
    }
    var visitor = struct {
        shell: *Shell,
        view_geometry: shared_types.layout.TerminalViewGeometry,
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
    shell: *Shell,
    renderer: anytype,
    view_geometry: shared_types.layout.TerminalViewGeometry,
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
    terminal_generation: u64,
    surface_update_plan: PresentationUpdatePlan,
    glyph_draw_stats: *GlyphDrawStats,
) f64 {
    const glyph_phase_start = app_shell.getTime();
    renderer.terminal_font.beginFrameAtlasStats();
    renderer.beginTerminalGlyphBatch();
    var visitor = struct {
        self_widget: @TypeOf(self),
        shell: *Shell,
        view_geometry: shared_types.layout.TerminalViewGeometry,
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
        terminal_generation: u64,
        glyph_draw_stats: *GlyphDrawStats,
        metal_fallback_sample: *@import("terminal_widget_debug_geometry.zig").MetalTerminalFallbackSample,

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
                ctx.terminal_generation,
                ctx.glyph_draw_stats,
                &ctx.self_widget.debug.last_text_paint,
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
        .terminal_generation = terminal_generation,
        .glyph_draw_stats = glyph_draw_stats,
        .metal_fallback_sample = &self.debug.last_metal_terminal_fallback,
    };
    forEachPresentationDrawSpan(rows, cols, surface_update_plan, &visitor);
    renderer.flushTerminalGlyphBatch();
    return time_utils.secondsToMs(app_shell.getTime() - glyph_phase_start);
}

fn executePresentationUpdate(
    self: anytype,
    shell: *Shell,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: shared_types.layout.TerminalViewGeometry,
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
    const bg_color = if (view_cells.len > 0) toShellColor(base_colors.resolved_background) else renderer.theme.background;
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
    if (has_kitty) {
        const kitty_phase_start = app_shell.getTime();
        self.surface.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, true, start_line, rows, cols);
        result.kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
    }
    result.completed = true;
    return result;
}

fn toShellColor(color: terminal_publication.Color) Color {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
}

fn noteTerminalPresent(
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
    var sample = @TypeOf(self.debug.last_terminal_presentation){
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
    if (mode == .retained_surface) {
        if (renderer.retained_targets.terminal) |target| {
            sample.presentable_w_px = target.texture.width;
            sample.presentable_h_px = target.texture.height;
            sample.target_logical_w = @floatFromInt(target.logical_width);
            sample.target_logical_h = @floatFromInt(target.logical_height);
        } else {
            sample.valid = false;
        }
    }
    self.debug.last_terminal_presentation = sample;
}

fn directPresentMainTarget(
    self: anytype,
    shell: *Shell,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: shared_types.layout.TerminalViewGeometry,
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
) SurfacePresentResult {
    var result = SurfacePresentResult{};
    const rows = terminal_view.rows;
    const cols = terminal_view.cols;
    const view_cells = terminal_view.cells;
    if (rows == 0 or cols == 0 or view_cells.len == 0) return result;

    const bg_color = toShellColor(terminal_view.base_colors.resolved_background);
    renderer.drawRect(
        @intFromFloat(std.math.round(view_geometry.origin_x)),
        @intFromFloat(std.math.round(view_geometry.origin_y)),
        @intFromFloat(std.math.round(@min(width, view_geometry.viewport_width))),
        @intFromFloat(std.math.round(@min(height, view_geometry.viewport_height))),
        bg_color,
    );
    noteTerminalPresent(
        self,
        renderer,
        .direct_main_target,
        terminal_view.generation,
        view_geometry.origin_x,
        view_geometry.origin_y,
        @min(width, view_geometry.viewport_width),
        @min(height, view_geometry.viewport_height),
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
    result.presentation_bg_ms = time_utils.secondsToMs(app_shell.getTime() - bg_phase_start);

    if (has_kitty) {
        const kitty_phase_start = app_shell.getTime();
        self.surface.kitty.cleanupTextures(self.session.allocator, self.surface.kitty.images_view.items);
        self.surface.kitty.drawImages(self.session.allocator, shell, view_geometry.origin_x, view_geometry.origin_y, false, start_line, rows, cols);
        result.presentation_kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
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
    result.presentation_glyph_ms = time_utils.secondsToMs(app_shell.getTime() - glyph_phase_start);

    if (has_kitty) {
        const kitty_phase_start = app_shell.getTime();
        self.surface.kitty.drawImages(self.session.allocator, shell, view_geometry.origin_x, view_geometry.origin_y, true, start_line, rows, cols);
        result.presentation_kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
    }

    return result;
}

fn beginPresentationViewportClip(
    renderer: anytype,
    view_geometry: shared_types.layout.TerminalViewGeometry,
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

fn refreshPresentationPresentState(
    self: anytype,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    surface_geometry: PresentationGeometry,
    view_geometry: shared_types.layout.TerminalViewGeometry,
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
        self.surface.notePresentationUpdated(terminal_view, surface_geometry);
    }

    state.target_available = retained_targets_runtime.surfaceAvailable(renderer, .terminal);
    state.ready = self.surface.notePresentableAvailability(state.target_available);
    state.present = state.ready and state.visible;
    state.log_unavailable = !state.ready and terminal_view.rows > 0 and terminal_view.cols > 0 and view_cells_len > 0 and state.visible;

    if (state.present) {
        beginPresentationViewportClip(renderer, view_geometry, visible_w, visible_h);
    }

    return state;
}

fn logPresentationUnavailable(
    self: anytype,
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
        .{ .key = "presentable_ready", .value = .{ .boolean = self.surface.presentableReady() } },
        .{ .key = "target_available", .value = .{ .boolean = present_state.target_available } },
        .{ .key = "visible_w", .value = .{ .integer = visible_w } },
        .{ .key = "visible_h", .value = .{ .integer = visible_h } },
    });
}

fn presentPresentationSurface(
    self: anytype,
    renderer: anytype,
    sample_generation: u64,
    surface_generation: u64,
    view_geometry: shared_types.layout.TerminalViewGeometry,
    viewport_w: f32,
    viewport_h: f32,
) void {
    noteTerminalPresent(
        self,
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
    retained_targets_runtime.drawSurface(renderer, .terminal, .{
        .x = view_geometry.origin_x,
        .y = view_geometry.origin_y,
        .width = viewport_w,
        .height = viewport_h,
        .source_width = viewport_w,
        .source_height = viewport_h,
        .generation = surface_generation,
    });
}

fn planPresentationUpdate(
    self: anytype,
    renderer: anytype,
    terminal_view: view_state.TerminalViewModel,
    width: f32,
    height: f32,
    blink_requires_partial: bool,
    scroll_offset: usize,
    recent_input_window_active: bool,
) PresentationUpdatePlan {
    var plan = PresentationUpdatePlan{};
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

    const recreated = retained_targets_runtime.ensureSurface(renderer, .terminal, plan.geometry.surface_w, plan.geometry.surface_h);
    const presentation_delta = self.surface.presentationUpdateDelta(terminal_view, plan.geometry);

    var update_plan = draw_texture.choosePresentationUpdatePlan(
        self.publication.cacheConst().dirty,
        recreated,
        presentation_delta.clear_generation_changed,
        presentation_delta.cell_metrics_changed,
        presentation_delta.render_scale_changed,
        blink_requires_partial,
        presentation_delta.presentable_ready,
    );
    update_plan = draw_texture.forceFullPresentationUpdatePlanEveryFrame(update_plan, recent_input_window_active);

    var needs_full = update_plan.needs_full;
    var needs_partial = update_plan.needs_partial;
    const viewport_shift = ViewportShiftState{
        .rows = terminal_view.partial_capture.active_viewport_shift_rows,
        .exposed_only = terminal_view.partial_capture.shift_exposed_only,
    };
    var shifted_rows: usize = 0;
    var shift_requires_fullwidth_partial = false;
    switch (draw_texture.planViewportPresentShift(
        renderer.terminalTextureShiftEnabled(),
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
            if (retained_targets_runtime.scrollSurface(renderer, .terminal, 0, dy_pixels)) {
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
            self.publication.cacheConst(),
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
        const partial_plan = self.surface.ensurePartialDrawPlan(self.session.allocator, rows) orelse {
            needs_full = true;
            needs_partial = false;
            return .{
                .geometry = plan.geometry,
                .mode = .full,
            };
        };
        _ = draw_texture.buildPartialPlan(
            self.publication.cacheConst(),
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

    blk: {
        if (needs_full) {
            plan.mode = .full;
            break :blk;
        }
        if (needs_partial) {
            plan.mode = .partial;
            break :blk;
        }
        plan.mode = .none;
    }

    return plan;
}

pub fn updateAndPresent(
    self: anytype,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    input: shared_types.input.InputSnapshot,
    terminal_view: view_state.TerminalViewModel,
    view_geometry: shared_types.layout.TerminalViewGeometry,
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
    const r = shell.rendererPtr();
    const rows = terminal_view.rows;
    const cols = terminal_view.cols;
    const view_cells = terminal_view.cells;
    const base_colors = terminal_view.base_colors;
    self.debug.last_terminal_presentation.valid = false;

    if (r.terminalPresentationMode() == .direct_main_target) {
        return directPresentMainTarget(
            self,
            shell,
            r,
            terminal_view,
            view_geometry,
            hover_link_id,
            draw_cursor,
            cursor,
            cursor_style,
            blink_style,
            blink_time,
            start_line,
            has_kitty,
            width,
            height,
        );
    }

    const presentation_target_available = retained_targets_runtime.surfaceAvailable(r, .terminal);
    const presentation_ready = self.surface.notePresentableAvailability(presentation_target_available);

    if (terminal_view.sync_updates_active and view_cells.len > 0 and presentation_ready) {
        const bg_color = if (view_cells.len > 0) toShellColor(base_colors.resolved_background) else r.theme.background;
        r.drawRect(
            @intFromFloat(x),
            @intFromFloat(y),
            @intFromFloat(width),
            @intFromFloat(height),
            bg_color,
        );
        noteTerminalPresent(
            self,
            r,
            .retained_surface,
            terminal_view.generation,
            view_geometry.origin_x,
            view_geometry.origin_y,
            view_geometry.viewport_width,
            view_geometry.viewport_height,
            view_geometry.viewport_width,
            view_geometry.viewport_height,
        );
        retained_targets_runtime.drawSurface(r, .terminal, .{
            .x = view_geometry.origin_x,
            .y = view_geometry.origin_y,
            .width = view_geometry.viewport_width,
            .height = view_geometry.viewport_height,
            .source_width = view_geometry.viewport_width,
            .source_height = view_geometry.viewport_height,
            .generation = self.surface.lastRenderGeneration(),
        });
        result.early_return = true;
        return result;
    }

    var visible_w: i32 = 0;
    var visible_h: i32 = 0;
    var viewport_w: f32 = 0;
    var viewport_h: f32 = 0;
    var padding_x_i: i32 = 0;

    if (rows > 0 and cols > 0) {
        const plan_time = app_shell.getTime();
        const recent_input_window_active = r.forceFullTerminalTexturePublicationRecentInputWindow() and
            ((input.mods.ctrl or input.mods.shift or input.mods.alt or input.mods.super) or
                self.controller.blink.recentInputWindowActive(
                    plan_time,
                    r.fullTerminalTexturePublicationRecentInputWindowSeconds(),
                ));
        const surface_update_plan = planPresentationUpdate(
            self,
            r,
            terminal_view,
            width,
            height,
            blink_requires_partial,
            scroll_offset,
            recent_input_window_active,
        );
        visible_w = surface_update_plan.geometry.visible_w;
        visible_h = surface_update_plan.geometry.visible_h;
        viewport_w = surface_update_plan.geometry.viewport_w;
        viewport_h = surface_update_plan.geometry.viewport_h;
        padding_x_i = surface_update_plan.geometry.padding_x_i;
        var presentation_update_completed = false;

        if (surface_update_plan.mode != .none and retained_targets_runtime.beginSurface(r, .terminal)) {
            r.endClip();
            const execution = executePresentationUpdate(
                self,
                shell,
                r,
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
            result.presentation_bg_ms += execution.bg_ms;
            result.presentation_glyph_ms += execution.glyph_ms;
            result.presentation_kitty_ms += execution.kitty_ms;
            presentation_update_completed = execution.completed;
            scene_frame_runtime.restoreMainCompositionTarget(r);
        }
        const present_state = refreshPresentationPresentState(
            self,
            r,
            terminal_view,
            surface_update_plan.geometry,
            view_geometry,
            presentation_update_completed,
            visible_w,
            visible_h,
            view_cells.len,
        );
        if (rows > 0 and cols > 0) {
            const bg = if (view_cells.len > 0) toShellColor(base_colors.resolved_background) else r.theme.background;
            if (visible_w > 0 and visible_h > 0) {
                r.drawRectF(view_geometry.origin_x, view_geometry.origin_y, viewport_w, viewport_h, bg);
            }
        }
        logPresentationUnavailable(self, terminal_view, present_state, visible_w, visible_h);
        if (present_state.present) {
            presentPresentationSurface(
                self,
                r,
                self.surface.lastRenderGeneration(),
                self.surface.lastRenderGeneration(),
                view_geometry,
                viewport_w,
                viewport_h,
            );
        }
    }

    result.presentation_update_ms = time_utils.secondsToMs(app_shell.getTime() - presentation_phase_start);
    return result;
}
