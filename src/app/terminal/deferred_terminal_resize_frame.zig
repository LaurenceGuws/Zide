const app_bootstrap = @import("../bootstrap.zig");
const app_modes = @import("../modes/mod.zig");
const app_terminal_grid = @import("terminal_grid.zig");
const shared_types = @import("../../types/mod.zig");

const layout_types = shared_types.layout;

pub const Result = struct {
    triggered: bool = false,
    needs_redraw: bool = false,
    should_resize_terminals: bool = false,
    rows: u16 = 0,
    cols: u16 = 0,
};

pub fn handle(
    window_resize_pending: *bool,
    window_resize_last_time: f64,
    now: f64,
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    layout: layout_types.WidgetLayout,
    terminal_height: f32,
    terminal_tab_count: usize,
    terminal_cell_width: f32,
    terminal_cell_height: f32,
) Result {
    var out: Result = .{};
    if (!window_resize_pending.* or (now - window_resize_last_time) < 0.12) return out;

    window_resize_pending.* = false;
    out.triggered = true;
    out.needs_redraw = true;

    if (terminal_tab_count == 0) return out;

    const effective_height = app_modes.ide.terminalEffectiveHeightForSizing(
        app_mode,
        show_terminal,
        layout.terminal.height,
        terminal_height,
    );
    const grid = app_terminal_grid.compute(
        layout.terminal.width,
        effective_height,
        terminal_cell_width,
        terminal_cell_height,
        1,
        1,
    );
    out.cols = grid.cols;
    out.rows = grid.rows;
    out.should_resize_terminals = true;
    return out;
}
