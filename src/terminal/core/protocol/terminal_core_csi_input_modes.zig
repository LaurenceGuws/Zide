const input_modes = @import("../input_modes.zig");
const sync_updates = @import("sync_updates.zig");
const csi_mod = @import("../../protocol/csi.zig");

pub const InputModeSnapshot = struct {
    app_cursor_keys: bool,
    auto_repeat: bool,
    mouse_mode_x10: bool,
    app_keypad: bool,
    mouse_mode_button: bool,
    mouse_mode_any: bool,
    focus_reporting: bool,
    mouse_mode_sgr: bool,
    mouse_alternate_scroll: bool,
    mouse_mode_sgr_pixels: bool,
    bracketed_paste: bool,
    sync_updates_active: bool,
    grapheme_cluster_shaping_2027: bool,
};

pub fn applyPrivateInputMode(self: anytype, mode: i32, enabled: bool) bool {
    switch (mode) {
        1 => input_modes.setAppCursorKeysLocked(self, enabled),
        8 => input_modes.setAutoRepeatLocked(self, enabled),
        9 => input_modes.setMouseModeX10Locked(self, enabled),
        1000 => input_modes.setMouseModeX10Locked(self, enabled),
        1002 => input_modes.setMouseModeButtonLocked(self, enabled),
        1003 => input_modes.setMouseModeAnyLocked(self, enabled),
        1004 => input_modes.setFocusReportingLocked(self, enabled),
        1006 => input_modes.setMouseModeSgrLocked(self, enabled),
        1007 => input_modes.setMouseAlternateScrollLocked(self, enabled),
        1016 => input_modes.setMouseModeSgrPixelsLocked(self, enabled),
        2004 => input_modes.setBracketedPasteLocked(self, enabled),
        2026 => sync_updates.setLocked(self, enabled),
        2027 => {
            self.session.interaction.protocol_modes.grapheme_cluster_shaping_2027 = enabled;
            self.core.primary.setGraphemeClusterShaping2027(enabled);
            self.core.alt.setGraphemeClusterShaping2027(enabled);
        },
        66 => input_modes.setKeypadModeLocked(self, enabled),
        else => return false,
    }
    return true;
}

pub fn inputModeSnapshot(self: anytype) InputModeSnapshot {
    return .{
        .app_cursor_keys = input_modes.appCursorKeysEnabled(self),
        .auto_repeat = self.session.interaction.derived_snapshot.input.auto_repeat.load(.acquire),
        .mouse_mode_x10 = self.session.interaction.derived_snapshot.input.mouse_mode_x10.load(.acquire),
        .app_keypad = input_modes.appKeypadEnabled(self),
        .mouse_mode_button = self.session.interaction.derived_snapshot.input.mouse_mode_button.load(.acquire),
        .mouse_mode_any = self.session.interaction.derived_snapshot.input.mouse_mode_any.load(.acquire),
        .focus_reporting = self.session.interaction.derived_snapshot.input.focus_reporting.load(.acquire),
        .mouse_mode_sgr = self.session.interaction.derived_snapshot.input.mouse_mode_sgr.load(.acquire),
        .mouse_alternate_scroll = self.session.interaction.derived_snapshot.input.mouse_alternate_scroll.load(.acquire),
        .mouse_mode_sgr_pixels = self.session.interaction.derived_snapshot.input.mouse_mode_sgr_pixels_1016.load(.acquire),
        .bracketed_paste = self.session.interaction.derived_snapshot.input.bracketed_paste.load(.acquire),
        .sync_updates_active = self.core.sync_updates_active,
        .grapheme_cluster_shaping_2027 = self.session.interaction.protocol_modes.grapheme_cluster_shaping_2027,
    };
}

pub fn decrqmPrivateInputModeState(snapshot: InputModeSnapshot, mode: i32) ?csi_mod.DecrpmState {
    return switch (mode) {
        1 => boolModeState(snapshot.app_cursor_keys),
        8 => boolModeState(snapshot.auto_repeat),
        9 => boolModeState(snapshot.mouse_mode_x10),
        66 => boolModeState(snapshot.app_keypad),
        67 => .permanently_reset,
        1000 => boolModeState(snapshot.mouse_mode_x10),
        1001 => .permanently_reset,
        1002 => boolModeState(snapshot.mouse_mode_button),
        1003 => boolModeState(snapshot.mouse_mode_any),
        1004 => boolModeState(snapshot.focus_reporting),
        1005 => .permanently_reset,
        1006 => boolModeState(snapshot.mouse_mode_sgr),
        1007 => boolModeState(snapshot.mouse_alternate_scroll),
        1015 => .permanently_reset,
        1016 => boolModeState(snapshot.mouse_mode_sgr_pixels),
        1034 => .permanently_reset,
        1035 => .permanently_reset,
        1036 => .permanently_reset,
        1042 => .permanently_reset,
        1070 => .permanently_reset,
        2004 => boolModeState(snapshot.bracketed_paste),
        2026 => boolModeState(snapshot.sync_updates_active),
        2027 => boolModeState(snapshot.grapheme_cluster_shaping_2027),
        else => null,
    };
}

fn boolModeState(enabled: bool) csi_mod.DecrpmState {
    return if (enabled) .set else .reset;
}
