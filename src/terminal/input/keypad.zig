const input_mod = @import("input.zig");

pub fn keypadChar(key: input_mod.KeypadKey) ?u32 {
    return switch (key) {
        .kp0 => '0',
        .kp1 => '1',
        .kp2 => '2',
        .kp3 => '3',
        .kp4 => '4',
        .kp5 => '5',
        .kp6 => '6',
        .kp7 => '7',
        .kp8 => '8',
        .kp9 => '9',
        .kp_decimal => '.',
        .kp_divide => '/',
        .kp_multiply => '*',
        .kp_subtract => '-',
        .kp_add => '+',
        .kp_enter => '\r',
        .kp_equal => '=',
    };
}

pub fn keypadAppCode(key: input_mod.KeypadKey) ?u8 {
    return switch (key) {
        .kp0 => 'p',
        .kp1 => 'q',
        .kp2 => 'r',
        .kp3 => 's',
        .kp4 => 't',
        .kp5 => 'u',
        .kp6 => 'v',
        .kp7 => 'w',
        .kp8 => 'x',
        .kp9 => 'y',
        .kp_decimal => 'n',
        .kp_divide => 'o',
        .kp_multiply => 'j',
        .kp_subtract => 'm',
        .kp_add => 'k',
        .kp_enter => 'M',
        .kp_equal => 'X',
    };
}
