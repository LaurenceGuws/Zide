const std = @import("std");
const types = @import("../model/types.zig");
const screen_mod = @import("../model/screen.zig");
const parser_csi = @import("../parser/csi.zig");
const app_logger = @import("../../app_logger.zig");
const csi_reply = @import("csi_reply.zig");
const csi_mode_query = @import("csi_mode_query.zig");

const Color = types.Color;

pub const DecrpmState = enum(u8) {
    not_recognized = 0,
    set = 1,
    reset = 2,
    permanently_set = 3,
    permanently_reset = 4,
};

const ModeSnapshot = csi_mode_query.ModeSnapshot;
const ModeCaptureContext = csi_mode_query.ModeCaptureContext;
const ModeQueryContext = csi_mode_query.ModeQueryContext;

fn modeSnapshotFromContext(ctx: ModeCaptureContext) ModeSnapshot {
    return csi_mode_query.modeSnapshotFromContext(ctx);
}

const SgrContext = struct {
    ctx: *anyopaque,
    palette_color_fn: *const fn (ctx: *anyopaque, idx: u8) Color,
    current_attrs_ptr_fn: *const fn (ctx: *anyopaque) *types.CellAttrs,
    default_attrs_ptr_fn: *const fn (ctx: *anyopaque) *const types.CellAttrs,

    pub fn from(session: anytype) SgrContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .palette_color_fn = struct {
                fn call(ctx: *anyopaque, idx: u8) Color {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.paletteColor(idx);
                }
            }.call,
            .current_attrs_ptr_fn = struct {
                fn call(ctx: *anyopaque) *types.CellAttrs {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return &s.activeScreen().current_attrs;
                }
            }.call,
            .default_attrs_ptr_fn = struct {
                fn call(ctx: *anyopaque) *const types.CellAttrs {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return &s.activeScreen().default_attrs;
                }
            }.call,
        };
    }

    pub fn paletteColor(self: *const SgrContext, idx: u8) Color {
        return self.palette_color_fn(self.ctx, idx);
    }

    pub fn currentAttrs(self: *const SgrContext) *types.CellAttrs {
        return self.current_attrs_ptr_fn(self.ctx);
    }

    pub fn defaultAttrs(self: *const SgrContext) *const types.CellAttrs {
        return self.default_attrs_ptr_fn(self.ctx);
    }
};

const DecstrContext = struct {
    ctx: *anyopaque,
    reset_parser_fn: *const fn (ctx: *anyopaque) void,
    reset_saved_charset_fn: *const fn (ctx: *anyopaque) void,
    clear_title_buffer_fn: *const fn (ctx: *anyopaque) void,
    set_default_title_fn: *const fn (ctx: *anyopaque) void,
    set_report_color_scheme_2031_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_grapheme_cluster_shaping_2027_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_primary_grapheme_cluster_shaping_2027_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_alt_grapheme_cluster_shaping_2027_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_inband_resize_notifications_2048_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_kitty_paste_events_5522_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    reset_input_modes_locked_fn: *const fn (ctx: *anyopaque) void,
    set_column_mode_132_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_sync_updates_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    clear_all_kitty_images_fn: *const fn (ctx: *anyopaque) void,
    reset_active_screen_state_fn: *const fn (ctx: *anyopaque) void,
    mark_active_screen_decstr_dirty_fn: *const fn (ctx: *anyopaque) void,

    pub fn from(session: anytype) DecstrContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .reset_parser_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.parser.reset();
                }
            }.call,
            .reset_saved_charset_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.saved_charset = .{};
                }
            }.call,
            .clear_title_buffer_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.title_buffer.clearRetainingCapacity();
                }
            }.call,
            .set_default_title_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.title = "Terminal";
                }
            }.call,
            .set_report_color_scheme_2031_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.report_color_scheme_2031 = enabled;
                }
            }.call,
            .set_grapheme_cluster_shaping_2027_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.grapheme_cluster_shaping_2027 = enabled;
                }
            }.call,
            .set_primary_grapheme_cluster_shaping_2027_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.primary.setGraphemeClusterShaping2027(enabled);
                }
            }.call,
            .set_alt_grapheme_cluster_shaping_2027_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.alt.setGraphemeClusterShaping2027(enabled);
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
            .reset_input_modes_locked_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.resetInputModesLocked();
                }
            }.call,
            .set_column_mode_132_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.column_mode_132 = enabled;
                }
            }.call,
            .set_sync_updates_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setSyncUpdatesLocked(enabled);
                }
            }.call,
            .clear_all_kitty_images_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.clearAllKittyImages();
                }
            }.call,
            .reset_active_screen_state_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().resetState();
                }
            }.call,
            .mark_active_screen_decstr_dirty_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.activeScreen().markDirtyAllWithReason(.decstr_soft_reset, @src());
                }
            }.call,
        };
    }

    pub fn resetParser(self: *const DecstrContext) void {
        self.reset_parser_fn(self.ctx);
    }

    pub fn resetSavedCharset(self: *const DecstrContext) void {
        self.reset_saved_charset_fn(self.ctx);
    }

    pub fn clearTitleBuffer(self: *const DecstrContext) void {
        self.clear_title_buffer_fn(self.ctx);
    }

    pub fn setDefaultTitle(self: *const DecstrContext) void {
        self.set_default_title_fn(self.ctx);
    }

    pub fn setReportColorScheme2031(self: *const DecstrContext, enabled: bool) void {
        self.set_report_color_scheme_2031_fn(self.ctx, enabled);
    }

    pub fn setGraphemeClusterShaping2027(self: *const DecstrContext, enabled: bool) void {
        self.set_grapheme_cluster_shaping_2027_fn(self.ctx, enabled);
    }

    pub fn setPrimaryGraphemeClusterShaping2027(self: *const DecstrContext, enabled: bool) void {
        self.set_primary_grapheme_cluster_shaping_2027_fn(self.ctx, enabled);
    }

    pub fn setAltGraphemeClusterShaping2027(self: *const DecstrContext, enabled: bool) void {
        self.set_alt_grapheme_cluster_shaping_2027_fn(self.ctx, enabled);
    }

    pub fn setInbandResizeNotifications2048(self: *const DecstrContext, enabled: bool) void {
        self.set_inband_resize_notifications_2048_fn(self.ctx, enabled);
    }

    pub fn setKittyPasteEvents5522(self: *const DecstrContext, enabled: bool) void {
        self.set_kitty_paste_events_5522_fn(self.ctx, enabled);
    }

    pub fn resetInputModesLocked(self: *const DecstrContext) void {
        self.reset_input_modes_locked_fn(self.ctx);
    }

    pub fn setColumnMode132(self: *const DecstrContext, enabled: bool) void {
        self.set_column_mode_132_fn(self.ctx, enabled);
    }

    pub fn setSyncUpdatesLocked(self: *const DecstrContext, enabled: bool) void {
        self.set_sync_updates_locked_fn(self.ctx, enabled);
    }

    pub fn clearAllKittyImages(self: *const DecstrContext) void {
        self.clear_all_kitty_images_fn(self.ctx);
    }

    pub fn resetActiveScreenState(self: *const DecstrContext) void {
        self.reset_active_screen_state_fn(self.ctx);
    }

    pub fn markActiveScreenDecstrDirty(self: *const DecstrContext) void {
        self.mark_active_screen_decstr_dirty_fn(self.ctx);
    }
};

