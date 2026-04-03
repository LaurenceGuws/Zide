const csi_mod = @import("../../protocol/csi.zig");

pub const TerminalModeSnapshot = struct {
    column_mode_132: bool,
    screen_reverse: bool,
    origin_mode: bool,
    cursor_blink: bool,
    cursor_visible: bool,
    reverse_wrap: bool,
    left_right_margin_mode_69: bool,
    alt_active: bool,
    save_cursor_mode_1048: bool,
    insert_mode: bool,
    local_echo_mode_12: bool,
    newline_mode: bool,
};

pub fn terminalModeSnapshot(self: anytype) TerminalModeSnapshot {
    const screen = self.core.activeScreen();
    return .{
        .column_mode_132 = self.core.column_mode_132,
        .screen_reverse = screen.screen_reverse,
        .origin_mode = screen.origin_mode,
        .cursor_blink = screen.cursor_style.blink,
        .cursor_visible = screen.cursor_visible,
        .reverse_wrap = screen.reverse_wrap,
        .left_right_margin_mode_69 = screen.left_right_margin_mode_69,
        .alt_active = self.core.active == .alt,
        .save_cursor_mode_1048 = screen.save_cursor_mode_1048,
        .insert_mode = screen.insert_mode,
        .local_echo_mode_12 = screen.local_echo_mode_12,
        .newline_mode = screen.newline_mode,
    };
}

pub fn decrqmPrivateTerminalModeState(snapshot: TerminalModeSnapshot, mode: i32) ?csi_mod.DecrpmState {
    return switch (mode) {
        3 => boolModeState(snapshot.column_mode_132),
        5 => boolModeState(snapshot.screen_reverse),
        6 => boolModeState(snapshot.origin_mode),
        12 => boolModeState(snapshot.cursor_blink),
        25 => boolModeState(snapshot.cursor_visible),
        45 => boolModeState(snapshot.reverse_wrap),
        47, 1047, 1049 => boolModeState(snapshot.alt_active),
        69 => boolModeState(snapshot.left_right_margin_mode_69),
        1048 => boolModeState(snapshot.save_cursor_mode_1048),
        else => null,
    };
}

pub fn decrqmAnsiTerminalModeState(snapshot: TerminalModeSnapshot, mode: i32) ?csi_mod.DecrpmState {
    return switch (mode) {
        4 => boolModeState(snapshot.insert_mode),
        12 => boolModeState(snapshot.local_echo_mode_12),
        20 => boolModeState(snapshot.newline_mode),
        else => null,
    };
}

fn boolModeState(enabled: bool) csi_mod.DecrpmState {
    return if (enabled) .set else .reset;
}
