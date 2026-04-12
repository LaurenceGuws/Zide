const present_feedback_state = @import("present_feedback_state.zig");
const present_capture_state = @import("present_capture_state.zig");

pub const PresentTrace = struct {
    frame_seq: u64 = 0,
    terminal_presentation_count: usize = 0,
    terminal_presented_generation: ?u64 = null,
    chrome_band_touch_count: usize = 0,
    editor_row_band_touch_count: usize = 0,
    sample_section_touch_count: usize = 0,
    composition_clip_count: usize = 0,
    band_group_begin_count: usize = 0,
    band_group_end_count: usize = 0,
    sample_section_group_begin_count: usize = 0,
    sample_section_group_end_count: usize = 0,
    editor_row_band_group_begin_count: usize = 0,
    editor_row_band_group_end_count: usize = 0,
    /// OpenGL: `SurfaceDraw.solid` records accepted into the deferred queue this frame.
    gl_surface_solid_enqueue_count: usize = 0,
    /// OpenGL: individual draws executed when the deferred queue is replayed.
    gl_surface_queued_replay_count: usize = 0,
    composition_full_pane_clear: bool = false,
    captured_path: ?[]const u8 = null,
};

pub const PresentState = struct {
    frame_seq: u64 = 0,
    submission_sequence: u64 = 0,
    frame_execution_state: present_feedback_state.FrameExecutionState = .not_attempted,
    last_present_counter: u64 = 0,
    last_present_gap_ms: f64 = 0.0,
    last_swap_ms: f64 = 0.0,
    main_composition_target: present_feedback_state.MainCompositionTarget = .default_target,
    frame_family_current: present_feedback_state.FrameFamilySummary = .{},
    trace_enabled: bool = false,
    trace_current: PresentTrace = .{},
    trace_last: PresentTrace = .{},
    capture: present_capture_state.PresentCaptureState = .{},
};

pub fn noteCompositionFullPaneClear(self: anytype) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.composition_full_pane_clear = true;
}

pub fn noteCompositionClip(self: anytype) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.composition_clip_count += 1;
}

pub fn noteBandCommandGroupBegin(self: anytype) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.band_group_begin_count += 1;
}

pub fn noteBandCommandGroupEnd(self: anytype) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.band_group_end_count += 1;
}

pub fn noteFrameFamilyTouch(self: anytype, family: present_feedback_state.FrameFamily) void {
    if (!self.present.trace_enabled) return;
    switch (family) {
        .terminal => {
            self.present.trace_current.terminal_presentation_count += 1;
        },
        .chrome_band => {
            self.present.trace_current.chrome_band_touch_count += 1;
        },
        .editor_row_band => {
            self.present.trace_current.editor_row_band_touch_count += 1;
        },
        .sample_section => {
            self.present.trace_current.sample_section_touch_count += 1;
        },
    }
}

pub fn noteSampleSectionCommandGroupBegin(self: anytype) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.sample_section_group_begin_count += 1;
}

pub fn noteSampleSectionCommandGroupEnd(self: anytype) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.sample_section_group_end_count += 1;
}

pub fn noteEditorRowBandCommandGroupBegin(self: anytype) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.editor_row_band_group_begin_count += 1;
}

pub fn noteEditorRowBandCommandGroupEnd(self: anytype) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.editor_row_band_group_end_count += 1;
}

pub fn noteGlSurfaceSolidEnqueue(self: anytype) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.gl_surface_solid_enqueue_count += 1;
}

pub fn noteGlSurfaceQueuedReplay(self: anytype) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.gl_surface_queued_replay_count += 1;
}

pub fn noteTerminalPresentedGeneration(self: anytype, generation: u64) void {
    if (!self.present.trace_enabled) return;
    self.present.trace_current.terminal_presented_generation = generation;
}

pub fn noteEditorSurfaceFullPaneClear(self: anytype, x: i32, y: i32, w: i32, h: i32) void {
    if (x != 0 or y != 0 or w != self.target_width or h != self.target_height) return;
    noteCompositionFullPaneClear(self);
}

pub fn performanceDeltaMs(start: u64, end: u64, freq: f64) f64 {
    if (end <= start or freq <= 0.0) return 0.0;
    return (@as(f64, @floatFromInt(end - start)) * 1000.0) / freq;
}
