const terminal_mod = @import("../core/terminal.zig");
const input_types = @import("../../types/input.zig");

pub const TerminalSession = terminal_mod.TerminalSession;
pub const Modifier = terminal_mod.Modifier;
pub const KeyAction = terminal_mod.KeyAction;

pub fn sendKeyAction(session: *TerminalSession, key: input_types.Key, key_mod: Modifier, action: KeyAction) !bool {
    switch (key) {
        .enter => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_ENTER, key_mod, action);
            return true;
        },
        .backspace => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_BACKSPACE, key_mod, action);
            return true;
        },
        .tab => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_TAB, key_mod, action);
            return true;
        },
        .escape => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_ESCAPE, key_mod, action);
            return true;
        },
        .up => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_UP, key_mod, action);
            return true;
        },
        .down => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_DOWN, key_mod, action);
            return true;
        },
        .left => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_LEFT, key_mod, action);
            return true;
        },
        .right => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_RIGHT, key_mod, action);
            return true;
        },
        .home => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_HOME, key_mod, action);
            return true;
        },
        .end => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_END, key_mod, action);
            return true;
        },
        .page_up => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_PAGEUP, key_mod, action);
            return true;
        },
        .page_down => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_PAGEDOWN, key_mod, action);
            return true;
        },
        .insert => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_INS, key_mod, action);
            return true;
        },
        .delete => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_DEL, key_mod, action);
            return true;
        },
        .kp_0 => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp0, key_mod, action);
            return true;
        },
        .kp_1 => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp1, key_mod, action);
            return true;
        },
        .kp_2 => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp2, key_mod, action);
            return true;
        },
        .kp_3 => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp3, key_mod, action);
            return true;
        },
        .kp_4 => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp4, key_mod, action);
            return true;
        },
        .kp_5 => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp5, key_mod, action);
            return true;
        },
        .kp_6 => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp6, key_mod, action);
            return true;
        },
        .kp_7 => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp7, key_mod, action);
            return true;
        },
        .kp_8 => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp8, key_mod, action);
            return true;
        },
        .kp_9 => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp9, key_mod, action);
            return true;
        },
        .kp_decimal => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp_decimal, key_mod, action);
            return true;
        },
        .kp_divide => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp_divide, key_mod, action);
            return true;
        },
        .kp_multiply => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp_multiply, key_mod, action);
            return true;
        },
        .kp_subtract => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp_subtract, key_mod, action);
            return true;
        },
        .kp_add => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp_add, key_mod, action);
            return true;
        },
        .kp_enter => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp_enter, key_mod, action);
            return true;
        },
        .kp_equal => {
            try session.sendKeypadAction(terminal_mod.KeypadKey.kp_equal, key_mod, action);
            return true;
        },
        .left_shift => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_LEFT_SHIFT, key_mod, action);
            return true;
        },
        .right_shift => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_RIGHT_SHIFT, key_mod, action);
            return true;
        },
        .left_ctrl => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_LEFT_CTRL, key_mod, action);
            return true;
        },
        .right_ctrl => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_RIGHT_CTRL, key_mod, action);
            return true;
        },
        .left_alt => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_LEFT_ALT, key_mod, action);
            return true;
        },
        .right_alt => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_RIGHT_ALT, key_mod, action);
            return true;
        },
        .left_super => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_LEFT_SUPER, key_mod, action);
            return true;
        },
        .right_super => {
            try session.sendKeyAction(terminal_mod.VTERM_KEY_RIGHT_SUPER, key_mod, action);
            return true;
        },
        else => return false,
    }
}

pub fn isRepeatKey(key: input_types.Key) bool {
    return switch (key) {
        .enter,
        .backspace,
        .tab,
        .escape,
        .up,
        .down,
        .left,
        .right,
        .home,
        .end,
        .page_up,
        .page_down,
        .insert,
        .delete,
        .kp_0,
        .kp_1,
        .kp_2,
        .kp_3,
        .kp_4,
        .kp_5,
        .kp_6,
        .kp_7,
        .kp_8,
        .kp_9,
        .kp_decimal,
        .kp_divide,
        .kp_multiply,
        .kp_subtract,
        .kp_add,
        .kp_enter,
        .kp_equal,
        => true,
        else => false,
    };
}

pub const repeat_keys = [_]input_types.Key{
    .enter,
    .backspace,
    .tab,
    .escape,
    .up,
    .down,
    .left,
    .right,
    .home,
    .end,
    .page_up,
    .page_down,
    .insert,
    .delete,
    .kp_0,
    .kp_1,
    .kp_2,
    .kp_3,
    .kp_4,
    .kp_5,
    .kp_6,
    .kp_7,
    .kp_8,
    .kp_9,
    .kp_decimal,
    .kp_divide,
    .kp_multiply,
    .kp_subtract,
    .kp_add,
    .kp_enter,
    .kp_equal,
};
