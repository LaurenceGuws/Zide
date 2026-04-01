const input_mod = @import("../../input/input.zig");
const session_input_snapshot = @import("input_snapshot.zig");

pub const Fields = struct {
    bracketed_paste: bool,
    focus_reporting: bool,
    auto_repeat: bool,
    app_cursor_keys: bool,
    app_keypad: bool,
    mouse_alternate_scroll: bool,
    inband_resize_notifications_2048: bool,
    report_color_scheme_2031: bool,
    grapheme_cluster_shaping_2027: bool,
    color_scheme_dark: bool,
    kitty_paste_events_5522: bool,
    input: input_mod.InputState,
    input_snapshot: session_input_snapshot.InputSnapshot,
    cell_width: u16,
    cell_height: u16,
};
