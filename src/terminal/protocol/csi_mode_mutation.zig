const parser_csi = @import("../parser/csi.zig");

pub const ModeMutationContext = struct {
    ctx: *anyopaque,
    set_insert_mode_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_local_echo_mode_12_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_newline_mode_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_screen_reverse_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_origin_mode_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_autowrap_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_cursor_blink_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_reverse_wrap_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_left_right_margin_mode_69_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_cursor_visible_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_save_cursor_mode_1048_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_app_cursor_keys_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_column_mode_132_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_auto_repeat_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_mouse_mode_x10_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_bracketed_paste_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_sync_updates_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_focus_reporting_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_mouse_mode_button_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_mouse_mode_any_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_mouse_mode_sgr_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_mouse_alternate_scroll_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_mouse_mode_sgr_pixels_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    enter_alt_screen_fn: *const fn (ctx: *anyopaque, clear: bool, save_cursor: bool) void,
    exit_alt_screen_fn: *const fn (ctx: *anyopaque, restore_cursor: bool) void,
    save_cursor_fn: *const fn (ctx: *anyopaque) void,
    restore_cursor_fn: *const fn (ctx: *anyopaque) void,
    set_grapheme_cluster_shaping_2027_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_report_color_scheme_2031_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_inband_resize_notifications_2048_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_kitty_paste_events_5522_fn: *const fn (ctx: *anyopaque, enabled: bool) void,

    pub fn from(session: anytype) ModeMutationContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .set_insert_mode_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().*.setInsertMode(enabled);
                }
            }.call,
            .set_local_echo_mode_12_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().*.setLocalEchoMode12(enabled);
                }
            }.call,
            .set_newline_mode_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().*.setNewlineMode(enabled);
                }
            }.call,
            .set_screen_reverse_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().*.setScreenReverse(enabled);
                }
            }.call,
            .set_origin_mode_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().*.setOriginMode(enabled);
                }
            }.call,
            .set_autowrap_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().*.setAutowrap(enabled);
                }
            }.call,
            .set_cursor_blink_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().*.setCursorBlink(enabled);
                }
            }.call,
            .set_reverse_wrap_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().*.setReverseWrap(enabled);
                }
            }.call,
            .set_left_right_margin_mode_69_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().*.setLeftRightMarginMode69(enabled);
                }
            }.call,
            .set_cursor_visible_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().setCursorVisible(enabled);
                }
            }.call,
            .set_save_cursor_mode_1048_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().*.setSaveCursorMode1048(enabled);
                }
            }.call,
            .set_app_cursor_keys_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setAppCursorKeysLocked(enabled);
                }
            }.call,
            .set_column_mode_132_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setColumnMode132Locked(enabled);
                }
            }.call,
            .set_auto_repeat_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setAutoRepeatLocked(enabled);
                }
            }.call,
            .set_mouse_mode_x10_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setMouseModeX10Locked(enabled);
                }
            }.call,
            .set_bracketed_paste_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setBracketedPasteLocked(enabled);
                }
            }.call,
            .set_sync_updates_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setSyncUpdatesLocked(enabled);
                }
            }.call,
            .set_focus_reporting_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setFocusReportingLocked(enabled);
                }
            }.call,
            .set_mouse_mode_button_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setMouseModeButtonLocked(enabled);
                }
            }.call,
            .set_mouse_mode_any_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setMouseModeAnyLocked(enabled);
                }
            }.call,
            .set_mouse_mode_sgr_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setMouseModeSgrLocked(enabled);
                }
            }.call,
            .set_mouse_alternate_scroll_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setMouseAlternateScrollLocked(enabled);
                }
            }.call,
            .set_mouse_mode_sgr_pixels_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setMouseModeSgrPixelsLocked(enabled);
                }
            }.call,
            .enter_alt_screen_fn = struct {
                fn call(ctx: *anyopaque, clear: bool, save_cursor: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.enterAltScreen(clear, save_cursor);
                }
            }.call,
            .exit_alt_screen_fn = struct {
                fn call(ctx: *anyopaque, restore_cursor: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.exitAltScreen(restore_cursor);
                }
            }.call,
            .save_cursor_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.saveCursor();
                }
            }.call,
            .restore_cursor_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.restoreCursor();
                }
            }.call,
            .set_grapheme_cluster_shaping_2027_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.grapheme_cluster_shaping_2027 = enabled;
                    s.primary.setGraphemeClusterShaping2027(enabled);
                    s.alt.setGraphemeClusterShaping2027(enabled);
                }
            }.call,
            .set_report_color_scheme_2031_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.report_color_scheme_2031 = enabled;
                }
            }.call,
            .set_inband_resize_notifications_2048_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.inband_resize_notifications_2048 = enabled;
                }
            }.call,
            .set_kitty_paste_events_5522_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.kitty_paste_events_5522 = enabled;
                }
            }.call,
        };
    }

    pub fn setInsertMode(self: *const ModeMutationContext, enabled: bool) void { self.set_insert_mode_fn(self.ctx, enabled); }
    pub fn setLocalEchoMode12(self: *const ModeMutationContext, enabled: bool) void { self.set_local_echo_mode_12_fn(self.ctx, enabled); }
    pub fn setNewlineMode(self: *const ModeMutationContext, enabled: bool) void { self.set_newline_mode_fn(self.ctx, enabled); }
    pub fn setScreenReverse(self: *const ModeMutationContext, enabled: bool) void { self.set_screen_reverse_fn(self.ctx, enabled); }
    pub fn setOriginMode(self: *const ModeMutationContext, enabled: bool) void { self.set_origin_mode_fn(self.ctx, enabled); }
    pub fn setAutowrap(self: *const ModeMutationContext, enabled: bool) void { self.set_autowrap_fn(self.ctx, enabled); }
    pub fn setCursorBlink(self: *const ModeMutationContext, enabled: bool) void { self.set_cursor_blink_fn(self.ctx, enabled); }
    pub fn setReverseWrap(self: *const ModeMutationContext, enabled: bool) void { self.set_reverse_wrap_fn(self.ctx, enabled); }
    pub fn setLeftRightMarginMode69(self: *const ModeMutationContext, enabled: bool) void { self.set_left_right_margin_mode_69_fn(self.ctx, enabled); }
    pub fn setCursorVisible(self: *const ModeMutationContext, enabled: bool) void { self.set_cursor_visible_fn(self.ctx, enabled); }
    pub fn setSaveCursorMode1048(self: *const ModeMutationContext, enabled: bool) void { self.set_save_cursor_mode_1048_fn(self.ctx, enabled); }
    pub fn setAppCursorKeysLocked(self: *const ModeMutationContext, enabled: bool) void { self.set_app_cursor_keys_locked_fn(self.ctx, enabled); }
    pub fn setColumnMode132Locked(self: *const ModeMutationContext, enabled: bool) void { self.set_column_mode_132_locked_fn(self.ctx, enabled); }
    pub fn setAutoRepeatLocked(self: *const ModeMutationContext, enabled: bool) void { self.set_auto_repeat_locked_fn(self.ctx, enabled); }
    pub fn setMouseModeX10Locked(self: *const ModeMutationContext, enabled: bool) void { self.set_mouse_mode_x10_locked_fn(self.ctx, enabled); }
    pub fn setBracketedPasteLocked(self: *const ModeMutationContext, enabled: bool) void { self.set_bracketed_paste_locked_fn(self.ctx, enabled); }
    pub fn setSyncUpdatesLocked(self: *const ModeMutationContext, enabled: bool) void { self.set_sync_updates_locked_fn(self.ctx, enabled); }
    pub fn setFocusReportingLocked(self: *const ModeMutationContext, enabled: bool) void { self.set_focus_reporting_locked_fn(self.ctx, enabled); }
    pub fn setMouseModeButtonLocked(self: *const ModeMutationContext, enabled: bool) void { self.set_mouse_mode_button_locked_fn(self.ctx, enabled); }
    pub fn setMouseModeAnyLocked(self: *const ModeMutationContext, enabled: bool) void { self.set_mouse_mode_any_locked_fn(self.ctx, enabled); }
    pub fn setMouseModeSgrLocked(self: *const ModeMutationContext, enabled: bool) void { self.set_mouse_mode_sgr_locked_fn(self.ctx, enabled); }
    pub fn setMouseAlternateScrollLocked(self: *const ModeMutationContext, enabled: bool) void { self.set_mouse_alternate_scroll_locked_fn(self.ctx, enabled); }
    pub fn setMouseModeSgrPixelsLocked(self: *const ModeMutationContext, enabled: bool) void { self.set_mouse_mode_sgr_pixels_locked_fn(self.ctx, enabled); }
    pub fn enterAltScreen(self: *const ModeMutationContext, clear: bool, save_cursor: bool) void { self.enter_alt_screen_fn(self.ctx, clear, save_cursor); }
    pub fn exitAltScreen(self: *const ModeMutationContext, restore_cursor: bool) void { self.exit_alt_screen_fn(self.ctx, restore_cursor); }
    pub fn saveCursor(self: *const ModeMutationContext) void { self.save_cursor_fn(self.ctx); }
    pub fn restoreCursor(self: *const ModeMutationContext) void { self.restore_cursor_fn(self.ctx); }
    pub fn setGraphemeClusterShaping2027(self: *const ModeMutationContext, enabled: bool) void { self.set_grapheme_cluster_shaping_2027_fn(self.ctx, enabled); }
    pub fn setReportColorScheme2031(self: *const ModeMutationContext, enabled: bool) void { self.set_report_color_scheme_2031_fn(self.ctx, enabled); }
    pub fn setInbandResizeNotifications2048(self: *const ModeMutationContext, enabled: bool) void { self.set_inband_resize_notifications_2048_fn(self.ctx, enabled); }
    pub fn setKittyPasteEvents5522(self: *const ModeMutationContext, enabled: bool) void { self.set_kitty_paste_events_5522_fn(self.ctx, enabled); }
};

