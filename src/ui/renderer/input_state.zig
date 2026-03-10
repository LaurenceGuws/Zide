const std = @import("std");
const input_events = @import("../../platform/input_events.zig");

pub const KeyPress = input_events.KeyPress;
pub const TextPress = input_events.TextPress;
pub const TextComposition = struct {
    text: []const u8,
    cursor: i32,
    selection_len: i32,
    active: bool,
};

pub const InputState = struct {
    key_down: []bool,
    key_pressed: []bool,
    key_repeated: []bool,
    key_released: []bool,
    mouse_down: []bool,
    mouse_pressed: []bool,
    mouse_released: []bool,
    mouse_clicks: []u8,
    key_queue: *std.ArrayList(KeyPress),
    char_queue: *std.ArrayList(TextPress),
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
    @memset(state.mouse_clicks, 0);
    state.window_resized_flag.* = false;
    state.mouse_wheel_delta.* = 0.0;
}

pub fn applyTextInputReset(state: InputState) void {
    if (!state.composing_active.*) return;
    state.composing_active.* = false;
    state.composing_text.clearRetainingCapacity();
    state.composing_cursor.* = 0;
    state.composing_selection_len.* = 0;
}

pub fn snapshotTextComposition(text: []const u8, cursor: i32, selection_len: i32, active: bool) TextComposition {
    return .{
        .text = text,
        .cursor = cursor,
        .selection_len = selection_len,
        .active = active,
    };
}

pub fn popKeyPress(queue: *std.ArrayList(KeyPress), head: *usize) ?KeyPress {
    if (head.* >= queue.items.len) return null;
    const value = queue.items[head.*];
    head.* += 1;
    return value;
}

pub fn isKeyActive(keys: []const bool, key: i32) bool {
    if (key < 0) return false;
    const idx: usize = @intCast(key);
    if (idx >= keys.len) return false;
    return keys[idx];
}

pub fn isMouseButtonActive(buttons: []const bool, button: i32) bool {
    if (button < 0) return false;
    const idx: usize = @intCast(button);
    if (idx >= buttons.len) return false;
    return buttons[idx];
}

pub fn resetMouseWheel(delta: *f32) void {
    delta.* = 0.0;
}

pub fn addMouseWheel(delta: *f32, value: f32) void {
    delta.* += value;
}
