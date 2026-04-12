pub const FrameFamily = enum {
    terminal,
    chrome_band,
    editor_row_band,
    sample_section,
};

pub const FrameFamilySummary = struct {
    pub const FamilyState = struct {
        touched: bool = false,
        presented: bool = false,
        presented_generation: ?u64 = null,
    };

    terminal: FamilyState = .{},
    chrome_band: FamilyState = .{},
    editor_row_band: FamilyState = .{},
    sample_section: FamilyState = .{},
};

pub fn finalizedFrameFamilySummary(current: FrameFamilySummary, submitted: bool) FrameFamilySummary {
    var summary = current;
    summary.terminal.presented = submitted and summary.terminal.touched;
    if (!summary.terminal.presented) summary.terminal.presented_generation = null;
    summary.chrome_band.presented = submitted and summary.chrome_band.touched;
    summary.chrome_band.presented_generation = null;
    summary.editor_row_band.presented = submitted and summary.editor_row_band.touched;
    summary.editor_row_band.presented_generation = null;
    summary.sample_section.presented = submitted and summary.sample_section.touched;
    summary.sample_section.presented_generation = null;
    return summary;
}

pub const FrameSubmission = struct {
    succeeded: bool,
    sequence: u64,
    family_summary: FrameFamilySummary = .{},
};

pub const FrameExecutionState = enum {
    not_attempted,
    ready,
    begin_failed,
    abandoned,
};

pub const FrameExecutionOutcomeKind = enum {
    not_attempted,
    begin_failed,
    abandoned,
    submitted,
    submit_failed,
};

pub const FrameExecutionOutcome = struct {
    kind: FrameExecutionOutcomeKind = .not_attempted,
    present_ms: f64 = 0.0,
};

pub const MainCompositionTarget = enum {
    default_target,
    offscreen_scene_target,
    backend_surface,
};