const ModeMutationContext = struct {
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

    pub fn setInsertMode(self: *const ModeMutationContext, enabled: bool) void {
        self.set_insert_mode_fn(self.ctx, enabled);
    }
    pub fn setLocalEchoMode12(self: *const ModeMutationContext, enabled: bool) void {
        self.set_local_echo_mode_12_fn(self.ctx, enabled);
    }
    pub fn setNewlineMode(self: *const ModeMutationContext, enabled: bool) void {
        self.set_newline_mode_fn(self.ctx, enabled);
    }
    pub fn setScreenReverse(self: *const ModeMutationContext, enabled: bool) void {
        self.set_screen_reverse_fn(self.ctx, enabled);
    }
    pub fn setOriginMode(self: *const ModeMutationContext, enabled: bool) void {
        self.set_origin_mode_fn(self.ctx, enabled);
    }
    pub fn setAutowrap(self: *const ModeMutationContext, enabled: bool) void {
        self.set_autowrap_fn(self.ctx, enabled);
    }
    pub fn setCursorBlink(self: *const ModeMutationContext, enabled: bool) void {
        self.set_cursor_blink_fn(self.ctx, enabled);
    }
    pub fn setReverseWrap(self: *const ModeMutationContext, enabled: bool) void {
        self.set_reverse_wrap_fn(self.ctx, enabled);
    }
    pub fn setLeftRightMarginMode69(self: *const ModeMutationContext, enabled: bool) void {
        self.set_left_right_margin_mode_69_fn(self.ctx, enabled);
    }
    pub fn setCursorVisible(self: *const ModeMutationContext, enabled: bool) void {
        self.set_cursor_visible_fn(self.ctx, enabled);
    }
    pub fn setSaveCursorMode1048(self: *const ModeMutationContext, enabled: bool) void {
        self.set_save_cursor_mode_1048_fn(self.ctx, enabled);
    }
    pub fn setAppCursorKeysLocked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_app_cursor_keys_locked_fn(self.ctx, enabled);
    }
    pub fn setColumnMode132Locked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_column_mode_132_locked_fn(self.ctx, enabled);
    }
    pub fn setAutoRepeatLocked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_auto_repeat_locked_fn(self.ctx, enabled);
    }
    pub fn setMouseModeX10Locked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_mouse_mode_x10_locked_fn(self.ctx, enabled);
    }
    pub fn setBracketedPasteLocked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_bracketed_paste_locked_fn(self.ctx, enabled);
    }
    pub fn setSyncUpdatesLocked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_sync_updates_locked_fn(self.ctx, enabled);
    }
    pub fn setFocusReportingLocked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_focus_reporting_locked_fn(self.ctx, enabled);
    }
    pub fn setMouseModeButtonLocked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_mouse_mode_button_locked_fn(self.ctx, enabled);
    }
    pub fn setMouseModeAnyLocked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_mouse_mode_any_locked_fn(self.ctx, enabled);
    }
    pub fn setMouseModeSgrLocked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_mouse_mode_sgr_locked_fn(self.ctx, enabled);
    }
    pub fn setMouseAlternateScrollLocked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_mouse_alternate_scroll_locked_fn(self.ctx, enabled);
    }
    pub fn setMouseModeSgrPixelsLocked(self: *const ModeMutationContext, enabled: bool) void {
        self.set_mouse_mode_sgr_pixels_locked_fn(self.ctx, enabled);
    }
    pub fn enterAltScreen(self: *const ModeMutationContext, clear: bool, save_cursor: bool) void {
        self.enter_alt_screen_fn(self.ctx, clear, save_cursor);
    }
    pub fn exitAltScreen(self: *const ModeMutationContext, restore_cursor: bool) void {
        self.exit_alt_screen_fn(self.ctx, restore_cursor);
    }
    pub fn saveCursor(self: *const ModeMutationContext) void {
        self.save_cursor_fn(self.ctx);
    }
    pub fn restoreCursor(self: *const ModeMutationContext) void {
        self.restore_cursor_fn(self.ctx);
    }
    pub fn setGraphemeClusterShaping2027(self: *const ModeMutationContext, enabled: bool) void {
        self.set_grapheme_cluster_shaping_2027_fn(self.ctx, enabled);
    }
    pub fn setReportColorScheme2031(self: *const ModeMutationContext, enabled: bool) void {
        self.set_report_color_scheme_2031_fn(self.ctx, enabled);
    }
    pub fn setInbandResizeNotifications2048(self: *const ModeMutationContext, enabled: bool) void {
        self.set_inband_resize_notifications_2048_fn(self.ctx, enabled);
    }
    pub fn setKittyPasteEvents5522(self: *const ModeMutationContext, enabled: bool) void {
        self.set_kitty_paste_events_5522_fn(self.ctx, enabled);
    }
};


