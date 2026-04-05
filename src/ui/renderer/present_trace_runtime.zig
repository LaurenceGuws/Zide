pub const PresentableKind = enum {
    editor,
    terminal,
};

pub const FrameSubmission = struct {
    succeeded: bool,
    sequence: u64,
    terminal_presented: bool = false,
    terminal_presented_generation: ?u64 = null,
};

pub const PresentTrace = struct {
    frame_seq: u64 = 0,
    editor_presentable_update_count: usize = 0,
    editor_presentable_draw_count: usize = 0,
    terminal_presentation_count: usize = 0,
    terminal_presented_generation: ?u64 = null,
    composition_clip_count: usize = 0,
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
    drawing_editor_surface: bool = false,
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

pub fn notePresentableUpdate(self: anytype, presentable: PresentableKind) void {
    switch (presentable) {
        .editor => {
            self.present.drawing_editor_surface = true;
            self.present.trace_current.editor_presentable_update_count += 1;
        },
        .terminal => {},
    }
}

pub fn notePresentableDraw(self: anytype, presentable: PresentableKind, generation: ?u64) void {
    switch (presentable) {
        .editor => self.present.trace_current.editor_presentable_draw_count += 1,
        .terminal => noteTerminalPresentation(self, generation),
    }
}

pub fn noteTerminalPresentation(self: anytype, generation: ?u64) void {
    self.present.trace_current.terminal_presentation_count += 1;
    if (generation) |value| self.present.trace_current.terminal_presented_generation = value;
}

pub fn notePresentableEnded(self: anytype, presentable: PresentableKind) void {
    switch (presentable) {
        .editor => self.present.drawing_editor_surface = false,
        .terminal => {},
    }
}

pub fn noteEditorSurfaceFullPaneClear(self: anytype, x: i32, y: i32, w: i32, h: i32) void {
    if (!self.present.drawing_editor_surface) return;
    if (x != 0 or y != 0 or w != self.target_width or h != self.target_height) return;
    noteCompositionFullPaneClear(self);
}

pub fn performanceDeltaMs(start: u64, end: u64, freq: f64) f64 {
    if (end <= start or freq <= 0.0) return 0.0;
    return (@as(f64, @floatFromInt(end - start)) * 1000.0) / freq;
}
