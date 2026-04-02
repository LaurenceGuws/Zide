const types = @import("../model/types.zig");
const input_mod = @import("../input/input.zig");

const VTERM_MOD_NONE = types.VTERM_MOD_NONE;

pub const KeyActionDispatch = enum {
    suppress,
    app_cursor,
    encoded,
};

pub const KeypadActionDispatch = struct {
    suppress: bool,
    emit: bool,
    app_keypad: bool,
};

pub const AlternateScrollDispatch = struct {
    active: bool,
    key: ?types.Key,
};

pub const CharActionDispatch = struct {
    suppress: bool,
    local_echo_eligible: bool,
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

pub fn decideKeypadAction(
    _: anytype,
    action: input_mod.KeyAction,
    auto_repeat_enabled: bool,
    app_keypad_enabled: bool,
) KeypadActionDispatch {
    if (action == .repeat and !auto_repeat_enabled) {
        return .{
            .suppress = true,
            .emit = false,
            .app_keypad = app_keypad_enabled,
        };
    }
    return .{
        .suppress = false,
        .emit = action == .press,
        .app_keypad = app_keypad_enabled,
    };
}

pub fn decideAlternateScrollStep(
    _: anytype,
    wheel_steps: i32,
    alternate_scroll_enabled: bool,
    alt_active: bool,
) AlternateScrollDispatch {
    if (wheel_steps == 0 or !alternate_scroll_enabled or !alt_active) {
        return .{
            .active = false,
            .key = null,
        };
    }
    return .{
        .active = true,
        .key = if (wheel_steps > 0) types.VTERM_KEY_UP else types.VTERM_KEY_DOWN,
    };
}

pub fn decideCharAction(
    _: anytype,
    char: u32,
    mod: types.Modifier,
    action: input_mod.KeyAction,
    auto_repeat_enabled: bool,
    local_echo_mode_12: bool,
) CharActionDispatch {
    if (action == .repeat and !auto_repeat_enabled) {
        return .{
            .suppress = true,
            .local_echo_eligible = false,
        };
    }
    return .{
        .suppress = false,
        .local_echo_eligible = action != .release and
            mod == types.VTERM_MOD_NONE and
            char >= 0x20 and
            char != 0x7F and
            char <= 0x10FFFF and
            !(char >= 0xD800 and char <= 0xDFFF) and
            local_echo_mode_12,
    };
}
