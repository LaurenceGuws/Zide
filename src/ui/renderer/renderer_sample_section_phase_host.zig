const app_shell = @import("../../app_shell.zig");
const renderer_text_host = @import("renderer_text_host.zig");

const Color = app_shell.Color;

pub const TextOp = struct {
    text: []const u8,
    x: f32,
    y: f32,
    color: Color,
    bg: Color,
};

pub fn beginSampleSectionCommandGroup(renderer: anytype) void {
    _ = renderer;
}

pub fn endSampleSectionCommandGroup(renderer: anytype) void {
    _ = renderer;
}

pub fn replaySampleSectionTextOnBg(renderer: anytype, op: TextOp) void {
    renderer_text_host.drawTextOnBg(renderer, op.text, op.x, op.y, op.color, op.bg);
}

pub fn replaySampleSectionTextOps(renderer: anytype, ops: []const TextOp) void {
    beginSampleSectionCommandGroup(renderer);
    defer endSampleSectionCommandGroup(renderer);
    for (ops) |op| replaySampleSectionTextOnBg(renderer, op);
}
