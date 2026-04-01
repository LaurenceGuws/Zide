const parser_csi = @import("../parser/csi.zig");
const terminal_core_modes = @import("../core/terminal_core_modes.zig");

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
            4 => self.activeScreen().*.setInsertMode(enabled),
            12 => self.activeScreen().*.setLocalEchoMode12(enabled),
            20 => self.activeScreen().*.setNewlineMode(enabled),
            else => {},
        }
    }
}

fn applyPrivateModeMutation(self: anytype, param_len: usize, params: [parser_csi.max_params]i32, enabled: bool) void {
    var idx: u8 = 0;
    while (idx < param_len and idx < params.len) : (idx += 1) {
        switch (params[idx]) {
            1 => self.setAppCursorKeysLocked(enabled),
            3 => self.setColumnMode132Locked(enabled),
            5 => self.activeScreen().*.setScreenReverse(enabled),
            6 => self.activeScreen().*.setOriginMode(enabled),
            7 => self.activeScreen().*.setAutowrap(enabled),
            8 => self.setAutoRepeatLocked(enabled),
            9 => self.setMouseModeX10Locked(enabled),
            12 => self.activeScreen().*.setCursorBlink(enabled),
            25 => self.activeScreen().setCursorVisible(enabled),
            45 => self.activeScreen().*.setReverseWrap(enabled),
            47 => if (enabled) self.enterAltScreen(false, false) else self.exitAltScreen(false),
            69 => self.activeScreen().*.setLeftRightMarginMode69(enabled),
            1000 => self.setMouseModeX10Locked(enabled),
            1002 => self.setMouseModeButtonLocked(enabled),
            1003 => self.setMouseModeAnyLocked(enabled),
            1004 => self.setFocusReportingLocked(enabled),
            1006 => self.setMouseModeSgrLocked(enabled),
            1007 => self.setMouseAlternateScrollLocked(enabled),
            1016 => self.setMouseModeSgrPixelsLocked(enabled),
            1047 => if (enabled) self.enterAltScreen(true, false) else self.exitAltScreen(false),
            1048 => {
                if (enabled) {
                    terminal_core_modes.saveCursor(self);
                } else {
                    terminal_core_modes.restoreCursor(self);
                }
                self.activeScreen().*.setSaveCursorMode1048(enabled);
            },
            1049 => if (enabled) self.enterAltScreen(true, true) else self.exitAltScreen(true),
            2004 => self.setBracketedPasteLocked(enabled),
            2026 => self.setSyncUpdatesLocked(enabled),
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