const SimpleCsiContext = struct {
    ctx: *anyopaque,
    active_screen_fn: *const fn (ctx: *anyopaque) *screen_mod.Screen,
    erase_display_fn: *const fn (ctx: *anyopaque, mode: i32) void,
    erase_line_fn: *const fn (ctx: *anyopaque, mode: i32) void,
    insert_chars_fn: *const fn (ctx: *anyopaque, count: usize) void,
    delete_chars_fn: *const fn (ctx: *anyopaque, count: usize) void,
    erase_chars_fn: *const fn (ctx: *anyopaque, count: usize) void,
    insert_lines_fn: *const fn (ctx: *anyopaque, count: usize) void,
    delete_lines_fn: *const fn (ctx: *anyopaque, count: usize) void,
    scroll_region_up_fn: *const fn (ctx: *anyopaque, count: usize) void,
    scroll_region_down_fn: *const fn (ctx: *anyopaque, count: usize) void,
    save_cursor_fn: *const fn (ctx: *anyopaque) void,
    restore_cursor_fn: *const fn (ctx: *anyopaque) void,
    set_cursor_style_fn: *const fn (ctx: *anyopaque, mode: i32) void,

    pub fn from(session: anytype) SimpleCsiContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .active_screen_fn = struct {
                fn call(ctx: *anyopaque) *screen_mod.Screen {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.activeScreen();
                }
            }.call,
            .erase_display_fn = struct {
                fn call(ctx: *anyopaque, mode: i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.eraseDisplay(mode);
                }
            }.call,
            .erase_line_fn = struct {
                fn call(ctx: *anyopaque, mode: i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.eraseLine(mode);
                }
            }.call,
            .insert_chars_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.insertChars(count);
                }
            }.call,
            .delete_chars_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.deleteChars(count);
                }
            }.call,
            .erase_chars_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.eraseChars(count);
                }
            }.call,
            .insert_lines_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.insertLines(count);
                }
            }.call,
            .delete_lines_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.deleteLines(count);
                }
            }.call,
            .scroll_region_up_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.scrollRegionUp(count);
                }
            }.call,
            .scroll_region_down_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.scrollRegionDown(count);
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
            .set_cursor_style_fn = struct {
                fn call(ctx: *anyopaque, mode: i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setCursorStyle(mode);
                }
            }.call,
        };
    }

    pub fn activeScreen(self: *const SimpleCsiContext) *screen_mod.Screen {
        return self.active_screen_fn(self.ctx);
    }
    pub fn eraseDisplay(self: *const SimpleCsiContext, mode: i32) void {
        self.erase_display_fn(self.ctx, mode);
    }
    pub fn eraseLine(self: *const SimpleCsiContext, mode: i32) void {
        self.erase_line_fn(self.ctx, mode);
    }
    pub fn insertChars(self: *const SimpleCsiContext, count: usize) void {
        self.insert_chars_fn(self.ctx, count);
    }
    pub fn deleteChars(self: *const SimpleCsiContext, count: usize) void {
        self.delete_chars_fn(self.ctx, count);
    }
    pub fn eraseChars(self: *const SimpleCsiContext, count: usize) void {
        self.erase_chars_fn(self.ctx, count);
    }
    pub fn insertLines(self: *const SimpleCsiContext, count: usize) void {
        self.insert_lines_fn(self.ctx, count);
    }
    pub fn deleteLines(self: *const SimpleCsiContext, count: usize) void {
        self.delete_lines_fn(self.ctx, count);
    }
    pub fn scrollRegionUp(self: *const SimpleCsiContext, count: usize) void {
        self.scroll_region_up_fn(self.ctx, count);
    }
    pub fn scrollRegionDown(self: *const SimpleCsiContext, count: usize) void {
        self.scroll_region_down_fn(self.ctx, count);
    }
    pub fn saveCursor(self: *const SimpleCsiContext) void {
        self.save_cursor_fn(self.ctx);
    }
    pub fn restoreCursor(self: *const SimpleCsiContext) void {
        self.restore_cursor_fn(self.ctx);
    }
    pub fn setCursorStyle(self: *const SimpleCsiContext, mode: i32) void {
        self.set_cursor_style_fn(self.ctx, mode);
    }
};

