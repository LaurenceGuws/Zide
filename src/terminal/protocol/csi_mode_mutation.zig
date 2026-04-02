const input_modes = @import("../core/input_modes.zig");
const parser_csi = @import("../parser/csi.zig");
const terminal_publication = @import("../core/publication/terminal_publication.zig");
const terminal_core_modes = @import("../core/terminal_core_modes.zig");
const config = @import("../core/session/config.zig");
const mode_effects = @import("../core/session/mode_effects.zig");

pub fn applyModeMutation(
    self: anytype,
    action: parser_csi.CsiAction,
    param_len: usize,
    params: [parser_csi.max_params]i32,
    enabled: bool,
) void {
    if (!action.private) {
        applyAnsiModeMutation(self, param_len, params, enabled);
        return;
    }
    if (action.leader == '?') {
        applyPrivateModeMutation(self, param_len, params, enabled);
    }
}

fn applyAnsiModeMutation(self: anytype, param_len: usize, params: [parser_csi.max_params]i32, enabled: bool) void {
    var idx: u8 = 0;
    while (idx < param_len and idx < params.len) : (idx += 1) {
        switch (params[idx]) {
            4 => self.core.activeScreen().*.setInsertMode(enabled),
            12 => self.core.activeScreen().*.setLocalEchoMode12(enabled),
            20 => self.core.activeScreen().*.setNewlineMode(enabled),
            else => {},
        }
    }
}

fn applyPrivateModeMutation(self: anytype, param_len: usize, params: [parser_csi.max_params]i32, enabled: bool) void {
    var idx: u8 = 0;
    while (idx < param_len and idx < params.len) : (idx += 1) {
        switch (params[idx]) {
            1 => input_modes.setAppCursorKeysLocked(self, enabled),
            3 => config.setColumnMode132Locked(self, enabled),
            5 => self.core.activeScreen().*.setScreenReverse(enabled),
            6 => self.core.activeScreen().*.setOriginMode(enabled),
            7 => self.core.activeScreen().*.setAutowrap(enabled),
            8 => input_modes.setAutoRepeatLocked(self, enabled),
            9 => input_modes.setMouseModeX10Locked(self, enabled),
            12 => self.core.activeScreen().*.setCursorBlink(enabled),
            25 => self.core.activeScreen().setCursorVisible(enabled),
            45 => self.core.activeScreen().*.setReverseWrap(enabled),
            47 => if (enabled) mode_effects.enterAltScreen(self, false, false) else mode_effects.exitAltScreen(self, false),
            69 => self.core.activeScreen().*.setLeftRightMarginMode69(enabled),
            1000 => input_modes.setMouseModeX10Locked(self, enabled),
            1002 => input_modes.setMouseModeButtonLocked(self, enabled),
            1003 => input_modes.setMouseModeAnyLocked(self, enabled),
            1004 => input_modes.setFocusReportingLocked(self, enabled),
            1006 => input_modes.setMouseModeSgrLocked(self, enabled),
            1007 => input_modes.setMouseAlternateScrollLocked(self, enabled),
            1016 => input_modes.setMouseModeSgrPixelsLocked(self, enabled),
            1047 => if (enabled) mode_effects.enterAltScreen(self, true, false) else mode_effects.exitAltScreen(self, false),
            1048 => {
                if (enabled) {
                    terminal_core_modes.saveCursor(self);
                } else {
                    terminal_core_modes.restoreCursor(self);
                }
                self.core.activeScreen().*.setSaveCursorMode1048(enabled);
            },
            1049 => if (enabled) mode_effects.enterAltScreen(self, true, true) else mode_effects.exitAltScreen(self, true),
            2004 => input_modes.setBracketedPasteLocked(self, enabled),
            2026 => terminal_publication.setSyncUpdatesLocked(self, enabled),
            2027 => {
                self.interaction.grapheme_cluster_shaping_2027 = enabled;
                self.core.primary.setGraphemeClusterShaping2027(enabled);
                self.core.alt.setGraphemeClusterShaping2027(enabled);
            },
            2031 => self.interaction.report_color_scheme_2031 = enabled,
            2048 => self.interaction.inband_resize_notifications_2048 = enabled,
            5522 => self.interaction.kitty_paste_events_5522 = enabled,
            else => {},
        }
    }
}
