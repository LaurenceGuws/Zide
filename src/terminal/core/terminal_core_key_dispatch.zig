const types = @import("../model/types.zig");
const input_mod = @import("../input/input.zig");

const VTERM_MOD_NONE = types.VTERM_MOD_NONE;

pub const KeyActionDispatch = enum {
    suppress,
    app_cursor,
    encoded,
};

pub fn decideKeyAction(
    _: anytype,
    key: types.Key,
    mod: types.Modifier,
    action: input_mod.KeyAction,
    auto_repeat_enabled: bool,
    app_cursor_enabled: bool,
    key_mode_flags: u32,
) KeyActionDispatch {
    if (action == .repeat and !auto_repeat_enabled) return .suppress;
    if (key_mode_flags == 0 and app_cursor_enabled and mod == VTERM_MOD_NONE and action == .press and appCursorSequence(key) != null) {
        return .app_cursor;
    }
    return .encoded;
}

pub fn appCursorSequence(key: types.Key) ?[]const u8 {
    return switch (key) {
        types.VTERM_KEY_UP => "\x1bOA",
        types.VTERM_KEY_DOWN => "\x1bOB",
        types.VTERM_KEY_RIGHT => "\x1bOC",
        types.VTERM_KEY_LEFT => "\x1bOD",
        types.VTERM_KEY_HOME => "\x1bOH",
        types.VTERM_KEY_END => "\x1bOF",
        else => null,
    };
}
