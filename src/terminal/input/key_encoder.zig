const types = @import("../model/types.zig");
const input_mod = @import("input.zig");
const input_types = @import("../../types/input.zig");

pub const Modifier = types.Modifier;

pub const key_mode_disambiguate: u32 = 1;
pub const key_mode_report_all_event_types: u32 = 2;
pub const key_mode_report_alternate_key: u32 = 4;
pub const key_mode_report_text: u32 = 8;
pub const key_mode_embed_text: u32 = 16;

fn keyAltMetadata(key: input_types.Key, base_codepoint: ?u32) types.KeyboardAlternateMetadata {
    return .{
        .physical_key = @as(types.PhysicalKey, @intCast(@intFromEnum(key))),
        .base_codepoint = base_codepoint,
    };
}

fn sessionSendMappedKeyAction(session: anytype, source_key: input_types.Key, term_key: types.Key, key_mod: Modifier, action: anytype) !void {
    const owner_type = @TypeOf(session.*);
    if (@hasDecl(owner_type, "sendKeyActionWithMetadata")) {
        try session.sendKeyActionWithMetadata(term_key, key_mod, action, keyAltMetadata(source_key, null));
        return;
    }
    try session.sendKeyAction(term_key, key_mod, action);
}

fn sessionSendMappedCharAction(session: anytype, source_key: input_types.Key, ch: u32, key_mod: Modifier, action: anytype) !void {
    const owner_type = @TypeOf(session.*);
    if (@hasDecl(owner_type, "sendCharActionWithMetadata")) {
        try session.sendCharActionWithMetadata(ch, key_mod, action, keyAltMetadata(source_key, ch));
        return;
    }
    try session.sendCharAction(ch, key_mod, action);
}

pub fn sendKeyAction(session: anytype, key: input_types.Key, key_mod: Modifier, action: anytype) !bool {
    switch (key) {
        .enter => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_ENTER, key_mod, action);
            return true;
        },
        .backspace => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_BACKSPACE, key_mod, action);
            return true;
        },
        .tab => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_TAB, key_mod, action);
            return true;
        },
        .escape => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_ESCAPE, key_mod, action);
            return true;
        },
        .up => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_UP, key_mod, action);
            return true;
        },
        .down => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_DOWN, key_mod, action);
            return true;
        },
        .left => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_LEFT, key_mod, action);
            return true;
        },
        .right => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_RIGHT, key_mod, action);
            return true;
        },
        .home => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_HOME, key_mod, action);
            return true;
        },
        .end => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_END, key_mod, action);
            return true;
        },
        .page_up => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_PAGEUP, key_mod, action);
            return true;
        },
        .page_down => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_PAGEDOWN, key_mod, action);
            return true;
        },
        .insert => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_INS, key_mod, action);
            return true;
        },
        .delete => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_DEL, key_mod, action);
            return true;
        },
        .kp_0 => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp0, key_mod, action);
            return true;
        },
        .kp_1 => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp1, key_mod, action);
            return true;
        },
        .kp_2 => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp2, key_mod, action);
            return true;
        },
        .kp_3 => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp3, key_mod, action);
            return true;
        },
        .kp_4 => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp4, key_mod, action);
            return true;
        },
        .kp_5 => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp5, key_mod, action);
            return true;
        },
        .kp_6 => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp6, key_mod, action);
            return true;
        },
        .kp_7 => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp7, key_mod, action);
            return true;
        },
        .kp_8 => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp8, key_mod, action);
            return true;
        },
        .kp_9 => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp9, key_mod, action);
            return true;
        },
        .kp_decimal => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp_decimal, key_mod, action);
            return true;
        },
        .kp_divide => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp_divide, key_mod, action);
            return true;
        },
        .kp_multiply => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp_multiply, key_mod, action);
            return true;
        },
        .kp_subtract => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp_subtract, key_mod, action);
            return true;
        },
        .kp_add => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp_add, key_mod, action);
            return true;
        },
        .kp_enter => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp_enter, key_mod, action);
            return true;
        },
        .kp_equal => {
            try session.sendKeypadAction(input_mod.KeypadKey.kp_equal, key_mod, action);
            return true;
        },
        .left_shift => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_LEFT_SHIFT, key_mod, action);
            return true;
        },
        .right_shift => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_RIGHT_SHIFT, key_mod, action);
            return true;
        },
        .left_ctrl => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_LEFT_CTRL, key_mod, action);
            return true;
        },
        .right_ctrl => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_RIGHT_CTRL, key_mod, action);
            return true;
        },
        .left_alt => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_LEFT_ALT, key_mod, action);
            return true;
        },
        .right_alt => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_RIGHT_ALT, key_mod, action);
            return true;
        },
        .left_super => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_LEFT_SUPER, key_mod, action);
            return true;
        },
        .right_super => {
            try sessionSendMappedKeyAction(session, key, types.VTERM_KEY_RIGHT_SUPER, key_mod, action);
            return true;
        },
        else => return false,
    }
}

pub fn sendCharForKey(
    session: anytype,
    key: input_types.Key,
    key_mod: Modifier,
    action: anytype,
    ctrl: bool,
    alt: bool,
) !bool {
    if (!ctrl and !alt) return false;
    const base_char = baseCharForKey(key) orelse return false;
    if (ctrl and !ctrlAllowsChar(base_char)) return false;
    try sessionSendMappedCharAction(session, key, base_char, key_mod, action);
    return true;
}

pub fn baseCharForKey(key: input_types.Key) ?u32 {
    return switch (key) {
        .a => 'a',
        .b => 'b',
        .c => 'c',
        .d => 'd',
        .e => 'e',
        .f => 'f',
        .g => 'g',
        .h => 'h',
        .i => 'i',
        .j => 'j',
        .k => 'k',
        .l => 'l',
        .m => 'm',
        .n => 'n',
        .o => 'o',
        .p => 'p',
        .q => 'q',
        .r => 'r',
        .s => 's',
        .t => 't',
        .u => 'u',
        .v => 'v',
        .w => 'w',
        .x => 'x',
        .y => 'y',
        .z => 'z',
        .zero => '0',
        .one => '1',
        .two => '2',
        .three => '3',
        .four => '4',
        .five => '5',
        .six => '6',
        .seven => '7',
        .eight => '8',
        .nine => '9',
        .space => ' ',
        .minus => '-',
        .equal => '=',
        .left_bracket => '[',
        .right_bracket => ']',
        .backslash => '\\',
        .semicolon => ';',
        .apostrophe => '\'',
        .grave => '`',
        .comma => ',',
        .period => '.',
        .slash => '/',
        else => null,
    };
}

pub fn ctrlAllowsChar(ch: u32) bool {
    return switch (ch) {
        'a'...'z', 'A'...'Z', '@', '[', '\\', ']', '^', '_', '?', ' ' => true,
        else => false,
    };
}

pub fn reportTextEnabled(flags: u32) bool {
    return (flags & key_mode_report_text) != 0;
}

pub fn embedTextEnabled(flags: u32) bool {
    return (flags & key_mode_embed_text) != 0;
}

pub fn reportAllEventTypes(flags: u32) bool {
    return (flags & key_mode_report_all_event_types) != 0;
}

pub fn disambiguateEnabled(flags: u32) bool {
    return (flags & key_mode_disambiguate) != 0;
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
