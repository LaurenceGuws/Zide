const app_modes = @import("modes/mod.zig");
const app_terminal_surface_gate = @import("terminal_surface_gate.zig");
const app_terminal_tabs_runtime = @import("terminal_tabs_runtime.zig");
const app_bootstrap = @import("bootstrap.zig");

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    terminal_workspace: anytype,
    terminals: anytype,
    input_has_events: bool,
) !bool {
    if (!app_terminal_surface_gate.hasVisibleTerminalTabs(app_mode, show_terminal, terminal_workspace.*, terminals.len)) return false;

    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        if (terminal_workspace.*) |*workspace| {
            return try workspace.pollAll(
                app_terminal_tabs_runtime.activeIndex(
                    app_mode,
                    terminal_workspace.*,
                    terminals.len,
                ),
                input_has_events,
            );
        }
        return false;
    }

    if (terminals.len > 0) {
        const term = terminals[0];
        if (term.hasData()) {
            term.setInputPressure(input_has_events);
            try term.poll();
            return true;
        }
    }
    return false;
}
