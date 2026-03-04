const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_terminal_active_widget = @import("terminal_active_widget.zig");
const app_terminal_surface_gate = @import("terminal_surface_gate.zig");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const ActiveMode = app_modes.ide.ActiveMode;

pub const Result = struct {
    needs_redraw: bool = false,
};

pub const Hooks = struct {
    poll_visible_sessions: *const fn (*anyopaque, *input_types.InputBatch) anyerror!void,
    handle_terminal_widget_input: *const fn (
        *anyopaque,
        *widgets.TerminalWidget,
        *app_shell.Shell,
        f32,
        f32,
        f32,
        f32,
        bool,
        bool,
        *input_types.InputBatch,
        bool,
        f64,
    ) anyerror!void,
};

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
    terminals_len: usize,
    terminal_widgets: []widgets.TerminalWidget,
    tab_bar_dragging: bool,
    active_kind: ActiveMode,
    shell: *app_shell.Shell,
    layout: layout_types.WidgetLayout,
    input_batch: *input_types.InputBatch,
    search_panel_consumed_input: bool,
    suppress_terminal_shortcuts: bool,
    terminal_close_modal_active: bool,
    now: f64,
    ctx: *anyopaque,
    hooks: Hooks,
) !Result {
    var out: Result = .{};
    if (!app_terminal_surface_gate.hasVisibleTerminalTabs(app_mode, show_terminal, terminal_workspace.*, terminals_len)) {
        return out;
    }

    try hooks.poll_visible_sessions(ctx, input_batch);

    if (app_terminal_active_widget.resolveActive(
        app_mode,
        terminal_workspace,
        terminals_len,
        terminal_widgets,
    )) |term_widget| {
        const strip = app_modes.ide.terminalStrip(app_mode, layout.terminal.height);
        const term_y_draw = layout.terminal.y + strip.offset_y;
        const term_x = layout.terminal.x;
        const term_draw_height = strip.draw_height;

        if (term_widget.updateBlink(now)) {
            out.needs_redraw = true;
        }

        const suppress_terminal_input_for_tab_drag = app_modes.ide.suppressTerminalInputForTabDrag(app_mode, tab_bar_dragging);
        const allow_terminal_input = active_kind == .terminal and !terminal_close_modal_active and !suppress_terminal_input_for_tab_drag;

        try hooks.handle_terminal_widget_input(
            ctx,
            term_widget,
            shell,
            term_x,
            term_y_draw,
            layout.terminal.width,
            term_draw_height,
            allow_terminal_input,
            suppress_terminal_shortcuts,
            input_batch,
            search_panel_consumed_input,
            now,
        );
    }

    return out;
}

