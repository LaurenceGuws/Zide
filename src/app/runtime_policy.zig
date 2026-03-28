const std = @import("std");

pub const RuntimeKind = enum {
    ui_host,
    terminal_session,
    editor,
    workspace_service,
};

pub const LifecycleTier = enum {
    focused_visible,
    visible_inactive,
    hidden_warm,
    paused,
    evicted,

    pub fn isVisible(self: LifecycleTier) bool {
        return switch (self) {
            .focused_visible, .visible_inactive => true,
            .hidden_warm, .paused, .evicted => false,
        };
    }

    pub fn retainsWarmState(self: LifecycleTier) bool {
        return switch (self) {
            .focused_visible, .visible_inactive, .hidden_warm => true,
            .paused, .evicted => false,
        };
    }
};

pub const WorkClass = enum {
    frame_critical,
    interactive,
    background,
    deferred,
};

pub const RuntimeIntent = struct {
    runtime: RuntimeKind,
    lifecycle: LifecycleTier,
    work_class: WorkClass,
    user_input_active: bool = false,

    pub fn isLatencySensitive(self: RuntimeIntent) bool {
        return switch (self.work_class) {
            .frame_critical, .interactive => true,
            .background, .deferred => false,
        };
    }
};

pub const TerminalWorkspaceIntents = struct {
    active: RuntimeIntent,
    background: RuntimeIntent,
};

pub fn terminalVisibleIntent(user_input_active: bool) RuntimeIntent {
    return .{
        .runtime = .terminal_session,
        .lifecycle = .focused_visible,
        .work_class = if (user_input_active) .interactive else .background,
        .user_input_active = user_input_active,
    };
}

pub fn terminalBackgroundIntent(tab_count: usize) RuntimeIntent {
    return .{
        .runtime = .terminal_session,
        .lifecycle = if (tab_count <= 1)
            .focused_visible
        else if (tab_count == 2)
            .visible_inactive
        else
            .hidden_warm,
        .work_class = .background,
        .user_input_active = false,
    };
}

pub fn terminalWorkspaceIntents(tab_count: usize, user_input_active: bool) TerminalWorkspaceIntents {
    if (tab_count == 0) {
        return .{
            .active = .{
                .runtime = .terminal_session,
                .lifecycle = .hidden_warm,
                .work_class = .background,
                .user_input_active = false,
            },
            .background = .{
                .runtime = .terminal_session,
                .lifecycle = .hidden_warm,
                .work_class = .background,
                .user_input_active = false,
            },
        };
    }
    return .{
        .active = terminalVisibleIntent(user_input_active),
        .background = terminalBackgroundIntent(tab_count),
    };
}

pub fn editorInteractiveIntent() RuntimeIntent {
    return .{
        .runtime = .editor,
        .lifecycle = .focused_visible,
        .work_class = .interactive,
        .user_input_active = true,
    };
}

pub fn editorBackgroundIntent() RuntimeIntent {
    return .{
        .runtime = .editor,
        .lifecycle = .focused_visible,
        .work_class = .background,
        .user_input_active = false,
    };
}

pub fn terminalBackgroundTabBudget(base_budget: usize, intent: RuntimeIntent) usize {
    return switch (intent.lifecycle) {
        .focused_visible => base_budget,
        .visible_inactive => @min(base_budget, @as(usize, 2)),
        .hidden_warm => @min(base_budget, @as(usize, 1)),
        .paused, .evicted => 0,
    };
}

pub fn terminalSleepLifecycle(idle_frames: u32, short_idle_frame_limit: u32, medium_idle_frame_limit: u32) LifecycleTier {
    return if (idle_frames < short_idle_frame_limit)
        .focused_visible
    else if (idle_frames < medium_idle_frame_limit)
        .visible_inactive
    else
        .hidden_warm;
}

pub fn lifecycleLabel(tier: LifecycleTier) []const u8 {
    return switch (tier) {
        .focused_visible => "focused_visible",
        .visible_inactive => "visible_inactive",
        .hidden_warm => "hidden_warm",
        .paused => "paused",
        .evicted => "evicted",
    };
}

pub fn runtimeKindLabel(kind: RuntimeKind) []const u8 {
    return switch (kind) {
        .ui_host => "ui_host",
        .terminal_session => "terminal_session",
        .editor => "editor",
        .workspace_service => "workspace_service",
    };
}

pub fn workClassLabel(work_class: WorkClass) []const u8 {
    return switch (work_class) {
        .frame_critical => "frame_critical",
        .interactive => "interactive",
        .background => "background",
        .deferred => "deferred",
    };
}