pub fn applyModeMutation(
    context: ModeMutationContext,
    action: parser_csi.CsiAction,
    param_len: usize,
    params: [parser_csi.max_params]i32,
    enabled: bool,
) void {
    if (!action.private) {
        applyAnsiModeMutation(context, param_len, params, enabled);
        return;
    }
    if (action.leader == '?') {
        applyPrivateModeMutation(context, param_len, params, enabled);
    }
}

fn applyAnsiModeMutation(context: ModeMutationContext, param_len: usize, params: [parser_csi.max_params]i32, enabled: bool) void {
    var idx: u8 = 0;
    while (idx < param_len and idx < params.len) : (idx += 1) {
        switch (params[idx]) {
            4 => context.setInsertMode(enabled),
            12 => context.setLocalEchoMode12(enabled),
            20 => context.setNewlineMode(enabled),
            else => {},
        }
    }
}

fn applyPrivateModeMutation(context: ModeMutationContext, param_len: usize, params: [parser_csi.max_params]i32, enabled: bool) void {
    var idx: u8 = 0;
    while (idx < param_len and idx < params.len) : (idx += 1) {
        switch (params[idx]) {
            1 => context.setAppCursorKeysLocked(enabled),
            3 => context.setColumnMode132Locked(enabled),
            5 => context.setScreenReverse(enabled),
            6 => context.setOriginMode(enabled),
            7 => context.setAutowrap(enabled),
            8 => context.setAutoRepeatLocked(enabled),
            9 => context.setMouseModeX10Locked(enabled),
            12 => context.setCursorBlink(enabled),
            25 => context.setCursorVisible(enabled),
            45 => context.setReverseWrap(enabled),
            47 => if (enabled) context.enterAltScreen(false, false) else context.exitAltScreen(false),
            69 => context.setLeftRightMarginMode69(enabled),
            1000 => context.setMouseModeX10Locked(enabled),
            1002 => context.setMouseModeButtonLocked(enabled),
            1003 => context.setMouseModeAnyLocked(enabled),
            1004 => context.setFocusReportingLocked(enabled),
            1006 => context.setMouseModeSgrLocked(enabled),
            1007 => context.setMouseAlternateScrollLocked(enabled),
            1016 => context.setMouseModeSgrPixelsLocked(enabled),
            1047 => if (enabled) context.enterAltScreen(true, false) else context.exitAltScreen(false),
            1048 => {
                if (enabled) {
                    context.saveCursor();
                } else {
                    context.restoreCursor();
                }
                context.setSaveCursorMode1048(enabled);
            },
            1049 => if (enabled) context.enterAltScreen(true, true) else context.exitAltScreen(true),
            2004 => context.setBracketedPasteLocked(enabled),
            2026 => context.setSyncUpdatesLocked(enabled),
            2027 => context.setGraphemeClusterShaping2027(enabled),
            2031 => context.setReportColorScheme2031(enabled),
            2048 => context.setInbandResizeNotifications2048(enabled),
            5522 => context.setKittyPasteEvents5522(enabled),
            else => {},
        }
    }
}
