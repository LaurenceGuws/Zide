const parser_csi = @import("../parser/csi.zig");
const csi_mod = @import("csi.zig");
const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_core_csi_input_modes = @import("../core/protocol/terminal_core_csi_input_modes.zig");
const host_reporting = @import("../core/session/host_reporting.zig");
const protocol_runtime = @import("../core/session/protocol_runtime.zig");

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
    const terminal_modes = self.core.terminalModeSnapshot();
    const input_snapshot = terminal_core_csi_input_modes.inputModeSnapshot(self);
    const reporting = protocol_runtime.reportingSnapshot(self);
    return .{
        .app_cursor_keys = input_snapshot.app_cursor_keys,
        .column_mode_132 = terminal_modes.column_mode_132,
        .screen_reverse = terminal_modes.screen_reverse,
        .origin_mode = terminal_modes.origin_mode,
        .auto_wrap = terminal_modes.auto_wrap,
        .auto_repeat = input_snapshot.auto_repeat,
        .mouse_mode_x10 = input_snapshot.mouse_mode_x10,
        .cursor_blink = terminal_modes.cursor_blink,
        .cursor_visible = terminal_modes.cursor_visible,
        .reverse_wrap = terminal_modes.reverse_wrap,
        .left_right_margin_mode_69 = terminal_modes.left_right_margin_mode_69,
        .alt_active = terminal_modes.alt_active,
        .save_cursor_mode_1048 = terminal_modes.save_cursor_mode_1048,
        .app_keypad = input_snapshot.app_keypad,
        .mouse_mode_button = input_snapshot.mouse_mode_button,
        .mouse_mode_any = input_snapshot.mouse_mode_any,
        .focus_reporting = input_snapshot.focus_reporting,
        .mouse_mode_sgr = input_snapshot.mouse_mode_sgr,
        .mouse_alternate_scroll = input_snapshot.mouse_alternate_scroll,
        .mouse_mode_sgr_pixels = input_snapshot.mouse_mode_sgr_pixels,
        .bracketed_paste = input_snapshot.bracketed_paste,
        .sync_updates_active = self.core.sync_updates_active,
        .grapheme_cluster_shaping_2027 = input_snapshot.grapheme_cluster_shaping_2027,
        .report_color_scheme_2031 = reporting.report_color_scheme_2031,
        .inband_resize_notifications_2048 = reporting.inband_resize_notifications_2048,
        .kitty_paste_events_5522 = reporting.kitty_paste_events_5522,
        .insert_mode = terminal_modes.insert_mode,
        .local_echo_mode_12 = terminal_modes.local_echo_mode_12,
        .newline_mode = terminal_modes.newline_mode,
    };
}

pub fn decrqmPrivateModeState(snapshot: ModeSnapshot, mode: i32) csi_mod.DecrpmState {
    if (decrqmPrivateTerminalModeState(snapshot, mode)) |state| return state;
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
        else => .not_recognized,
    };
}

pub fn decrqmAnsiModeState(snapshot: ModeSnapshot, mode: i32) csi_mod.DecrpmState {
    if (decrqmAnsiTerminalModeState(snapshot, mode)) |state| return state;
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

fn decrqmPrivateTerminalModeState(snapshot: ModeSnapshot, mode: i32) ?csi_mod.DecrpmState {
    return switch (mode) {
        3 => boolModeState(snapshot.column_mode_132),
        5 => boolModeState(snapshot.screen_reverse),
        6 => boolModeState(snapshot.origin_mode),
        7 => boolModeState(snapshot.auto_wrap),
        12 => boolModeState(snapshot.cursor_blink),
        25 => boolModeState(snapshot.cursor_visible),
        45 => boolModeState(snapshot.reverse_wrap),
        47, 1047, 1049 => boolModeState(snapshot.alt_active),
        69 => boolModeState(snapshot.left_right_margin_mode_69),
        1048 => boolModeState(snapshot.save_cursor_mode_1048),
        else => null,
    };
}

fn decrqmAnsiTerminalModeState(snapshot: ModeSnapshot, mode: i32) ?csi_mod.DecrpmState {
    return switch (mode) {
        4 => boolModeState(snapshot.insert_mode),
        12 => boolModeState(snapshot.local_echo_mode_12),
        20 => boolModeState(snapshot.newline_mode),
        else => null,
    };
}
