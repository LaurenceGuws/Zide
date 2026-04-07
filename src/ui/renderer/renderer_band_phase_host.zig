const renderer_text_host = @import("renderer_text_host.zig");

pub fn beginBandCommandGroup(renderer: anytype) void {
    _ = renderer;
}

pub fn endBandCommandGroup(renderer: anytype) void {
    _ = renderer;
}

pub fn replayBandTextOnBg(renderer: anytype, text: []const u8, x: f32, y: f32, color: anytype, bg: anytype) void {
    renderer_text_host.drawTextOnBg(renderer, text, x, y, color, bg);
}

pub fn replayBandIconTextOnBg(renderer: anytype, text: []const u8, x: f32, y: f32, color: anytype, bg: anytype) void {
    renderer_text_host.drawIconTextOnBg(renderer, text, x, y, color, bg);
}
