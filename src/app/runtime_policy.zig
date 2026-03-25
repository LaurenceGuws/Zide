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
};

pub fn terminalVisibleIntent(user_input_active: bool) RuntimeIntent {
    return .{
        .runtime = .terminal_session,
        .lifecycle = .focused_visible,
        .work_class = if (user_input_active) .interactive else .background,
        .user_input_active = user_input_active,
    };
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
}
