const terminal_core_csi_input_modes = @import("../protocol/terminal_core_csi_input_modes.zig");
const session_input = @import("input.zig");
const session_interaction = @import("interaction.zig");

pub fn setGraphemeClusterShaping2027(self: anytype, enabled: bool) void {
    self.session.interaction.protocol_modes.grapheme_cluster_shaping_2027 = enabled;
    self.core.primary.setGraphemeClusterShaping2027(enabled);
    self.core.alt.setGraphemeClusterShaping2027(enabled);
}

pub fn inputModeSnapshot(self: anytype) terminal_core_csi_input_modes.InputModeSnapshot {
    return .{
        .app_cursor_keys = session_input.appCursorKeysEnabled(self),
        .auto_repeat = session_interaction.autoRepeatEnabled(self),
        .mouse_mode_x10 = session_interaction.mouseModeX10Enabled(self),
        .app_keypad = session_input.appKeypadEnabled(self),
        .mouse_mode_button = session_interaction.mouseModeButtonEnabled(self),
        .mouse_mode_any = session_interaction.mouseModeAnyEnabled(self),
        .focus_reporting = session_interaction.focusReportingEnabled(self),
        .mouse_mode_sgr = session_interaction.mouseModeSgrEnabled(self),
        .mouse_alternate_scroll = session_interaction.mouseAlternateScrollEnabled(self),
        .mouse_mode_sgr_pixels = session_interaction.mouseModeSgrPixelsEnabled(self),
        .bracketed_paste = session_interaction.bracketedPasteEnabled(self),
        .sync_updates_active = self.core.sync_updates_active,
        .grapheme_cluster_shaping_2027 = self.session.interaction.protocol_modes.grapheme_cluster_shaping_2027,
    };
}
