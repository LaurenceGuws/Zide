const input_modes = @import("../core/input_modes.zig");
const parser_csi = @import("../parser/csi.zig");
const terminal_core_csi_input_modes = @import("../core/protocol/terminal_core_csi_input_modes.zig");
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
        if (terminal_core_csi_input_modes.applyPrivateInputMode(self, params[idx], enabled)) continue;
        switch (params[idx]) {
            3 => config.setColumnMode132Locked(self, enabled),
            2031 => self.session.interaction.host_contract.report_color_scheme_2031 = enabled,
            2048 => self.session.interaction.host_contract.inband_resize_notifications_2048 = enabled,
            5522 => self.session.interaction.host_contract.kitty_paste_events_5522 = enabled,
            else => {},
        }
    }
}