test "focused visible tiers are visible and warm" {
    try std.testing.expect(LifecycleTier.focused_visible.isVisible());
    try std.testing.expect(LifecycleTier.focused_visible.retainsWarmState());
}

test "paused and evicted tiers are not visible" {
    try std.testing.expect(!LifecycleTier.paused.isVisible());
    try std.testing.expect(!LifecycleTier.evicted.isVisible());
}

test "terminal visible intent uses interactive class under input pressure" {
    const intent = terminalVisibleIntent(true);
    try std.testing.expectEqual(RuntimeKind.terminal_session, intent.runtime);
    try std.testing.expectEqual(LifecycleTier.focused_visible, intent.lifecycle);
    try std.testing.expectEqual(WorkClass.interactive, intent.work_class);
    try std.testing.expect(intent.isLatencySensitive());
}

test "terminal workspace intents cool background tabs while keeping active input-sensitive" {
    const intents = terminalWorkspaceIntents(2, true);
    try std.testing.expectEqual(LifecycleTier.focused_visible, intents.active.lifecycle);
    try std.testing.expectEqual(WorkClass.interactive, intents.active.work_class);
    try std.testing.expectEqual(LifecycleTier.visible_inactive, intents.background.lifecycle);
    try std.testing.expectEqual(WorkClass.background, intents.background.work_class);
}

test "terminal workspace intents cool larger background sets to hidden warm" {
    const intents = terminalWorkspaceIntents(3, false);
    try std.testing.expectEqual(LifecycleTier.focused_visible, intents.active.lifecycle);
    try std.testing.expectEqual(WorkClass.background, intents.active.work_class);
    try std.testing.expectEqual(LifecycleTier.hidden_warm, intents.background.lifecycle);
    try std.testing.expectEqual(WorkClass.background, intents.background.work_class);
}

test "terminal workspace intents stay background when no tabs exist" {
    const intents = terminalWorkspaceIntents(0, true);
    try std.testing.expectEqual(LifecycleTier.hidden_warm, intents.active.lifecycle);
    try std.testing.expectEqual(WorkClass.background, intents.active.work_class);
    try std.testing.expect(!intents.active.user_input_active);
}

test "editor intents distinguish interactive and background work classes" {
    const interactive = editorInteractiveIntent();
    const background = editorBackgroundIntent();
    try std.testing.expectEqual(RuntimeKind.editor, interactive.runtime);
    try std.testing.expectEqual(LifecycleTier.focused_visible, interactive.lifecycle);
    try std.testing.expectEqual(WorkClass.interactive, interactive.work_class);
    try std.testing.expect(interactive.user_input_active);
    try std.testing.expectEqual(RuntimeKind.editor, background.runtime);
    try std.testing.expectEqual(LifecycleTier.focused_visible, background.lifecycle);
    try std.testing.expectEqual(WorkClass.background, background.work_class);
    try std.testing.expect(!background.user_input_active);
}

test "runtime kind labels stay stable for structured logs" {
    try std.testing.expectEqualStrings("ui_host", runtimeKindLabel(.ui_host));
    try std.testing.expectEqualStrings("terminal_session", runtimeKindLabel(.terminal_session));
    try std.testing.expectEqualStrings("editor", runtimeKindLabel(.editor));
    try std.testing.expectEqualStrings("workspace_service", runtimeKindLabel(.workspace_service));
}

test "hidden warm background budget is capped harder than visible tiers" {
    try std.testing.expectEqual(@as(usize, 4), terminalBackgroundTabBudget(4, .{
        .runtime = .terminal_session,
        .lifecycle = .focused_visible,
        .work_class = .background,
    }));
    try std.testing.expectEqual(@as(usize, 2), terminalBackgroundTabBudget(4, .{
        .runtime = .terminal_session,
        .lifecycle = .visible_inactive,
        .work_class = .background,
    }));
    try std.testing.expectEqual(@as(usize, 1), terminalBackgroundTabBudget(4, .{
        .runtime = .terminal_session,
        .lifecycle = .hidden_warm,
        .work_class = .background,
    }));
}

test "terminal sleep lifecycle cools through focused visible, visible inactive, and hidden warm" {
    try std.testing.expectEqual(
        LifecycleTier.focused_visible,
        terminalSleepLifecycle(0, 10, 60),
    );
    try std.testing.expectEqual(
        LifecycleTier.visible_inactive,
        terminalSleepLifecycle(10, 10, 60),
    );
    try std.testing.expectEqual(
        LifecycleTier.hidden_warm,
        terminalSleepLifecycle(60, 10, 60),
    );
}
