const input_events = @import("../../platform/input_events.zig");
const std = @import("std");
const text_composition = @import("text_composition.zig");

pub const KeyPress = input_events.KeyPress;

pub const InputState = struct {
    key_down: []bool,
    key_pressed: []bool,
    key_repeated: []bool,
    key_released: []bool,
    mouse_down: []bool,
    mouse_pressed: []bool,
    mouse_released: []bool,
    key_queue: *std.ArrayList(KeyPress),
    char_queue: *std.ArrayList(u32),
    composing_text: *std.ArrayList(u8),
    composing_cursor: *i32,
    composing_selection_len: *i32,
    composing_active: *bool,
    mouse_wheel_delta: *f32,
    window_resized_flag: *bool,
};

pub fn resetForFrame(state: InputState) void {
    @memset(state.key_pressed, false);
    @memset(state.key_repeated, false);
    @memset(state.key_released, false);
    @memset(state.mouse_pressed, false);
    @memset(state.mouse_released, false);
    state.window_resized_flag.* = false;
    state.mouse_wheel_delta.* = 0.0;
}

pub fn applyTextInputReset(state: InputState) void {
    text_composition.reset(
        state.composing_text,
        state.composing_cursor,
        state.composing_selection_len,
        state.composing_active,
    );
}
