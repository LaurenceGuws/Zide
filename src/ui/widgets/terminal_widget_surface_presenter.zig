const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const scene_frame_runtime = @import("../renderer/scene_frame_runtime.zig");
const draw_grid = @import("terminal_widget_draw_grid.zig");
const presentation_runtime = @import("terminal_widget_presentation_runtime.zig");
const presentation_state_mod = @import("terminal_widget_presentation_state.zig");
const presentation_target_runtime = @import("terminal_widget_presentation_target_runtime.zig");
const view_state = @import("terminal_widget_view_state.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_publication.CursorPos;
const PresentationPartialDrawPlan = presentation_state_mod.PresentationState.PresentationPartialDrawPlan;

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

const PresentationGeometry = presentation_runtime.PresentationGeometry;
const PresentationUpdatePlan = presentation_runtime.PresentationUpdatePlan;

const PresentationPresentState = presentation_runtime.PresentationPresentState;

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
    return presentation_runtime.refreshPresentState(
        &self.surface,
        renderer,
        terminal_view,
        surface_geometry,
        view_geometry,
        presentation_update_completed,
        visible_w,
        visible_h,
        view_cells_len,
    );
}

fn logPresentationUnavailable(
    self: anytype,
    terminal_view: view_state.TerminalViewModel,
    present_state: PresentationPresentState,
    visible_w: i32,
    visible_h: i32,
) void {
    presentation_runtime.logUnavailable(&self.surface, terminal_view, present_state, visible_w, visible_h);
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
    presentation_runtime.presentDraw(
        renderer,
        sample_generation,
        surface_generation,
        view_geometry,
        viewport_w,
        viewport_h,
        self,
        noteTerminalPresent,
    );
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
    return presentation_runtime.planUpdate(
        &self.surface,
        self.session.allocator,
        renderer,
        self.publication.cacheConst(),
        terminal_view,
        width,
        height,
        blink_requires_partial,
        scroll_offset,
        recent_input_window_active,
    );
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

    const bg_color = if (view_cells.len > 0) toShellColor(base_colors.resolved_background) else r.theme.background;
    if (presentation_runtime.tryFastPresentExisting(
        &self.surface,
        r,
        terminal_view,
        view_cells.len,
        bg_color,
        x,
        y,
        width,
        height,
        view_geometry,
        self,
        noteTerminalPresent,
    )) {
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
        const recent_input_window_active = r.forceFullTerminalPresentationRecentInputWindow() and
            ((input.mods.ctrl or input.mods.shift or input.mods.alt or input.mods.super) or
                self.controller.blink.recentInputWindowActive(
                    plan_time,
                    r.fullTerminalPresentationRecentInputWindowSeconds(),
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

        if (surface_update_plan.mode != .none and presentation_target_runtime.beginPresentable(r)) {
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
