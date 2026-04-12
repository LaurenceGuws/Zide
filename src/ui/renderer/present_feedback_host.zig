const present_feedback_state = @import("present_feedback_state.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");

pub fn noteFrameFamilyTouch(self: anytype, family: present_feedback_state.FrameFamily) void {
    switch (family) {
        .terminal => self.present.frame_family_current.terminal.touched = true,
        .chrome_band => self.present.frame_family_current.chrome_band.touched = true,
        .editor_row_band => self.present.frame_family_current.editor_row_band.touched = true,
        .sample_section => self.present.frame_family_current.sample_section.touched = true,
    }
    present_trace_runtime.noteFrameFamilyTouch(self, family);
}

pub fn noteTerminalPresentation(self: anytype, generation: ?u64) void {
    noteFrameFamilyTouch(self, .terminal);
    if (generation) |value| {
        self.present.frame_family_current.terminal.presented_generation = value;
        present_trace_runtime.noteTerminalPresentedGeneration(self, value);
    }
}
