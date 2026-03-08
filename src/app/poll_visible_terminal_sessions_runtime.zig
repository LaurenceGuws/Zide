const app_modes = @import("modes/mod.zig");
const app_terminal_surface_gate = @import("terminal_surface_gate.zig");
const app_terminal_tabs_runtime = @import("terminal_tabs_runtime.zig");
const app_bootstrap = @import("bootstrap.zig");
const app_logger = @import("../app_logger.zig");
const app_shell = @import("../app_shell.zig");

var terminal_input_activity_hint: ?bool = null;
var last_statebug_poll_log_time: f64 = 0.0;

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
            const active_idx_opt = app_terminal_tabs_runtime.activeIndex(
                app_mode,
                terminal_workspace.*,
                terminals.len,
            );
            const active_idx = active_idx_opt orelse 0;
            const active_session = if (active_idx_opt) |idx| workspace.sessionAt(idx) else null;
            const has_data_pre = if (active_session) |s| s.hasData() else false;
            const gen_pre = if (active_session) |s| s.currentGeneration() else 0;
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
            const has_data_post = if (active_session) |s| s.hasData() else false;
            const gen_post = if (active_session) |s| s.currentGeneration() else 0;
            const now = app_shell.getTime();
            if ((now - last_statebug_poll_log_time) >= 0.1) {
                last_statebug_poll_log_time = now;
                app_logger.logger("terminal.ui.statebug").logf(
                    .info,
                    "poll_probe input_pressure={d} any_polled={d} active_idx={d} hasData_pre={d} hasData_post={d} gen_pre={d} gen_post={d}",
                    .{
                        @intFromBool(input_pressure),
                        @intFromBool(any_polled),
                        active_idx,
                        @intFromBool(has_data_pre),
                        @intFromBool(has_data_post),
                        gen_pre,
                        gen_post,
                    },
                );
            }
            return any_polled;
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