const SpecialCsiContext = struct {
    ctx: *anyopaque,
    active_screen_fn: *const fn (ctx: *anyopaque) *screen_mod.Screen,
    save_cursor_fn: *const fn (ctx: *anyopaque) void,
    restore_cursor_fn: *const fn (ctx: *anyopaque) void,
    set_cursor_style_fn: *const fn (ctx: *anyopaque, mode: i32) void,
    key_mode_push_locked_fn: *const fn (ctx: *anyopaque, flags: u32) void,
    key_mode_pop_locked_fn: *const fn (ctx: *anyopaque, count: usize) void,
    key_mode_modify_locked_fn: *const fn (ctx: *anyopaque, flags: u32, mode: u32) void,
    key_mode_query_locked_fn: *const fn (ctx: *anyopaque) void,

    pub fn from(session: anytype) SpecialCsiContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .active_screen_fn = struct {
                fn call(ctx: *anyopaque) *screen_mod.Screen {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.activeScreen();
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
            .set_cursor_style_fn = struct {
                fn call(ctx: *anyopaque, mode: i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setCursorStyle(mode);
                }
            }.call,
            .key_mode_push_locked_fn = struct {
                fn call(ctx: *anyopaque, flags: u32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.keyModePushLocked(flags);
                }
            }.call,
            .key_mode_pop_locked_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.keyModePopLocked(count);
                }
            }.call,
            .key_mode_modify_locked_fn = struct {
                fn call(ctx: *anyopaque, flags: u32, mode: u32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.keyModeModifyLocked(flags, mode);
                }
            }.call,
            .key_mode_query_locked_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.keyModeQueryLocked();
                }
            }.call,
        };
    }

    pub fn activeScreen(self: *const SpecialCsiContext) *screen_mod.Screen {
        return self.active_screen_fn(self.ctx);
    }
    pub fn saveCursor(self: *const SpecialCsiContext) void {
        self.save_cursor_fn(self.ctx);
    }
    pub fn restoreCursor(self: *const SpecialCsiContext) void {
        self.restore_cursor_fn(self.ctx);
    }
    pub fn setCursorStyle(self: *const SpecialCsiContext, mode: i32) void {
        self.set_cursor_style_fn(self.ctx, mode);
    }
    pub fn keyModePushLocked(self: *const SpecialCsiContext, flags: u32) void {
        self.key_mode_push_locked_fn(self.ctx, flags);
    }
    pub fn keyModePopLocked(self: *const SpecialCsiContext, count: usize) void {
        self.key_mode_pop_locked_fn(self.ctx, count);
    }
    pub fn keyModeModifyLocked(self: *const SpecialCsiContext, flags: u32, mode: u32) void {
        self.key_mode_modify_locked_fn(self.ctx, flags, mode);
    }
    pub fn keyModeQueryLocked(self: *const SpecialCsiContext) void {
        self.key_mode_query_locked_fn(self.ctx);
    }
};

