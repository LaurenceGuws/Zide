const text_phase = @import("renderer_text_phase_group_host.zig");

pub const TextKind = text_phase.TextKind;
pub const ReplayOp = text_phase.ReplayOp;

pub fn beginBandCommandGroup(renderer: anytype) void {
    text_phase.beginGroup(renderer, .chrome_band);
}

pub fn endBandCommandGroup(renderer: anytype) void {
    text_phase.endGroup(renderer, .chrome_band);
}

pub fn replayBandTextOnBg(renderer: anytype, text: []const u8, x: f32, y: f32, color: anytype, bg: anytype) void {
    text_phase.replayOpOnBg(renderer, .{
        .kind = .text,
        .text = text,
        .x = x,
        .y = y,
        .color = color,
        .bg = bg,
    });
}

pub fn replayBandIconTextOnBg(renderer: anytype, text: []const u8, x: f32, y: f32, color: anytype, bg: anytype) void {
    text_phase.replayOpOnBg(renderer, .{
        .kind = .icon,
        .text = text,
        .x = x,
        .y = y,
        .color = color,
        .bg = bg,
    });
}

pub fn replayBandOpsWith(replayer: anytype, ops: []const ReplayOp) void {
    text_phase.replayOpsWith(replayer, .chrome_band, ops);
}

pub fn replayBandOps(renderer: anytype, ops: []const ReplayOp) void {
    text_phase.replayOps(renderer, .chrome_band, ops);
}
