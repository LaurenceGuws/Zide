const input_modes = @import("../core/input_modes.zig");
const parser_csi = @import("../parser/csi.zig");
const sync_updates = @import("../core/protocol/sync_updates.zig");
const terminal_core_csi_modes = @import("../core/protocol/terminal_core_csi_modes.zig");
const config = @import("../core/session/config.zig");

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
        _ = terminal_core_csi_modes.applyAnsiTerminalMode(self, params[idx], enabled);
    }
}

fn applyPrivateModeMutation(self: anytype, param_len: usize, params: [parser_csi.max_params]i32, enabled: bool) void {
    var idx: u8 = 0;
    while (idx < param_len and idx < params.len) : (idx += 1) {
        if (terminal_core_csi_modes.applyPrivateTerminalMode(self, params[idx], enabled)) continue;
        switch (params[idx]) {
            1 => input_modes.setAppCursorKeysLocked(self, enabled),
            3 => config.setColumnMode132Locked(self, enabled),
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
            2031 => self.session.interaction.host_contract.report_color_scheme_2031 = enabled,
            2048 => self.session.interaction.host_contract.inband_resize_notifications_2048 = enabled,
            5522 => self.session.interaction.host_contract.kitty_paste_events_5522 = enabled,
            else => {},
        }
    }
}
