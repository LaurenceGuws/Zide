const text_phase = @import("renderer_text_phase_group_host.zig");

pub const TextOp = text_phase.ReplayOp;

pub fn beginSampleSectionCommandGroup(renderer: anytype) void {
    text_phase.beginGroup(renderer, .sample_section);
}

pub fn endSampleSectionCommandGroup(renderer: anytype) void {
    text_phase.endGroup(renderer, .sample_section);
}

pub fn replaySampleSectionTextOnBg(renderer: anytype, op: TextOp) void {
    text_phase.replayOpOnBg(renderer, op);
}

pub fn replaySampleSectionTextOps(renderer: anytype, ops: []const TextOp) void {
    text_phase.replayOps(renderer, .sample_section, ops);
}

pub fn replaySampleSectionTextOpsWith(replayer: anytype, ops: []const TextOp) void {
    text_phase.replayOpsWith(replayer, .sample_section, ops);
}
