const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const session_runtime = @import("../../terminal/core/session/runtime.zig");
const runtime_policy = @import("../runtime_policy.zig");

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

pub fn inputPressure(input_has_events: bool, terminal_input_activity: bool) bool {
    // Poll pressure should track terminal-relevant activity, not unrelated UI events.
    return terminal_input_activity or input_has_events;
}

fn pollPolicy(comptime Policy: type, has_input: bool) Policy {
    return pollPolicyForTabCount(Policy, 1, has_input);
}

fn pollPolicyForTabCount(comptime Policy: type, tab_count: usize, has_input: bool) Policy {
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

pub fn pollWorkspace(workspace: anytype, input_active_index: ?usize, has_input: bool) !bool {
    const result = try workspace.pollForFrame(
        input_active_index,
        pollPolicyForTabCount(@TypeOf(workspace.*).PollPolicy, workspace.tabCount(), has_input),
    );
    return result.active_published_changed;
}

pub fn pollSingleSession(term: anytype, has_input: bool) !bool {
    const wake_log = app_logger.logger("terminal.wake");
    const pubgen_pre = terminal_publication.publishedGeneration(term);
    const had_data = session_runtime.hasData(term);
    var polled = false;
    if (had_data) {
        session_runtime.setInputPressure(term, has_input);
        try session_runtime.poll(term);
        polled = true;
    }
    const pubgen_post = terminal_publication.publishedGeneration(term);
    const published_changed = pubgen_post != pubgen_pre;
    if (wake_log.enabled_file or wake_log.enabled_console) {
        wake_log.logFields(.info, "single_poll", &.{
            .{ .key = "has_input", .value = .{ .boolean = has_input } },
            .{ .key = "had_data", .value = .{ .boolean = had_data } },
            .{ .key = "polled", .value = .{ .boolean = polled } },
            .{ .key = "published_changed", .value = .{ .boolean = published_changed } },
            .{ .key = "published_generation_pre", .value = .{ .unsigned = pubgen_pre } },
            .{ .key = "published_generation_post", .value = .{ .unsigned = pubgen_post } },
        });
    }
    return published_changed;
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

test "workspace poll policy carries shared active and background intents" {
    const policy = pollPolicyForTabCount(struct {
        active_intent: runtime_policy.RuntimeIntent,
        background_intent: runtime_policy.RuntimeIntent,
        max_tabs_per_frame: usize,
        max_background_tabs_per_frame: usize,
        max_active_polls_per_frame: usize,
    }, 2, true);

    try std.testing.expectEqual(runtime_policy.LifecycleTier.focused_visible, policy.active_intent.lifecycle);
    try std.testing.expectEqual(runtime_policy.WorkClass.interactive, policy.active_intent.work_class);
    try std.testing.expectEqual(runtime_policy.LifecycleTier.visible_inactive, policy.background_intent.lifecycle);
    try std.testing.expectEqual(runtime_policy.WorkClass.background, policy.background_intent.work_class);
    try std.testing.expectEqual(@as(usize, 2), policy.max_background_tabs_per_frame);
}

test "workspace poll policy cools larger background sets more aggressively" {
    const policy = pollPolicyForTabCount(struct {
        active_intent: runtime_policy.RuntimeIntent,
        background_intent: runtime_policy.RuntimeIntent,
        max_tabs_per_frame: usize,
        max_background_tabs_per_frame: usize,
        max_active_polls_per_frame: usize,
    }, 3, false);

    try std.testing.expectEqual(runtime_policy.LifecycleTier.focused_visible, policy.active_intent.lifecycle);
    try std.testing.expectEqual(runtime_policy.WorkClass.background, policy.active_intent.work_class);
    try std.testing.expectEqual(runtime_policy.LifecycleTier.hidden_warm, policy.background_intent.lifecycle);
    try std.testing.expectEqual(runtime_policy.WorkClass.background, policy.background_intent.work_class);
    try std.testing.expectEqual(@as(usize, 1), policy.max_background_tabs_per_frame);
}
