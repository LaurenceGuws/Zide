const app_logger = @import("../app_logger.zig");
const app_modes = @import("modes/mod.zig");
const std = @import("std");

pub fn logIfMismatch(
    allocator: std.mem.Allocator,
    active_kind: app_modes.ide.ActiveMode,
    tabs: anytype,
    active_index: usize,
    editor_mode_adapter: anytype,
    terminal_mode_adapter: anytype,
) void {
    const log = app_logger.logger("app.mode.parity");

    const editor_snap = editor_mode_adapter.asContract().snapshot(allocator) catch |err| {
        log.logf(.warning, "editor adapter snapshot failed: {s}", .{@errorName(err)});
        return;
    };
    const terminal_snap = terminal_mode_adapter.asContract().snapshot(allocator) catch |err| {
        log.logf(.warning, "terminal adapter snapshot failed: {s}", .{@errorName(err)});
        return;
    };
    var projections = app_modes.ide.buildTabProjections(allocator, tabs) catch |err| {
        log.logf(.warning, "build tab projections failed: {s}", .{@errorName(err)});
        return;
    };
    defer projections.deinit(allocator);

    const active_projection = app_modes.ide.activeProjectionForTabBar(
        active_kind,
        tabs,
        active_index,
    );

    const editor_parity = app_modes.ide.evaluateKind(
        projections.items,
        .editor,
        active_projection,
        editor_snap.tabs,
        editor_snap.active_tab,
    );
    const terminal_parity = app_modes.ide.evaluateKind(
        projections.items,
        .terminal,
        active_projection,
        terminal_snap.tabs,
        terminal_snap.active_tab,
    );

    if (editor_parity.expected_count != editor_parity.actual_count or
        editor_parity.expected_active != editor_parity.actual_active or
        editor_parity.mismatch != null or
        terminal_parity.expected_count != terminal_parity.actual_count or
        terminal_parity.expected_active != terminal_parity.actual_active or
        terminal_parity.mismatch != null)
    {
        log.logf(
            .info,
            "adapter parity mismatch editor_count={d}/{d} editor_active={?d}/{?d} editor_first_mismatch_idx={?d} editor_first_mismatch_id={?d}/{?d} editor_first_mismatch_title={s}/{s} terminal_count={d}/{d} terminal_active={?d}/{?d} terminal_first_mismatch_idx={?d} terminal_first_mismatch_id={?d}/{?d} terminal_first_mismatch_title={s}/{s}",
            .{
                editor_parity.actual_count,
                editor_parity.expected_count,
                editor_parity.actual_active,
                editor_parity.expected_active,
                if (editor_parity.mismatch) |m| m.index else null,
                if (editor_parity.mismatch) |m| m.actual_id else null,
                if (editor_parity.mismatch) |m| m.expected_id else null,
                if (editor_parity.mismatch) |m| m.actual_title else "<ok>",
                if (editor_parity.mismatch) |m| m.expected_title else "<ok>",
                terminal_parity.actual_count,
                terminal_parity.expected_count,
                terminal_parity.actual_active,
                terminal_parity.expected_active,
                if (terminal_parity.mismatch) |m| m.index else null,
                if (terminal_parity.mismatch) |m| m.actual_id else null,
                if (terminal_parity.mismatch) |m| m.expected_id else null,
                if (terminal_parity.mismatch) |m| m.actual_title else "<ok>",
                if (terminal_parity.mismatch) |m| m.expected_title else "<ok>",
            },
        );
    }
}
