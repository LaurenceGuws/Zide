pub fn inputPressure(input_has_events: bool, terminal_input_activity: bool) bool {
    // Poll pressure should track terminal-relevant activity, not unrelated UI events.
    return terminal_input_activity or input_has_events;
}

fn pollPolicy(comptime Policy: type, has_input: bool) Policy {
    return if (has_input)
        .{
            .has_input = true,
            .max_tabs_per_frame = 3,
            .max_background_tabs_per_frame = 1,
            .max_active_polls_per_frame = 2,
        }
    else
        .{
            .has_input = false,
            .max_tabs_per_frame = 6,
            .max_background_tabs_per_frame = 3,
            .max_active_polls_per_frame = 4,
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
