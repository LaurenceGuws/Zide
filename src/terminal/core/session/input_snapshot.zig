const std = @import("std");

pub const InputSnapshot = struct {
    app_cursor_keys: std.atomic.Value(bool),
    app_keypad: std.atomic.Value(bool),
    key_mode_flags: std.atomic.Value(u32),
    mouse_mode_x10: std.atomic.Value(bool),
    mouse_mode_button: std.atomic.Value(bool),
    mouse_mode_any: std.atomic.Value(bool),
    mouse_mode_sgr: std.atomic.Value(bool),
    mouse_mode_sgr_pixels_1016: std.atomic.Value(bool),
    focus_reporting: std.atomic.Value(bool),
    bracketed_paste: std.atomic.Value(bool),
    auto_repeat: std.atomic.Value(bool),
    mouse_alternate_scroll: std.atomic.Value(bool),
    alt_active: std.atomic.Value(bool),
    screen_rows: std.atomic.Value(u16),
    screen_cols: std.atomic.Value(u16),

    pub fn init() InputSnapshot {
        return .{
            .app_cursor_keys = std.atomic.Value(bool).init(false),
            .app_keypad = std.atomic.Value(bool).init(false),
            .key_mode_flags = std.atomic.Value(u32).init(0),
            .mouse_mode_x10 = std.atomic.Value(bool).init(false),
            .mouse_mode_button = std.atomic.Value(bool).init(false),
            .mouse_mode_any = std.atomic.Value(bool).init(false),
            .mouse_mode_sgr = std.atomic.Value(bool).init(false),
            .mouse_mode_sgr_pixels_1016 = std.atomic.Value(bool).init(false),
            .focus_reporting = std.atomic.Value(bool).init(false),
            .bracketed_paste = std.atomic.Value(bool).init(false),
            .auto_repeat = std.atomic.Value(bool).init(true),
            .mouse_alternate_scroll = std.atomic.Value(bool).init(true),
            .alt_active = std.atomic.Value(bool).init(false),
            .screen_rows = std.atomic.Value(u16).init(0),
            .screen_cols = std.atomic.Value(u16).init(0),
        };
    }
};
