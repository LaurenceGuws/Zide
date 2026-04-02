const stream_mod = @import("../../parser/stream.zig");
const parser_csi = @import("../../parser/csi.zig");
const parser_mod = @import("../../parser/parser.zig");
const control_handlers = @import("control_handlers.zig");
const terminal_core_text = @import("terminal_core_text.zig");
const protocol_csi = @import("../../protocol/csi.zig");
const osc = @import("../../protocol/osc.zig");
const dcs_apc = @import("../../protocol/dcs_apc.zig");

pub fn handleStreamEvent(self: anytype, event: stream_mod.StreamEvent) void {
    switch (event) {
        .codepoint => |cp| terminal_core_text.handleCodepoint(self, @intCast(cp)),
        .control => |c| control_handlers.handleControl(self, c),
        .invalid => terminal_core_text.handleCodepoint(self, 0xFFFD),
    }
}

pub fn handleAsciiSlice(self: anytype, bytes: []const u8) void {
    terminal_core_text.handleAsciiSlice(self, bytes);
}

pub fn handleCsi(self: anytype, action: parser_csi.CsiAction) void {
    protocol_csi.handleCsi(self, action);
}

pub fn handleOsc(self: anytype, payload: []const u8, terminator: parser_mod.OscTerminator) void {
    osc.parseOsc(self, payload, terminator);
}

pub fn handleApc(self: anytype, payload: []const u8) void {
    dcs_apc.parseApc(self, payload);
}

pub fn handleDcs(self: anytype, payload: []const u8) void {
    dcs_apc.parseDcs(self, payload);
}
