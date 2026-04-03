const terminal_core_protocol = @import("terminal_core_protocol.zig");

pub fn applyDecstrTerminalReset(self: anytype) void {
    self.core.resetParserState();
    self.core.clearSavedCharsetState();
    self.core.clearTitleBuffer();
    self.core.setDefaultTitle();
    self.session.interaction.protocol_modes.grapheme_cluster_shaping_2027 = false;
    self.core.primary.setGraphemeClusterShaping2027(false);
    self.core.alt.setGraphemeClusterShaping2027(false);
    self.core.column_mode_132 = false;
    self.core.activeScreen().resetState();
    terminal_core_protocol.clearAllKittyImages(self);
    self.core.activeScreen().markDirtyAllWithReason(.decstr_soft_reset, @src());
}
