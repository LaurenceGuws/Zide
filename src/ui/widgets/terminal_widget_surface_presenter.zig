const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const presentation_runtime = @import("terminal_widget_presentation_runtime.zig");
const view_state = @import("terminal_widget_view_state.zig");

const Shell = app_shell.Shell;
const CursorPos = @import("../../terminal/core/publication/terminal_publication.zig").CursorPos;
const terminal_types = @import("../../terminal/model/types.zig");

pub const SurfacePresentResult = struct {
    early_return: bool = false,
    presentation_update_ms: f64 = 0.0,
    presentation_bg_ms: f64 = 0.0,
    presentation_glyph_ms: f64 = 0.0,
    presentation_kitty_ms: f64 = 0.0,
};

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
    const plan_time = app_shell.getTime();
    const recent_input_window_active = r.forceFullTerminalPresentationRecentInputWindow() and
        ((input.mods.ctrl or input.mods.shift or input.mods.alt or input.mods.super) or
            self.controller.blink.recentInputWindowActive(
                plan_time,
                r.fullTerminalPresentationRecentInputWindowSeconds(),
            ));
    const presentation = presentation_runtime.runPresentation(
        self,
        shell,
        r,
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
        width,
        height,
        x,
        y,
        recent_input_window_active,
        self,
        presentation_runtime.notePresentSample,
    );
    result.early_return = presentation.early_return;
    result.presentation_bg_ms = presentation.bg_ms;
    result.presentation_glyph_ms = presentation.glyph_ms;
    result.presentation_kitty_ms = presentation.kitty_ms;
    if (result.early_return) return result;

    result.presentation_update_ms = time_utils.secondsToMs(app_shell.getTime() - presentation_phase_start);
    return result;
}
