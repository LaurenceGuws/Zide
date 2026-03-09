pub fn inputPressure(input_has_events: bool, terminal_input_activity: bool) bool {
    // Poll pressure should track terminal-relevant activity, not unrelated UI events.
    return terminal_input_activity or input_has_events;
}

pub fn pollWorkspace(workspace: anytype, input_active_index: ?usize, has_input: bool) !bool {
    const active_idx = input_active_index orelse 0;
    const active_session = if (input_active_index) |idx| workspace.sessionAt(idx) else null;
    const pubgen_pre = if (active_session) |s| s.publishedGeneration() else 0;
    _ = try workspace.pollForFrame(active_idx, has_input);
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
