const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const app_modes = @import("../modes/mod.zig");
const app_terminal_poll_runtime = @import("terminal_poll_runtime.zig");
const app_terminal_surface_gate = @import("terminal_surface_gate.zig");
const app_terminal_tabs_runtime = @import("terminal_tabs_runtime.zig");
const app_bootstrap = @import("../bootstrap.zig");

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    terminal_workspace: anytype,
    terminals: anytype,
    input_has_events: bool,
    terminal_input_activity: bool,
) !bool {
    if (!app_terminal_surface_gate.hasVisibleTerminalTabs(app_mode, show_terminal, terminal_workspace.*, terminals.len)) return false;

    const wake_log = app_logger.logger("terminal.wake");
    const input_pressure = app_terminal_poll_runtime.inputPressure(input_has_events, terminal_input_activity);

    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        if (terminal_workspace.*) |*workspace| {
            const active_idx_opt = app_terminal_tabs_runtime.activeIndex(
                app_mode,
                terminal_workspace.*,
                terminals.len,
            );
            const changed = try app_terminal_poll_runtime.pollWorkspace(workspace, active_idx_opt, input_pressure);
            if (wake_log.enabled_file or wake_log.enabled_console) {
                wake_log.logFields(.info, "route_workspace", &.{
                    .{ .key = "input_events", .value = .{ .boolean = input_has_events } },
                    .{ .key = "terminal_input_activity", .value = .{ .boolean = terminal_input_activity } },
                    .{ .key = "input_pressure", .value = .{ .boolean = input_pressure } },
                    .{ .key = "active_idx", .value = .{ .unsigned = if (active_idx_opt) |idx| idx else std.math.maxInt(usize) } },
                    .{ .key = "published_changed", .value = .{ .boolean = changed } },
                });
            }
            return changed;
        }
        return false;
    }

    if (terminals.len > 0) {
        const changed = try app_terminal_poll_runtime.pollSingleSession(terminals[0], input_pressure);
        if (wake_log.enabled_file or wake_log.enabled_console) {
            wake_log.logFields(.info, "route_single", &.{
                .{ .key = "input_events", .value = .{ .boolean = input_has_events } },
                .{ .key = "terminal_input_activity", .value = .{ .boolean = terminal_input_activity } },
                .{ .key = "input_pressure", .value = .{ .boolean = input_pressure } },
                .{ .key = "published_changed", .value = .{ .boolean = changed } },
            });
        }
        return changed;
    }
    return false;
}
