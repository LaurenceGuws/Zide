const terminal_core_osc_semantic = @import("../core/protocol/terminal_core_osc_semantic.zig");

pub fn parseSemanticPrompt(self: anytype, text: []const u8) void {
    terminal_core_osc_semantic.parseSemanticPrompt(self, text);
}

pub fn parseUserVar(self: anytype, text: []const u8) void {
    terminal_core_osc_semantic.parseUserVar(self, text);
}
