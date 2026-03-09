pub fn inputPressure(input_has_events: bool, terminal_input_activity: bool) bool {
    // Poll pressure should track terminal-relevant activity, not unrelated UI events.
    return terminal_input_activity or input_has_events;
}

pub fn pollWorkspace(workspace: anytype, input_active_index: ?usize, has_input: bool) !bool {
    const active_idx = input_active_index orelse 0;
    const active_session = if (input_active_index) |idx| workspace.sessionAt(idx) else null;
    const pubgen_pre = if (active_session) |s| s.publishedGeneration() else 0;
    const PollBudget = @TypeOf(workspace.*).PollBudget;
    const budget: PollBudget = budgetForInputPressure(PollBudget, has_input);
    _ = try workspace.pollBudgeted(active_idx, has_input, budget);
    const pubgen_post = if (active_session) |s| s.publishedGeneration() else 0;
    return pubgen_post != pubgen_pre;
}

pub fn pollSingleSession(term: anytype, has_input: bool) !bool {
    const pubgen_pre = term.publishedGeneration();
    if (term.hasData()) {
        term.setInputPressure(has_input);
        try term.poll();
    }
    return term.publishedGeneration() != pubgen_pre;
}

fn budgetForInputPressure(comptime PollBudget: type, has_input: bool) PollBudget {
    return if (has_input)
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
}
