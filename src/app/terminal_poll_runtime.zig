const std = @import("std");

pub const PollProfile = struct {
    max_tabs_per_frame: usize,
    max_background_tabs_per_frame: usize,
    max_active_polls_per_frame: usize,
};

pub const PollProfiles = struct {
    interactive: PollProfile,
    idle: PollProfile,

    pub fn select(self: PollProfiles, has_input: bool) PollProfile {
        return if (has_input) self.interactive else self.idle;
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
    const profile = default_poll_profiles.select(has_input);
    return .{
        .has_input = has_input,
        .max_tabs_per_frame = profile.max_tabs_per_frame,
        .max_background_tabs_per_frame = profile.max_background_tabs_per_frame,
        .max_active_polls_per_frame = profile.max_active_polls_per_frame,
    };
}

pub fn pollWorkspace(workspace: anytype, input_active_index: ?usize, has_input: bool) !bool {
    const result = try workspace.pollForFrame(input_active_index, pollPolicy(@TypeOf(workspace.*).PollPolicy, has_input));
    return result.active_published_changed;
}

pub fn pollSingleSession(term: anytype, has_input: bool) !bool {
    const pubgen_pre = term.publishedGeneration();
    if (term.hasData()) {
        term.setInputPressure(has_input);
        try term.poll();
    }
    return term.publishedGeneration() != pubgen_pre;
}

test "default poll profiles select interactive and idle budgets explicitly" {
    const interactive = default_poll_profiles.select(true);
    try std.testing.expectEqual(@as(usize, 3), interactive.max_tabs_per_frame);
    try std.testing.expectEqual(@as(usize, 1), interactive.max_background_tabs_per_frame);
    try std.testing.expectEqual(@as(usize, 2), interactive.max_active_polls_per_frame);

    const idle = default_poll_profiles.select(false);
    try std.testing.expectEqual(@as(usize, 6), idle.max_tabs_per_frame);
    try std.testing.expectEqual(@as(usize, 3), idle.max_background_tabs_per_frame);
    try std.testing.expectEqual(@as(usize, 4), idle.max_active_polls_per_frame);
}
