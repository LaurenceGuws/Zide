const app_modes = @import("modes/mod.zig");
const app_terminal_surface_gate = @import("terminal_surface_gate.zig");
const app_terminal_tabs_runtime = @import("terminal_tabs_runtime.zig");
const app_bootstrap = @import("bootstrap.zig");

var terminal_input_activity_hint: ?bool = null;

pub fn setTerminalInputActivityHint(active: bool) void {
    terminal_input_activity_hint = active;
}

fn terminalInputPressure(input_has_events: bool) bool {
    return terminal_input_activity_hint orelse input_has_events;
}

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    terminal_workspace: anytype,
    terminals: anytype,
    input_has_events: bool,
) !bool {
    if (!app_terminal_surface_gate.hasVisibleTerminalTabs(app_mode, show_terminal, terminal_workspace.*, terminals.len)) return false;

    // Poll pressure should track terminal-relevant activity, not unrelated UI events.
    const input_pressure = terminalInputPressure(input_has_events);

    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        if (terminal_workspace.*) |*workspace| {
            const PollBudget = @TypeOf(workspace.*).PollBudget;
            const prev = workspace.lastPollFrameMetrics();
            const tab_count = workspace.tabCount();
            var budget: PollBudget = if (input_pressure)
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

            if (tab_count <= 1) {
                budget.max_background_tabs_per_frame = 0;
            } else if (input_pressure and tab_count > 4) {
                // Prioritize active-tab responsiveness when many background tabs are present.
                budget.max_background_tabs_per_frame = 0;
                budget.max_tabs_per_frame = @max(@as(usize, 1), budget.max_active_polls_per_frame);
            }

            if (prev.active_spillover_hint) {
                budget.max_active_polls_per_frame = @min(budget.max_active_polls_per_frame + 1, 6);
                budget.max_tabs_per_frame = @max(budget.max_tabs_per_frame, budget.max_active_polls_per_frame);
            }
            if (!input_pressure and prev.background_backlog_hint) {
                budget.max_background_tabs_per_frame = @min(budget.max_background_tabs_per_frame + 1, 6);
                budget.max_tabs_per_frame = @min(@max(budget.max_tabs_per_frame, budget.max_background_tabs_per_frame + 1), 8);
            }
            if (input_pressure and prev.budget_exhausted_hint and prev.active_spillover_hint) {
                // If the active tab still overflows under pressure, spend the frame on active polls.
                budget.max_background_tabs_per_frame = 0;
                budget.max_tabs_per_frame = budget.max_active_polls_per_frame;
            }

            return try workspace.pollBudgeted(
                app_terminal_tabs_runtime.activeIndex(
                    app_mode,
                    terminal_workspace.*,
                    terminals.len,
                ),
                input_pressure,
                budget,
            );
        }
        return false;
    }

    if (terminals.len > 0) {
        const term = terminals[0];
        if (term.hasData()) {
            term.setInputPressure(input_pressure);
            try term.poll();
            return true;
        }
    }
    return false;
}
