const app_modes = @import("modes/mod.zig");
const app_terminal_surface_gate = @import("terminal_surface_gate.zig");
const app_terminal_tabs_runtime = @import("terminal_tabs_runtime.zig");
const app_bootstrap = @import("bootstrap.zig");

fn terminalInputPressure(input_has_events: bool, terminal_input_activity: bool) bool {
    return terminal_input_activity or input_has_events;
}

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    terminal_workspace: anytype,
    terminals: anytype,
    input_has_events: bool,
    terminal_input_activity: bool,
) !bool {
    if (!app_terminal_surface_gate.hasVisibleTerminalTabs(app_mode, show_terminal, terminal_workspace.*, terminals.len)) return false;

    // Poll pressure should track terminal-relevant activity, not unrelated UI events.
    const input_pressure = terminalInputPressure(input_has_events, terminal_input_activity);

    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        if (terminal_workspace.*) |*workspace| {
            const active_idx_opt = app_terminal_tabs_runtime.activeIndex(
                app_mode,
                terminal_workspace.*,
                terminals.len,
            );
            const active_idx = active_idx_opt orelse 0;
            const active_session = if (active_idx_opt) |idx| workspace.sessionAt(idx) else null;
            const has_data_pre = if (active_session) |s| s.hasData() else false;
            const currgen_pre = if (active_session) |s| s.currentGeneration() else 0;
            const pubgen_pre = if (active_session) |s| s.publishedGeneration() else 0;
            const PollBudget = @TypeOf(workspace.*).PollBudget;
            const budget: PollBudget = if (input_pressure)
                .{
                    .max_tabs_per_frame = 3,
                    .max_background_tabs_per_frame = 1,
                    .max_active_polls_per_frame = 2,
                }
            else
                .{
                    .max_tabs_per_frame = 6,
                    .max_background_tabs_per_frame = 3,
                    .max_active_polls_per_frame = 4,
                };
            const any_polled = try workspace.pollBudgeted(
                active_idx,
                input_pressure,
                budget,
            );
            const pubgen_post = if (active_session) |s| s.publishedGeneration() else 0;
            _ = any_polled;
            _ = has_data_pre;
            _ = currgen_pre;
            return pubgen_post != pubgen_pre;
        }
        return false;
    }

    if (terminals.len > 0) {
        const term = terminals[0];
        const has_data_pre = term.hasData();
        const pubgen_pre = term.publishedGeneration();
        if (has_data_pre) {
            term.setInputPressure(input_pressure);
            try term.poll();
            const pubgen_post = term.publishedGeneration();
            return pubgen_post != pubgen_pre;
        } else {
            const pubgen_post = term.publishedGeneration();
            return pubgen_post != pubgen_pre;
        }
    }
    return false;
}
