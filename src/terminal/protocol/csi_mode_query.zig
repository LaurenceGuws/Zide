const parser_csi = @import("../parser/csi.zig");
const csi_mod = @import("csi.zig");
const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_core_csi_input_modes = @import("../core/protocol/terminal_core_csi_input_modes.zig");
const terminal_core_csi_mode_query = @import("../core/protocol/terminal_core_csi_mode_query.zig");
const host_reporting = @import("../core/session/host_reporting.zig");
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
    const input_snapshot = self.session.interaction.derived_snapshot.input;
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
        .grapheme_cluster_shaping_2027 = self.session.interaction.protocol_modes.grapheme_cluster_shaping_2027,
        .report_color_scheme_2031 = self.session.interaction.host_contract.report_color_scheme_2031,
        .inband_resize_notifications_2048 = self.session.interaction.host_contract.inband_resize_notifications_2048,
        .kitty_paste_events_5522 = self.session.interaction.host_contract.kitty_paste_events_5522,
        .insert_mode = screen.insert_mode,
        .local_echo_mode_12 = screen.local_echo_mode_12,
        .newline_mode = screen.newline_mode,
    };
}

pub fn decrqmPrivateModeState(snapshot: ModeSnapshot, mode: i32) csi_mod.DecrpmState {
    if (terminal_core_csi_mode_query.decrqmPrivateTerminalModeState(.{
        .column_mode_132 = snapshot.column_mode_132,
        .screen_reverse = snapshot.screen_reverse,
        .origin_mode = snapshot.origin_mode,
        .cursor_blink = snapshot.cursor_blink,
        .cursor_visible = snapshot.cursor_visible,
        .reverse_wrap = snapshot.reverse_wrap,
        .left_right_margin_mode_69 = snapshot.left_right_margin_mode_69,
        .alt_active = snapshot.alt_active,
        .save_cursor_mode_1048 = snapshot.save_cursor_mode_1048,
        .insert_mode = snapshot.insert_mode,
        .local_echo_mode_12 = snapshot.local_echo_mode_12,
        .newline_mode = snapshot.newline_mode,
    }, mode)) |state| return state;
    if (terminal_core_csi_input_modes.decrqmPrivateInputModeState(.{
        .app_cursor_keys = snapshot.app_cursor_keys,
        .auto_repeat = snapshot.auto_repeat,
        .mouse_mode_x10 = snapshot.mouse_mode_x10,
        .app_keypad = snapshot.app_keypad,
        .mouse_mode_button = snapshot.mouse_mode_button,
        .mouse_mode_any = snapshot.mouse_mode_any,
        .focus_reporting = snapshot.focus_reporting,
        .mouse_mode_sgr = snapshot.mouse_mode_sgr,
        .mouse_alternate_scroll = snapshot.mouse_alternate_scroll,
        .mouse_mode_sgr_pixels = snapshot.mouse_mode_sgr_pixels,
        .bracketed_paste = snapshot.bracketed_paste,
        .sync_updates_active = snapshot.sync_updates_active,
        .grapheme_cluster_shaping_2027 = snapshot.grapheme_cluster_shaping_2027,
    }, mode)) |state| return state;
    if (host_reporting.decrqmReportingModeState(.{
        .report_color_scheme_2031 = snapshot.report_color_scheme_2031,
        .inband_resize_notifications_2048 = snapshot.inband_resize_notifications_2048,
        .kitty_paste_events_5522 = snapshot.kitty_paste_events_5522,
    }, mode)) |state| return state;
    return switch (mode) {
        7 => boolModeState(snapshot.auto_wrap),
        else => .not_recognized,
    };
}

pub fn decrqmAnsiModeState(snapshot: ModeSnapshot, mode: i32) csi_mod.DecrpmState {
    if (terminal_core_csi_mode_query.decrqmAnsiTerminalModeState(.{
        .column_mode_132 = snapshot.column_mode_132,
        .screen_reverse = snapshot.screen_reverse,
        .origin_mode = snapshot.origin_mode,
        .cursor_blink = snapshot.cursor_blink,
        .cursor_visible = snapshot.cursor_visible,
        .reverse_wrap = snapshot.reverse_wrap,
        .left_right_margin_mode_69 = snapshot.left_right_margin_mode_69,
        .alt_active = snapshot.alt_active,
        .save_cursor_mode_1048 = snapshot.save_cursor_mode_1048,
        .insert_mode = snapshot.insert_mode,
        .local_echo_mode_12 = snapshot.local_echo_mode_12,
        .newline_mode = snapshot.newline_mode,
    }, mode)) |state| return state;
    return switch (mode) {
        else => .not_recognized,
    };
}

pub fn writeDecrqmReplyWithWriter(writer: anytype, private: bool, mode: i32, state: csi_mod.DecrpmState) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [32]u8 = undefined;
    const bytes = decrqmReplyInto(&buf, private, mode, state) orelse {
        log.logf(.warning, "DECRQM reply format failed mode={d} private={d}", .{ mode, @as(u8, @intFromBool(private)) });
        return false;
    };
    _ = writer.write(bytes) catch |err| {
        log.logf(.warning, "DECRQM reply write failed mode={d} private={d}: {s}", .{ mode, @as(u8, @intFromBool(private)), @errorName(err) });
        return false;
    };
    return true;
}

pub fn decrqmReplyInto(buf: []u8, private: bool, mode: i32, state: csi_mod.DecrpmState) ?[]const u8 {
    const seq = if (private)
        std.fmt.bufPrint(buf, "\x1b[?{d};{d}$y", .{ mode, @intFromEnum(state) })
    else
        std.fmt.bufPrint(buf, "\x1b[{d};{d}$y", .{ mode, @intFromEnum(state) });
    return seq catch null;
}

fn boolModeState(enabled: bool) csi_mod.DecrpmState {
    return if (enabled) .set else .reset;
}