const ReplyCsiContext = struct {
    ctx: *anyopaque,
    active_screen_fn: *const fn (ctx: *anyopaque) *screen_mod.Screen,
    handle_dsr_fn: *const fn (ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void,
    handle_da_fn: *const fn (ctx: *anyopaque, action: parser_csi.CsiAction) void,
    handle_window_op_fn: *const fn (ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void,
    handle_decrqm_fn: *const fn (ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void,
    apply_decstr_fn: *const fn (ctx: *anyopaque) void,

    pub fn from(session: anytype) ReplyCsiContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .active_screen_fn = struct {
                fn call(ctx: *anyopaque) *screen_mod.Screen {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.activeScreen();
                }
            }.call,
            .handle_dsr_fn = struct {
                fn call(ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (s.lockPtyWriter()) |writer_guard| {
                        var writer = writer_guard;
                        defer writer.unlock();
                        handleDsrQuery(QueryContext.from(s), CsiWriter.from(&writer), ScreenQueryContext.from(s.activeScreen()), action, param_len, params);
                    }
                }
            }.call,
            .handle_da_fn = struct {
                fn call(ctx: *anyopaque, action: parser_csi.CsiAction) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (!(action.leader == 0 or action.leader == '?')) return;
                    if (s.lockPtyWriter()) |writer_guard| {
                        var writer = writer_guard;
                        defer writer.unlock();
                        handleDaQuery(CsiWriter.from(&writer));
                    }
                }
            }.call,
            .handle_window_op_fn = struct {
                fn call(ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (action.leader != 0 or action.private) return;
                    if (s.lockPtyWriter()) |writer_guard| {
                        var writer = writer_guard;
                        defer writer.unlock();
                        handleWindowOpQuery(QueryContext.from(s), CsiWriter.from(&writer), ScreenQueryContext.from(s.activeScreen()), param_len, params);
                    }
                }
            }.call,
            .handle_decrqm_fn = struct {
                fn call(ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (!csiIntermediatesEq(action, "$")) return;
                    if (param_len != 1) return;
                    if (s.lockPtyWriter()) |writer_guard| {
                        var writer = writer_guard;
                        defer writer.unlock();
                        handleDecrqmQuery(CsiWriter.from(&writer), action, params[0], ModeQueryContext.from(s).snapshot());
                    }
                }
            }.call,
            .apply_decstr_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    applyDecstrReset(DecstrContext.from(s));
                }
            }.call,
        };
    }

    pub fn activeScreen(self: *const ReplyCsiContext) *screen_mod.Screen {
        return self.active_screen_fn(self.ctx);
    }
    pub fn handleDsr(self: *const ReplyCsiContext, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
        self.handle_dsr_fn(self.ctx, action, param_len, params);
    }
    pub fn handleDa(self: *const ReplyCsiContext, action: parser_csi.CsiAction) void {
        self.handle_da_fn(self.ctx, action);
    }
    pub fn handleWindowOp(self: *const ReplyCsiContext, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
        self.handle_window_op_fn(self.ctx, action, param_len, params);
    }
    pub fn handleDecrqm(self: *const ReplyCsiContext, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
        self.handle_decrqm_fn(self.ctx, action, param_len, params);
    }
    pub fn applyDecstr(self: *const ReplyCsiContext) void {
        self.apply_decstr_fn(self.ctx);
    }
};

fn csiIntermediatesEq(action: parser_csi.CsiAction, bytes: []const u8) bool {
    if (action.intermediates_len != bytes.len) return false;
    return std.mem.eql(u8, action.intermediates[0..action.intermediates_len], bytes);
}

fn effectiveCsiParamCount(action: parser_csi.CsiAction) usize {
    const raw_count = @min(@as(usize, action.count) + 1, parser_csi.max_params);
    if (action.count == 0 and action.params[0] == 0) return 0;
    return raw_count;
}

fn effectiveSgrParamCount(action: parser_csi.CsiAction) usize {
    const raw_count = @min(@as(usize, action.count) + 1, parser_csi.max_params);
    if (action.count == 0 and action.params[0] == 0) return 1;
    return raw_count;
}

pub const CsiWriter = csi_reply.CsiWriter;
const QueryContext = csi_reply.QueryContext;
const CursorReport = csi_reply.CursorReport;
const ScreenQueryContext = csi_reply.ScreenQueryContext;


pub const SessionFacade = struct {
    ctx: *anyopaque,
    handle_csi_fn: *const fn (ctx: *anyopaque, action: parser_csi.CsiAction) void,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .handle_csi_fn = struct {
                fn call(ctx: *anyopaque, action: parser_csi.CsiAction) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    handleCsiOnSession(s, action);
                }
            }.call,
        };
    }

    pub fn handleCsi(self: *const SessionFacade, action: parser_csi.CsiAction) void {
        self.handle_csi_fn(self.ctx, action);
    }
};

pub fn handleCsi(session: SessionFacade, action: parser_csi.CsiAction) void {
    session.handleCsi(action);
}

fn handleCsiOnSession(self: anytype, action: parser_csi.CsiAction) void {
    const log = app_logger.logger("terminal.csi");
    const csi_param_count = effectiveCsiParamCount(action);
    log.logf(
        .debug,
        "csi final={c} leader={c} private={d} interm={s} count={d} params={d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
        .{
            action.final,
            if (action.leader == 0) '.' else action.leader,
            @as(u8, @intFromBool(action.private)),
            action.intermediates[0..action.intermediates_len],
            csi_param_count,
            action.params[0],
            action.params[1],
            action.params[2],
            action.params[3],
            action.params[4],
            action.params[5],
            action.params[6],
            action.params[7],
            action.params[8],
            action.params[9],
            action.params[10],
            action.params[11],
            action.params[12],
            action.params[13],
            action.params[14],
            action.params[15],
        },
    );
    const p = action.params;
    const param_len = csi_param_count;
    const mode_context = ModeMutationContext.from(self);
    const simple = SimpleCsiContext.from(self);
    const special = SpecialCsiContext.from(self);
    const reply = ReplyCsiContext.from(self);

    switch (action.final) {
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'I', 'H', 'f', 'd', 'J', 'K', '@', 'P', 'X', 'L', 'M', 'S', 'T', 'Z', 'r' => {
            handleSimpleCsi(simple, action, param_len, p);
        },
        's' => { // SCP / DECSLRM (when ?69 enabled)
            handleSpecialCsi(special, action, param_len, p);
        },
        'u' => { // RCP
            handleSpecialCsi(special, action, param_len, p);
        },
        'm' => { // SGR
            applySgr(SgrContext.from(self), action);
        },
        'q' => { // DECSCUSR
            handleSpecialCsi(special, action, param_len, p);
        },
        'g' => { // TBC
            handleSpecialCsi(special, action, param_len, p);
        },
        'n' => { // DSR
            reply.handleDsr(action, param_len, p);
        },
        'c' => { // DA
            reply.handleDa(action);
        },
        't' => { // Window ops (bounded subset)
            reply.handleWindowOp(action, param_len, p);
        },
        'p' => { // DECRQM (requires '$' intermediate)
            if (csiIntermediatesEq(action, "!")) { // DECSTR (soft terminal reset)
                if (action.leader == 0 and !action.private) {
                    reply.applyDecstr();
                }
                return;
            }
            reply.handleDecrqm(action, param_len, p);
        },
        'h' => { // SM
            applyModeMutation(mode_context, action, param_len, p, true);
            return;
        },
        'l' => { // RM
            applyModeMutation(mode_context, action, param_len, p, false);
            return;
        },
        else => {},
    }
}

