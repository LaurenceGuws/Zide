const parser_csi = @import("../parser/csi.zig");
const csi_mod = @import("csi.zig");
const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const session_interaction = @import("../core/session/interaction.zig");
const session_input = @import("../core/session/input.zig");

pub const ModeSnapshot = struct {
    app_cursor_keys: bool,
    column_mode_132: bool,
    screen_reverse: bool,
    origin_mode: bool,
    auto_wrap: bool,
    auto_repeat: bool,
    mouse_mode_x10: bool,
    cursor_blink: bool,
    cursor_visible: bool,
    reverse_wrap: bool,
    left_right_margin_mode_69: bool,
    alt_active: bool,
    save_cursor_mode_1048: bool,
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
    report_color_scheme_2031: bool,
    inband_resize_notifications_2048: bool,
    kitty_paste_events_5522: bool,
    insert_mode: bool,
    local_echo_mode_12: bool,
    newline_mode: bool,
};

pub fn modeSnapshot(self: anytype) ModeSnapshot {
    const screen = self.core.activeScreen();
    const input_snapshot = self.interaction.input_snapshot;
    return .{
        .app_cursor_keys = session_input.appCursorKeysEnabled(self),
        .column_mode_132 = self.core.column_mode_132,
        .screen_reverse = screen.screen_reverse,
        .origin_mode = screen.origin_mode,
        .auto_wrap = screen.auto_wrap,
        .auto_repeat = session_interaction.autoRepeatEnabled(self),
        .mouse_mode_x10 = input_snapshot.mouse_mode_x10.load(.acquire),
        .cursor_blink = screen.cursor_style.blink,
        .cursor_visible = screen.cursor_visible,
        .reverse_wrap = screen.reverse_wrap,
        .left_right_margin_mode_69 = screen.left_right_margin_mode_69,
        .alt_active = self.core.active == .alt,
        .save_cursor_mode_1048 = screen.save_cursor_mode_1048,
        .app_keypad = session_input.appKeypadEnabled(self),
        .mouse_mode_button = input_snapshot.mouse_mode_button.load(.acquire),
        .mouse_mode_any = input_snapshot.mouse_mode_any.load(.acquire),
        .focus_reporting = session_interaction.focusReportingEnabled(self),
        .mouse_mode_sgr = input_snapshot.mouse_mode_sgr.load(.acquire),
        .mouse_alternate_scroll = input_snapshot.mouse_alternate_scroll.load(.acquire),
        .mouse_mode_sgr_pixels = input_snapshot.mouse_mode_sgr_pixels_1016.load(.acquire),
        .bracketed_paste = session_interaction.bracketedPasteEnabled(self),
        .sync_updates_active = self.core.sync_updates_active,
        .grapheme_cluster_shaping_2027 = self.interaction.grapheme_cluster_shaping_2027,
        .report_color_scheme_2031 = self.interaction.report_color_scheme_2031,
        .inband_resize_notifications_2048 = self.interaction.inband_resize_notifications_2048,
        .kitty_paste_events_5522 = self.interaction.kitty_paste_events_5522,
        .insert_mode = screen.insert_mode,
        .local_echo_mode_12 = screen.local_echo_mode_12,
        .newline_mode = screen.newline_mode,
    };
}

pub fn decrqmPrivateModeState(snapshot: ModeSnapshot, mode: i32) csi_mod.DecrpmState {
    return switch (mode) {
        1 => boolModeState(snapshot.app_cursor_keys),
        3 => boolModeState(snapshot.column_mode_132),
        5 => boolModeState(snapshot.screen_reverse),
        6 => boolModeState(snapshot.origin_mode),
        7 => boolModeState(snapshot.auto_wrap),
        8 => boolModeState(snapshot.auto_repeat),
        9 => boolModeState(snapshot.mouse_mode_x10),
        12 => boolModeState(snapshot.cursor_blink),
        25 => boolModeState(snapshot.cursor_visible),
        45 => boolModeState(snapshot.reverse_wrap),
        69 => boolModeState(snapshot.left_right_margin_mode_69),
        47, 1047, 1049 => boolModeState(snapshot.alt_active),
        1048 => boolModeState(snapshot.save_cursor_mode_1048),
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
        2031 => boolModeState(snapshot.report_color_scheme_2031),
        2048 => boolModeState(snapshot.inband_resize_notifications_2048),
        5522 => boolModeState(snapshot.kitty_paste_events_5522),
        else => .not_recognized,
    };
}

pub fn decrqmAnsiModeState(snapshot: ModeSnapshot, mode: i32) csi_mod.DecrpmState {
    return switch (mode) {
        4 => boolModeState(snapshot.insert_mode),
        12 => boolModeState(snapshot.local_echo_mode_12),
        20 => boolModeState(snapshot.newline_mode),
        else => .not_recognized,
    };
}

pub fn writeDecrqmReplyWithWriter(writer: anytype, private: bool, mode: i32, state: csi_mod.DecrpmState) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [32]u8 = undefined;
    const seq = if (private)
        std.fmt.bufPrint(&buf, "\x1b[?{d};{d}$y", .{ mode, @intFromEnum(state) })
    else
        std.fmt.bufPrint(&buf, "\x1b[{d};{d}$y", .{ mode, @intFromEnum(state) });
    const bytes = seq catch |err| {
        log.logf(.warning, "DECRQM reply format failed mode={d} private={d}: {s}", .{ mode, @as(u8, @intFromBool(private)), @errorName(err) });
        return false;
    };
    _ = writer.write(bytes) catch |err| {
        log.logf(.warning, "DECRQM reply write failed mode={d} private={d}: {s}", .{ mode, @as(u8, @intFromBool(private)), @errorName(err) });
        return false;
    };
    return true;
}

fn boolModeState(enabled: bool) csi_mod.DecrpmState {
    return if (enabled) .set else .reset;
}
