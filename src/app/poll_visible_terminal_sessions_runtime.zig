const app_modes = @import("modes/mod.zig");
const app_terminal_poll_runtime = @import("terminal_poll_runtime.zig");
const app_terminal_surface_gate = @import("terminal/terminal_surface_gate.zig");
const app_terminal_tabs_runtime = @import("terminal/terminal_tabs_runtime.zig");
const app_bootstrap = @import("bootstrap.zig");

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    terminal_workspace: anytype,
    terminals: anytype,
    input_has_events: bool,
    terminal_input_activity: bool,
) !bool {
    if (!app_terminal_surface_gate.hasVisibleTerminalTabs(app_mode, show_terminal, terminal_workspace.*, terminals.len)) return false;

    const input_pressure = app_terminal_poll_runtime.inputPressure(input_has_events, terminal_input_activity);

    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        if (terminal_workspace.*) |*workspace| {
            const active_idx_opt = app_terminal_tabs_runtime.activeIndex(
                app_mode,
                terminal_workspace.*,
                terminals.len,
            );
            return app_terminal_poll_runtime.pollWorkspace(workspace, active_idx_opt, input_pressure);
        }
        return false;
    }

    if (terminals.len > 0) {
        return app_terminal_poll_runtime.pollSingleSession(terminals[0], input_pressure);
    }
    return false;
}