fn applyModeMutation(
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

fn handleSimpleCsi(
    context: SimpleCsiContext,
    action: parser_csi.CsiAction,
    param_len: usize,
    params: [parser_csi.max_params]i32,
) void {
    const get = struct {
        fn at(local_params: [parser_csi.max_params]i32, idx: u8, default: i32) i32 {
            return if (idx < parser_csi.max_params) local_params[idx] else default;
        }
    }.at;
    const screen = context.activeScreen();

    switch (action.final) {
        'A' => screen.cursorUp(@intCast(@max(1, get(params, 0, 1)))),
        'B' => screen.cursorDown(@intCast(@max(1, get(params, 0, 1)))),
        'C' => screen.cursorForward(@intCast(@max(1, get(params, 0, 1)))),
        'D' => screen.cursorBack(@intCast(@max(1, get(params, 0, 1)))),
        'E' => screen.cursorNextLine(@intCast(@max(1, get(params, 0, 1)))),
        'F' => screen.cursorPrevLine(@intCast(@max(1, get(params, 0, 1)))),
        'G' => screen.cursorColAbsolute(@max(1, get(params, 0, 1))),
        'I' => {
            var i: i32 = 0;
            const n = @max(1, get(params, 0, 1));
            while (i < n) : (i += 1) screen.tab();
        },
        'H', 'f' => screen.cursorPosAbsolute(@max(1, get(params, 0, 1)), @max(1, get(params, 1, 1))),
        'd' => screen.cursorRowAbsolute(@max(1, get(params, 0, 1))),
        'J' => context.eraseDisplay(if (param_len > 0) params[0] else 0),
        'K' => context.eraseLine(if (param_len > 0) params[0] else 0),
        '@' => context.insertChars(@intCast(@max(1, get(params, 0, 1)))),
        'P' => context.deleteChars(@intCast(@max(1, get(params, 0, 1)))),
        'X' => context.eraseChars(@intCast(@max(1, get(params, 0, 1)))),
        'L' => context.insertLines(@intCast(@max(1, get(params, 0, 1)))),
        'M' => context.deleteLines(@intCast(@max(1, get(params, 0, 1)))),
        'S' => context.scrollRegionUp(@intCast(@max(1, get(params, 0, 1)))),
        'T' => context.scrollRegionDown(@intCast(@max(1, get(params, 0, 1)))),
        'Z' => {
            var i: i32 = 0;
            const n = @max(1, get(params, 0, 1));
            while (i < n) : (i += 1) screen.backTab();
        },
        'r' => {
            const top_1 = if (param_len > 0 and params[0] > 0) params[0] else 1;
            const bot_1 = if (param_len > 1 and params[1] > 0) params[1] else @as(i32, @intCast(screen.grid.rows));
            const top = @min(@as(usize, screen.grid.rows - 1), @as(usize, @intCast(@max(1, top_1) - 1)));
            const bot = @min(@as(usize, screen.grid.rows - 1), @as(usize, @intCast(@max(1, bot_1) - 1)));
            if (top < bot) {
                screen.setScrollRegion(top, bot);
            }
        },
        else => {},
    }
}

fn handleSpecialCsi(
    context: SpecialCsiContext,
    action: parser_csi.CsiAction,
    param_len: usize,
    params: [parser_csi.max_params]i32,
) void {
    const screen = context.activeScreen();
    switch (action.final) {
        's' => {
            if (!action.private) {
                if (screen.left_right_margin_mode_69) {
                    const cols = @as(usize, screen.grid.cols);
                    if (cols == 0) return;
                    const left_1 = if (param_len > 0 and params[0] > 0) params[0] else 1;
                    const right_1 = if (param_len > 1 and params[1] > 0) params[1] else @as(i32, @intCast(cols));
                    const left = @min(cols - 1, @as(usize, @intCast(@max(1, left_1) - 1)));
                    const right = @min(cols - 1, @as(usize, @intCast(@max(1, right_1) - 1)));
                    if (left < right) {
                        screen.setLeftRightMargins(left, right);
                    }
                    return;
                }
                context.saveCursor();
            }
        },
        'u' => {
            if (action.leader == 0 and !action.private) {
                context.restoreCursor();
                return;
            }
            const flags: u32 = if (param_len > 0) @intCast(@max(0, params[0])) else 0;
            const mode: u32 = if (param_len > 1) @intCast(@max(0, params[1])) else 1;
            switch (action.leader) {
                '>' => context.keyModePushLocked(flags),
                '<' => context.keyModePopLocked(if (param_len > 0) @intCast(@max(1, params[0])) else 1),
                '=' => context.keyModeModifyLocked(flags, mode),
                '?' => context.keyModeQueryLocked(),
                else => {},
            }
        },
        'q' => {
            if (action.leader == 0 and !action.private) {
                context.setCursorStyle(if (param_len > 0) params[0] else 0);
            }
        },
        'g' => {
            switch (if (param_len > 0) params[0] else 0) {
                0 => screen.clearTabAtCursor(),
                3 => screen.clearAllTabs(),
                else => {},
            }
        },
        else => {},
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

pub fn writeDaPrimaryReply(pty: anytype) bool {
    return csi_reply.writeDaPrimaryReply(pty);
}

fn writeDaPrimaryReplyWithWriter(writer: CsiWriter) bool {
    return csi_reply.writeDaPrimaryReplyWithWriter(writer);
}

pub fn writeDsrReply(pty: anytype, leader: u8, mode: i32, row_1: usize, col_1: usize) bool {
    return csi_reply.writeDsrReply(pty, leader, mode, row_1, col_1);
}

fn writeDsrReplyWithWriter(writer: CsiWriter, leader: u8, mode: i32, row_1: usize, col_1: usize) bool {
    return csi_reply.writeDsrReplyWithWriter(writer, leader, mode, row_1, col_1);
}

pub fn writeDecrqmReply(pty: anytype, private: bool, mode: i32, state: DecrpmState) bool {
    return writeDecrqmReplyWithWriter(CsiWriter.from(pty), private, mode, state);
}

pub fn writeDecrqmReplyWithWriter(writer: CsiWriter, private: bool, mode: i32, state: DecrpmState) bool {
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

fn applyDecstrReset(context: DecstrContext) void {
    // DECSTR is a soft reset: reset parser/mode state but preserve screen contents,
    // scrollback, and kitty graphics. Do not call the hard reset path.
    context.resetParser();
    context.resetSavedCharset();
    context.clearTitleBuffer();
    context.setDefaultTitle();

    context.setReportColorScheme2031(false);
    context.setGraphemeClusterShaping2027(false);
    context.setPrimaryGraphemeClusterShaping2027(false);
    context.setAltGraphemeClusterShaping2027(false);
    context.setInbandResizeNotifications2048(false);
    context.setKittyPasteEvents5522(false);
    context.resetInputModesLocked();
    context.setColumnMode132(false);
    context.setSyncUpdatesLocked(false);

    // Reset kitty graphics state across both screens as part of DECSTR.
    // This follows foot-style soft reset behavior and avoids hidden-screen leaks.
    context.clearAllKittyImages();
    context.resetActiveScreenState();
    context.markActiveScreenDecstrDirty();
}



fn handleDsrQuery(query: QueryContext, writer: CsiWriter, screen: ScreenQueryContext, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
    csi_reply.handleDsrQuery(query, writer, screen, action, param_len, params);
}

fn handleDaQuery(writer: CsiWriter) void {
    csi_reply.handleDaQuery(writer);
}

fn handleWindowOpQuery(query: QueryContext, writer: CsiWriter, screen: ScreenQueryContext, param_len: usize, params: [parser_csi.max_params]i32) void {
    csi_reply.handleWindowOpQuery(query, writer, screen, param_len, params);
}

fn handleDecrqmQuery(writer: CsiWriter, action: parser_csi.CsiAction, mode: i32, snapshot: ModeSnapshot) void {
    csi_mode_query.handleDecrqmQuery(writer, action, mode, snapshot);
}

fn writeConst(writer: CsiWriter, seq: []const u8) bool {
    return csi_reply.writeConst(writer, seq);
}

pub fn writeColorSchemePreferenceReply(pty: anytype, dark: bool) bool {
    return csi_reply.writeColorSchemePreferenceReply(pty, dark);
}

fn writeColorSchemePreferenceReplyWithWriter(writer: CsiWriter, dark: bool) bool {
    return csi_reply.writeColorSchemePreferenceReplyWithWriter(writer, dark);
}

pub fn writeWindowOpCharsReply(pty: anytype, rows: u16, cols: u16) bool {
    return csi_reply.writeWindowOpCharsReply(pty, rows, cols);
}

fn writeWindowOpCharsReplyWithWriter(writer: CsiWriter, rows: u16, cols: u16) bool {
    return csi_reply.writeWindowOpCharsReplyWithWriter(writer, rows, cols);
}

pub fn writeWindowOpScreenCharsReply(pty: anytype, rows: u16, cols: u16) bool {
    return csi_reply.writeWindowOpScreenCharsReply(pty, rows, cols);
}

fn writeWindowOpScreenCharsReplyWithWriter(writer: CsiWriter, rows: u16, cols: u16) bool {
    return csi_reply.writeWindowOpScreenCharsReplyWithWriter(writer, rows, cols);
}

pub fn writeWindowOpPixelsReply(pty: anytype, height_px: u32, width_px: u32) bool {
    return csi_reply.writeWindowOpPixelsReply(pty, height_px, width_px);
}

fn writeWindowOpPixelsReplyWithWriter(writer: CsiWriter, height_px: u32, width_px: u32) bool {
    return csi_reply.writeWindowOpPixelsReplyWithWriter(writer, height_px, width_px);
}

pub fn writeWindowOpCellPixelsReply(pty: anytype, cell_h: u16, cell_w: u16) bool {
    return csi_reply.writeWindowOpCellPixelsReply(pty, cell_h, cell_w);
}

fn writeWindowOpCellPixelsReplyWithWriter(writer: CsiWriter, cell_h: u16, cell_w: u16) bool {
    return csi_reply.writeWindowOpCellPixelsReplyWithWriter(writer, cell_h, cell_w);
}

pub fn applySgr(context: SgrContext, action: parser_csi.CsiAction) void {
    const params = action.params;
    const n_params = effectiveSgrParamCount(action);
    const current_attrs = context.currentAttrs();
    const default_attrs = context.defaultAttrs();
    const log = app_logger.logger("terminal.sgr");
    log.logf(
        .debug,
        "sgr count={d} params={d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
        .{
            n_params,
            params[0],
            params[1],
            params[2],
            params[3],
            params[4],
            params[5],
            params[6],
            params[7],
            params[8],
            params[9],
            params[10],
            params[11],
            params[12],
            params[13],
            params[14],
            params[15],
        },
    );
    var i: usize = 0;
    while (i < n_params) {
        const p = params[i];
        if (p == 38 or p == 48 or p == 58) {
            if (i + 1 < n_params) {
                const mode = params[i + 1];
                if (mode == 5 and i + 2 < n_params) {
                    const idx = types.clampColorIndex(params[i + 2]);
                    const color = context.paletteColor(idx);
                    switch (p) {
                        38 => current_attrs.fg = color,
                        48 => current_attrs.bg = color,
                        58 => current_attrs.underline_color = color,
                        else => {},
                    }
                    i += 3;
                    continue;
                }
                if (mode == 2) {
                    // Parse 38/48/58;2;R;G;B (truecolor).
                    const base: usize = i + 2;
                    if (base + 2 < n_params) {
                        const r = types.clampColorIndex(params[base]);
                        const g = types.clampColorIndex(params[base + 1]);
                        const b = types.clampColorIndex(params[base + 2]);
                        const color = Color{ .r = r, .g = g, .b = b, .a = 255 };
                        switch (p) {
                            38 => current_attrs.fg = color,
                            48 => current_attrs.bg = color,
                            58 => current_attrs.underline_color = color,
                            else => {},
                        }
                        i = base + 3;
                        continue;
                    }
                }
                if (mode == 6) {
                    // WezTerm extension: RGBA (38;6;R;G;B;A).
                    const base: usize = i + 2;
                    if (base + 3 < n_params) {
                        const r = types.clampColorIndex(params[base]);
                        const g = types.clampColorIndex(params[base + 1]);
                        const b = types.clampColorIndex(params[base + 2]);
                        const a = types.clampColorIndex(params[base + 3]);
                        const color = Color{ .r = r, .g = g, .b = b, .a = a };
                        switch (p) {
                            38 => current_attrs.fg = color,
                            48 => current_attrs.bg = color,
                            58 => current_attrs.underline_color = color,
                            else => {},
                        }
                        i = base + 4;
                        continue;
                    }
                }
            }
            i += 1;
            continue;
        }
        switch (p) {
            0 => { // reset
                current_attrs.* = default_attrs.*;
            },
            1 => { // bold
                current_attrs.bold = true;
            },
            5 => { // blink (slow)
                current_attrs.blink = true;
                current_attrs.blink_fast = false;
            },
            6 => { // blink (fast)
                current_attrs.blink = true;
                current_attrs.blink_fast = true;
            },
            22 => { // normal intensity
                current_attrs.bold = false;
            },
            25 => { // blink off
                current_attrs.blink = false;
                current_attrs.blink_fast = false;
            },
            4 => { // underline
                current_attrs.underline = true;
            },
            24 => { // underline off
                current_attrs.underline = false;
            },
            7 => { // reverse
                current_attrs.reverse = true;
            },
            27 => { // reverse off
                current_attrs.reverse = false;
            },
            39 => { // default fg
                current_attrs.fg = default_attrs.fg;
            },
            49 => { // default bg
                current_attrs.bg = default_attrs.bg;
            },
            59 => {
                current_attrs.underline_color = default_attrs.underline_color;
            },
            30...37 => {
                const idx: u8 = @intCast(p - 30);
                current_attrs.fg = context.paletteColor(idx);
            },
            40...47 => {
                const idx: u8 = @intCast(p - 40);
                current_attrs.bg = context.paletteColor(idx);
            },
            90...97 => {
                const idx: u8 = @intCast(8 + (p - 90));
                current_attrs.fg = context.paletteColor(idx);
            },
            100...107 => {
                const idx: u8 = @intCast(8 + (p - 100));
                current_attrs.bg = context.paletteColor(idx);
            },
            else => {},
        }
        i += 1;
    }
}
