const std = @import("std");
const terminal_runtime = @import("terminal_runtime.zig");
const workspace_mod = @import("workspace.zig");
const publication_state = @import("publication/publication_state.zig");
const workspace_polling = @import("workspace_polling.zig");
const host_queries = @import("session/host_queries.zig");
const launch_shell_path = @import("session/launch_shell_path.zig");
const session_interaction = @import("session/interaction.zig");
const session_runtime = @import("session/runtime.zig");
const runtime_policy = @import("../../app/runtime_policy.zig");

const TerminalWorkspace = workspace_mod.TerminalWorkspace;
const TabId = workspace_mod.TabId;
const TerminalRuntimeShell = terminal_runtime.TerminalRuntimeShell;
pub const ActiveFrameState = publication_state.FrameState;
pub const PollFrameResult = workspace_mod.TerminalWorkspace.PollFrameResult;
pub const PollPolicy = workspace_mod.TerminalWorkspace.PollPolicy;
pub const PollFrameMetrics = workspace_mod.TerminalWorkspace.PollFrameMetrics;
pub const PollRuntimeCounters = workspace_mod.TerminalWorkspace.PollRuntimeCounters;

pub const PollProfile = struct {
    max_tabs_per_frame: usize,
    max_background_tabs_per_frame: usize,
    max_active_polls_per_frame: usize,
};

pub const PollProfiles = struct {
    interactive: PollProfile,
    idle: PollProfile,

    pub fn select(self: PollProfiles, intent: runtime_policy.RuntimeIntent) PollProfile {
        return switch (intent.work_class) {
            .frame_critical, .interactive => self.interactive,
            .background, .deferred => self.idle,
        };
    }
};

pub const default_poll_profiles: PollProfiles = .{
    .interactive = .{
        .max_tabs_per_frame = 3,
        .max_background_tabs_per_frame = 1,
        .max_active_polls_per_frame = 2,
    },
    .idle = .{
        .max_tabs_per_frame = 6,
        .max_background_tabs_per_frame = 3,
        .max_active_polls_per_frame = 4,
    },
};

pub const TabTarget = struct {
    index: usize,
    id: TabId,
};

pub const CloseConfirmContext = struct {
    foreground_process_present: bool = false,
    foreground_process_label: []const u8 = "",
    semantic_command_active: bool = false,
};

pub fn activeFrameState(workspace: *const TerminalWorkspace) ActiveFrameState {
    if (workspace.tabs.items.len == 0) return .{};
    const session = workspace.tabs.items[workspace.activeIndex()].session;
    return publication_state.frameState(session, session_runtime.hasData(session));
}

pub fn pollForFrame(
    workspace: *TerminalWorkspace,
    input_active_index: ?usize,
    policy: PollPolicy,
) !PollFrameResult {
    return workspace_polling.pollForFrame(workspace, input_active_index, policy);
}

pub fn inputPressure(input_has_events: bool, terminal_input_activity: bool) bool {
    return terminal_input_activity or input_has_events;
}

pub fn pollWorkspace(workspace: *TerminalWorkspace, input_active_index: ?usize, has_input: bool) !bool {
    const result = try pollForFrame(
        workspace,
        input_active_index,
        pollPolicyForTabCount(workspace.tabCount(), has_input),
    );
    return result.active_published_changed;
}

fn pollPolicyForTabCount(tab_count: usize, has_input: bool) PollPolicy {
    const intents = runtime_policy.terminalWorkspaceIntents(tab_count, has_input);
    const profile = default_poll_profiles.select(intents.active);
    const background_budget = runtime_policy.terminalBackgroundTabBudget(
        profile.max_background_tabs_per_frame,
        intents.background,
    );
    return .{
        .active_intent = intents.active,
        .background_intent = intents.background,
        .max_tabs_per_frame = profile.max_tabs_per_frame,
        .max_background_tabs_per_frame = background_budget,
        .max_active_polls_per_frame = profile.max_active_polls_per_frame,
    };
}

pub fn lastPollFrameMetrics(workspace: *const TerminalWorkspace) PollFrameMetrics {
    return workspace.last_poll_metrics;
}

