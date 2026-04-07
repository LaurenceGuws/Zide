pub const FrameSubmission = struct {
    succeeded: bool,
    sequence: u64,
    terminal_presented: bool = false,
    terminal_presented_generation: ?u64 = null,
};

pub const PresentTrace = struct {
    pub const EditorImmediateSolidFamily = enum {
        none,
        overlay,
        row_base,
        pane_base,
        chrome_band,
    };

    frame_seq: u64 = 0,
    terminal_presentation_count: usize = 0,
    terminal_presented_generation: ?u64 = null,
    composition_clip_count: usize = 0,
    band_group_begin_count: usize = 0,
    band_group_end_count: usize = 0,
    sample_section_group_begin_count: usize = 0,
    sample_section_group_end_count: usize = 0,
    editor_row_band_group_begin_count: usize = 0,
    editor_row_band_group_end_count: usize = 0,
    gl_surface_immediate_solid_count: usize = 0,
    gl_surface_queued_replay_count: usize = 0,
    gl_surface_immediate_solid_in_band_group_count: usize = 0,
    gl_surface_immediate_solid_in_sample_section_group_count: usize = 0,
    gl_surface_immediate_solid_in_editor_row_band_group_count: usize = 0,
    gl_surface_immediate_solid_editor_overlay_count: usize = 0,
    gl_surface_immediate_solid_editor_row_base_count: usize = 0,
    gl_surface_immediate_solid_editor_pane_base_count: usize = 0,
    gl_surface_immediate_solid_chrome_band_count: usize = 0,
    gl_surface_immediate_solid_unattributed_count: usize = 0,
    editor_immediate_solid_family: EditorImmediateSolidFamily = .none,
    composition_full_pane_clear: bool = false,
    captured_path: ?[]const u8 = null,
};

pub const MainCompositionTarget = enum {
    default_target,
    offscreen_scene_target,
    backend_surface,
};

pub const PresentState = struct {
    frame_seq: u64 = 0,
    submission_sequence: u64 = 0,
    last_present_counter: u64 = 0,
    last_present_gap_ms: f64 = 0.0,
    last_swap_ms: f64 = 0.0,
    main_composition_target: MainCompositionTarget = .default_target,
    trace_current: PresentTrace = .{},
    trace_last: PresentTrace = .{},
    capture_path: ?[]const u8 = null,
    capture_armed: bool = false,
    capture_frame_seq: u64 = 0,
};

pub fn noteCompositionFullPaneClear(self: anytype) void {
    self.present.trace_current.composition_full_pane_clear = true;
}

pub fn noteCompositionClip(self: anytype) void {
    self.present.trace_current.composition_clip_count += 1;
}

pub fn noteBandCommandGroupBegin(self: anytype) void {
    self.present.trace_current.band_group_begin_count += 1;
}

pub fn noteBandCommandGroupEnd(self: anytype) void {
    self.present.trace_current.band_group_end_count += 1;
}

pub fn noteSampleSectionCommandGroupBegin(self: anytype) void {
    self.present.trace_current.sample_section_group_begin_count += 1;
}

pub fn noteSampleSectionCommandGroupEnd(self: anytype) void {
    self.present.trace_current.sample_section_group_end_count += 1;
}

pub fn noteEditorRowBandCommandGroupBegin(self: anytype) void {
    self.present.trace_current.editor_row_band_group_begin_count += 1;
}

pub fn noteEditorRowBandCommandGroupEnd(self: anytype) void {
    self.present.trace_current.editor_row_band_group_end_count += 1;
}

pub fn noteGlSurfaceImmediateSolid(self: anytype) void {
    var trace = &self.present.trace_current;
    trace.gl_surface_immediate_solid_count += 1;
    if (trace.band_group_begin_count > trace.band_group_end_count) {
        trace.gl_surface_immediate_solid_in_band_group_count += 1;
    }
    if (trace.sample_section_group_begin_count > trace.sample_section_group_end_count) {
        trace.gl_surface_immediate_solid_in_sample_section_group_count += 1;
    }
    if (trace.editor_row_band_group_begin_count > trace.editor_row_band_group_end_count) {
        trace.gl_surface_immediate_solid_in_editor_row_band_group_count += 1;
    }
    switch (trace.editor_immediate_solid_family) {
        .overlay => trace.gl_surface_immediate_solid_editor_overlay_count += 1,
        .row_base => trace.gl_surface_immediate_solid_editor_row_base_count += 1,
        .pane_base => trace.gl_surface_immediate_solid_editor_pane_base_count += 1,
        .chrome_band => trace.gl_surface_immediate_solid_chrome_band_count += 1,
        .none => trace.gl_surface_immediate_solid_unattributed_count += 1,
    }
}

pub fn noteGlSurfaceQueuedReplay(self: anytype) void {
    self.present.trace_current.gl_surface_queued_replay_count += 1;
}

pub fn setEditorImmediateSolidFamily(self: anytype, family: PresentTrace.EditorImmediateSolidFamily) void {
    self.present.trace_current.editor_immediate_solid_family = family;
}

pub fn clearEditorImmediateSolidFamily(self: anytype) void {
    self.present.trace_current.editor_immediate_solid_family = .none;
}

pub fn noteTerminalPresentation(self: anytype, generation: ?u64) void {
    self.present.trace_current.terminal_presentation_count += 1;
    if (generation) |value| self.present.trace_current.terminal_presented_generation = value;
}

pub fn noteEditorSurfaceFullPaneClear(self: anytype, x: i32, y: i32, w: i32, h: i32) void {
    if (x != 0 or y != 0 or w != self.target_width or h != self.target_height) return;
    noteCompositionFullPaneClear(self);
}

pub fn performanceDeltaMs(start: u64, end: u64, freq: f64) f64 {
    if (end <= start or freq <= 0.0) return 0.0;
    return (@as(f64, @floatFromInt(end - start)) * 1000.0) / freq;
}
