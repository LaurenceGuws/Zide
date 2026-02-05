const types = @import("../model/types.zig");

const mouse_button_left_mask: u8 = 1;
const mouse_button_middle_mask: u8 = 2;
const mouse_button_right_mask: u8 = 4;

pub fn mouseModBits(mod: types.Modifier) u8 {
    var value: u8 = 0;
    if ((mod & types.VTERM_MOD_SHIFT) != 0) value += 4;
    if ((mod & types.VTERM_MOD_ALT) != 0) value += 8;
    if ((mod & types.VTERM_MOD_CTRL) != 0) value += 16;
    return value;
}

pub fn mouseButtonFromMask(mask: u8) types.MouseButton {
    if ((mask & mouse_button_left_mask) != 0) return .left;
    if ((mask & mouse_button_middle_mask) != 0) return .middle;
    if ((mask & mouse_button_right_mask) != 0) return .right;
    return .none;
}

pub fn mouseButtonCode(button: types.MouseButton) u8 {
    return switch (button) {
        .left => 0,
        .middle => 1,
        .right => 2,
        .wheel_up => 64,
        .wheel_down => 65,
        .none => 3,
    };
}

pub fn mouseEncodeCoordX10(value: usize) u8 {
    const v = value + 1 + 32;
    if (v > 255) return 0;
    return @intCast(v);
}
