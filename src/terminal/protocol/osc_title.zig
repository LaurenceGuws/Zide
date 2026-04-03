const terminal_core_osc_metadata = @import("../core/protocol/terminal_core_osc_metadata.zig");

pub fn setTitle(self: anytype, text: []const u8) void {
    terminal_core_osc_metadata.setTitle(self, text);
}
