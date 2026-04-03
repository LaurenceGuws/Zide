const terminal_core_protocol = @import("terminal_core_protocol.zig");
const protocol_state = @import("../session/protocol_state.zig");

pub fn applyDecstrTerminalReset(self: anytype) void {
    self.core.resetParserState();
    self.core.clearSavedCharsetState();
    self.core.clearTitleBuffer();
    self.core.setDefaultTitle();
    protocol_state.setGraphemeClusterShaping2027(self, false);
    self.core.column_mode_132 = false;
    self.core.activeScreen().resetState();
    terminal_core_protocol.clearAllKittyImages(self);
    self.core.activeScreen().markDirtyAllWithReason(.decstr_soft_reset, @src());
}