pub fn pollRuntimeCounters(workspace: *const TerminalWorkspace) PollRuntimeCounters {
    return workspace.poll_runtime_counters;
}

fn sessionNeedsCloseConfirm(session: *TerminalRuntimeShell) bool {
    if (!host_queries.isAlive(session)) return false;
    const activity = host_queries.currentActivityMetadata(session);
    return activity.foreground_process_present or
        activity.semantic_input_active or
        activity.semantic_output_active or
        session.core.isAltActive() or
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
    session.lock();
    defer session.unlock();
    out.clearRetainingCapacity();
    try out.appendSlice(allocator, session.core.cwdText());
    return out.items;
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

pub fn firstConfirmCloseTab(workspace: *const TerminalWorkspace) ?TabTarget {
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
) ?CloseConfirmContext {
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

pub fn copyTabSyncState(
    workspace: *TerminalWorkspace,
    allocator: std.mem.Allocator,
    entries_out: *std.ArrayList(workspace_mod.TabSyncEntry),
    strings_out: *std.ArrayList(u8),
) !workspace_mod.TabSyncState {
    entries_out.clearRetainingCapacity();
    strings_out.clearRetainingCapacity();

    var title_buf = std.ArrayList(u8).empty;
    defer title_buf.deinit(allocator);
    var cwd_buf = std.ArrayList(u8).empty;
    defer cwd_buf.deinit(allocator);

    for (workspace.tabs.items) |tab| {
        const metadata = try host_queries.copyMetadata(tab.session, allocator, &title_buf, &cwd_buf);
        const activity = host_queries.currentActivityMetadata(tab.session);

        const title_offset = strings_out.items.len;
        try strings_out.appendSlice(allocator, metadata.title);
        const foreground_process_label_offset = strings_out.items.len;
        try strings_out.appendSlice(allocator, activity.foreground_process_label);
        const foreground_process_command_offset = strings_out.items.len;
        try strings_out.appendSlice(allocator, activity.foreground_process_command);
        const cwd_offset = strings_out.items.len;
        try strings_out.appendSlice(allocator, metadata.cwd);
        const shell_path = launch_shell_path.get(tab.session);
        const shell_path_offset = strings_out.items.len;
        try strings_out.appendSlice(allocator, shell_path);

        try entries_out.append(allocator, .{
            .id = tab.id,
            .title_offset = title_offset,
            .title_len = metadata.title.len,
            .foreground_process_label_offset = foreground_process_label_offset,
            .foreground_process_label_len = activity.foreground_process_label.len,
            .foreground_process_command_offset = foreground_process_command_offset,
            .foreground_process_command_len = activity.foreground_process_command.len,
            .cwd_offset = cwd_offset,
            .cwd_len = metadata.cwd.len,
            .shell_path_offset = shell_path_offset,
            .shell_path_len = shell_path.len,
            .alive = metadata.alive,
            .exit_code = metadata.exit_code,
            .progress_state = activity.progress.state,
            .progress_value = activity.progress.value,
        });
    }

    return .{
        .active_tab_id = workspace.activeTabId(),
        .strings = strings_out.items,
        .tabs = entries_out.items,
    };
}

test "default poll profiles select interactive and idle budgets explicitly" {
    const interactive = default_poll_profiles.select(runtime_policy.terminalVisibleIntent(true));
    try std.testing.expectEqual(@as(usize, 3), interactive.max_tabs_per_frame);
    try std.testing.expectEqual(@as(usize, 1), interactive.max_background_tabs_per_frame);
    try std.testing.expectEqual(@as(usize, 2), interactive.max_active_polls_per_frame);

    const idle = default_poll_profiles.select(runtime_policy.terminalVisibleIntent(false));
    try std.testing.expectEqual(@as(usize, 6), idle.max_tabs_per_frame);
    try std.testing.expectEqual(@as(usize, 3), idle.max_background_tabs_per_frame);
    try std.testing.expectEqual(@as(usize, 4), idle.max_active_polls_per_frame);
}
