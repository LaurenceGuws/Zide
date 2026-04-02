const std = @import("std");
const terminal_runtime = @import("terminal_runtime.zig");
const workspace_mod = @import("workspace.zig");
const host_queries = @import("session/host_queries.zig");
const session_interaction = @import("session/interaction.zig");
const session_runtime = @import("session/runtime.zig");

const TerminalWorkspace = workspace_mod.TerminalWorkspace;
const TabId = workspace_mod.TabId;
const PtyTerminalRuntime = terminal_runtime.PtyTerminalRuntime;

fn sessionNeedsCloseConfirm(session: *PtyTerminalRuntime) bool {
    if (!host_queries.isAlive(session)) return false;
    const activity = host_queries.currentActivityMetadata(session);
    return activity.foreground_process_present or
        activity.semantic_input_active or
        activity.semantic_output_active or
        host_queries.altScreenActive(session) or
        session_interaction.mouseReportingEnabled(session);
}

pub fn copyActiveSessionCwd(
    workspace: *TerminalWorkspace,
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
) ![]const u8 {
    if (workspace.tabs.items.len == 0) {
        out.clearRetainingCapacity();
        return "";
    }
    const session = workspace.tabs.items[workspace.activeIndex()].session;
    var title_buf = std.ArrayList(u8).empty;
    defer title_buf.deinit(allocator);
    const metadata = try host_queries.copyMetadata(session, allocator, &title_buf, out);
    return metadata.cwd;
}

pub fn activeSessionShouldConfirmClose(workspace: *const TerminalWorkspace) bool {
    if (workspace.tabs.items.len == 0) return false;
    return sessionNeedsCloseConfirm(workspace.tabs.items[workspace.activeIndex()].session);
}

pub fn activeSessionAlive(workspace: *const TerminalWorkspace) bool {
    if (workspace.tabs.items.len == 0) return false;
    return host_queries.isAlive(workspace.tabs.items[workspace.activeIndex()].session);
}

pub fn refreshActiveSessionChildExit(workspace: *TerminalWorkspace) void {
    if (workspace.tabs.items.len == 0) return;
    session_runtime.refreshChildExit(workspace.tabs.items[workspace.activeIndex()].session);
}

pub fn firstConfirmCloseTab(workspace: *const TerminalWorkspace) ?workspace_mod.TabTarget {
    for (workspace.tabs.items, 0..) |tab, idx| {
        if (!sessionNeedsCloseConfirm(tab.session)) continue;
        return .{
            .index = idx,
            .id = tab.id,
        };
    }
    return null;
}

pub fn closeConfirmContextForTabId(
    workspace: *const TerminalWorkspace,
    tab_id: TabId,
) ?TerminalWorkspace.CloseConfirmContext {
    for (workspace.tabs.items) |tab| {
        if (tab.id != tab_id) continue;
        const activity = host_queries.currentActivityMetadata(tab.session);
        return .{
            .foreground_process_present = activity.foreground_process_present,
            .foreground_process_label = activity.foreground_process_label,
            .semantic_command_active = activity.semantic_input_active or activity.semantic_output_active,
        };
    }
    return null;
}
