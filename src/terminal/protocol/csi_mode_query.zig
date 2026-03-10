const parser_csi = @import("../parser/csi.zig");
const csi_mod = @import("csi.zig");

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

pub const ModeCaptureContext = struct {
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

pub fn modeSnapshotFromContext(ctx: ModeCaptureContext) ModeSnapshot {
    return .{
        .app_cursor_keys = ctx.app_cursor_keys,
        .column_mode_132 = ctx.column_mode_132,
        .screen_reverse = ctx.screen_reverse,
        .origin_mode = ctx.origin_mode,
        .auto_wrap = ctx.auto_wrap,
        .auto_repeat = ctx.auto_repeat,
        .mouse_mode_x10 = ctx.mouse_mode_x10,
        .cursor_blink = ctx.cursor_blink,
        .cursor_visible = ctx.cursor_visible,
        .reverse_wrap = ctx.reverse_wrap,
        .left_right_margin_mode_69 = ctx.left_right_margin_mode_69,
        .alt_active = ctx.alt_active,
        .save_cursor_mode_1048 = ctx.save_cursor_mode_1048,
        .app_keypad = ctx.app_keypad,
        .mouse_mode_button = ctx.mouse_mode_button,
        .mouse_mode_any = ctx.mouse_mode_any,
        .focus_reporting = ctx.focus_reporting,
        .mouse_mode_sgr = ctx.mouse_mode_sgr,
        .mouse_alternate_scroll = ctx.mouse_alternate_scroll,
        .mouse_mode_sgr_pixels = ctx.mouse_mode_sgr_pixels,
        .bracketed_paste = ctx.bracketed_paste,
        .sync_updates_active = ctx.sync_updates_active,
        .grapheme_cluster_shaping_2027 = ctx.grapheme_cluster_shaping_2027,
        .report_color_scheme_2031 = ctx.report_color_scheme_2031,
        .inband_resize_notifications_2048 = ctx.inband_resize_notifications_2048,
        .kitty_paste_events_5522 = ctx.kitty_paste_events_5522,
        .insert_mode = ctx.insert_mode,
        .local_echo_mode_12 = ctx.local_echo_mode_12,
        .newline_mode = ctx.newline_mode,
    };
}

pub const ModeQueryContext = struct {
    ctx: *anyopaque,
    mode_snapshot_fn: *const fn (ctx: *anyopaque) ModeSnapshot,

    pub fn from(session: anytype) ModeQueryContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .mode_snapshot_fn = struct {
                fn call(ctx: *anyopaque) ModeSnapshot {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    const screen = s.activeScreen();
                    return modeSnapshotFromContext(.{
                        .app_cursor_keys = s.appCursorKeysEnabled(),
                        .column_mode_132 = s.column_mode_132,
                        .screen_reverse = screen.screen_reverse,
                        .origin_mode = screen.origin_mode,
                        .auto_wrap = screen.auto_wrap,
                        .auto_repeat = s.autoRepeatEnabled(),
                        .mouse_mode_x10 = s.mouseModeX10Enabled(),
                        .cursor_blink = screen.cursor_style.blink,
                        .cursor_visible = screen.cursor_visible,
                        .reverse_wrap = screen.reverse_wrap,
                        .left_right_margin_mode_69 = screen.left_right_margin_mode_69,
                        .alt_active = s.active == .alt,
                        .save_cursor_mode_1048 = screen.save_cursor_mode_1048,
                        .app_keypad = s.appKeypadEnabled(),
                        .mouse_mode_button = s.mouseModeButtonEnabled(),
                        .mouse_mode_any = s.mouseModeAnyEnabled(),
                        .focus_reporting = s.focusReportingEnabled(),
                        .mouse_mode_sgr = s.mouseModeSgrEnabled(),
                        .mouse_alternate_scroll = s.mouseAlternateScrollEnabled(),
                        .mouse_mode_sgr_pixels = s.mouseModeSgrPixelsEnabled(),
                        .bracketed_paste = s.bracketedPasteEnabled(),
                        .sync_updates_active = s.sync_updates_active,
                        .grapheme_cluster_shaping_2027 = s.grapheme_cluster_shaping_2027,
                        .report_color_scheme_2031 = s.report_color_scheme_2031,
                        .inband_resize_notifications_2048 = s.inband_resize_notifications_2048,
                        .kitty_paste_events_5522 = s.kitty_paste_events_5522,
                        .insert_mode = screen.insert_mode,
                        .local_echo_mode_12 = screen.local_echo_mode_12,
                        .newline_mode = screen.newline_mode,
                    });
                }
            }.call,
        };
    }

    pub fn snapshot(self: *const ModeQueryContext) ModeSnapshot {
        return self.mode_snapshot_fn(self.ctx);
    }
};

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

pub fn handleDecrqmQuery(writer: csi_mod.CsiWriter, action: parser_csi.CsiAction, mode: i32, snapshot: ModeSnapshot) void {
    if (action.leader == '?' and action.private) {
        const state = decrqmPrivateModeState(snapshot, mode);
        _ = csi_mod.writeDecrqmReplyWithWriter(writer, true, mode, state);
        return;
    }
    if (action.leader == 0 and !action.private) {
        const state = decrqmAnsiModeState(snapshot, mode);
        _ = csi_mod.writeDecrqmReplyWithWriter(writer, false, mode, state);
    }
}

fn boolModeState(enabled: bool) csi_mod.DecrpmState {
    return if (enabled) .set else .reset;
}
