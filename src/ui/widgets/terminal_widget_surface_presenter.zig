const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const draw_grid = @import("terminal_widget_draw_grid.zig");
const presentation_runtime = @import("terminal_widget_presentation_runtime.zig");
const presentation_state_mod = @import("terminal_widget_presentation_state.zig");
const presentation_target_runtime = @import("terminal_widget_presentation_target_runtime.zig");
const view_state = @import("terminal_widget_view_state.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = @import("../../terminal/core/publication/terminal_publication.zig").CursorPos;
const terminal_types = @import("../../terminal/model/types.zig");

pub const SurfacePresentResult = struct {
    early_return: bool = false,
    presentation_update_ms: f64 = 0.0,
    presentation_bg_ms: f64 = 0.0,
    presentation_glyph_ms: f64 = 0.0,
    presentation_kitty_ms: f64 = 0.0,
};

fn toShellColor(color: terminal_publication.Color) Color {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
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
    presentation_runtime.clearPresentationSample(self);

    if (r.terminalPresentationMode() == .direct_main_target) {
        const direct = presentation_runtime.directPresent(
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
            self,
            presentation_runtime.notePresentSample,
        );
        result.presentation_bg_ms = direct.bg_ms;
        result.presentation_glyph_ms = direct.glyph_ms;
        result.presentation_kitty_ms = direct.kitty_ms;
        return result;
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
        presentation_runtime.notePresentSample,
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
        const surface_update_plan = presentation_runtime.planUpdate(
            &self.surface,
            self.session.allocator,
            r,
            self.publication.cacheConst(),
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

        if (surface_update_plan.mode != .none) {
            const execution = presentation_runtime.runRetainedPresentCycle(
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
        }
        const present_state = presentation_runtime.refreshPresentState(
            &self.surface,
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
        presentation_runtime.logUnavailable(&self.surface, terminal_view, present_state, visible_w, visible_h);
        if (present_state.present) {
            presentation_runtime.presentDraw(
                r,
                self.surface.lastRenderGeneration(),
                self.surface.lastRenderGeneration(),
                view_geometry,
                viewport_w,
                viewport_h,
                self,
                presentation_runtime.notePresentSample,
            );
        }
    }

    result.presentation_update_ms = time_utils.secondsToMs(app_shell.getTime() - presentation_phase_start);
    return result;
}
