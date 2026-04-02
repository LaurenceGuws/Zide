const std = @import("std");
const input_events = @import("../../platform/input_events.zig");
const iface = @import("interface.zig");
const text_input = @import("text_input.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

pub const KeyPress = input_events.KeyPress;
pub const TextPress = input_events.TextPress;
const key_repeat_key_count: usize = sdl_api.scancode_count;
const mouse_button_count: usize = 8;

pub const TextComposition = struct {
    text: []const u8,
    cursor: i32,
    selection_len: i32,
    active: bool,
};

pub const InputRuntimeState = struct {
    key_down: [key_repeat_key_count]bool = [_]bool{false} ** key_repeat_key_count,
    key_pressed: [key_repeat_key_count]bool = [_]bool{false} ** key_repeat_key_count,
    key_repeated: [key_repeat_key_count]bool = [_]bool{false} ** key_repeat_key_count,
    key_released: [key_repeat_key_count]bool = [_]bool{false} ** key_repeat_key_count,
    mouse_down: [mouse_button_count]bool = [_]bool{false} ** mouse_button_count,
    mouse_pressed: [mouse_button_count]bool = [_]bool{false} ** mouse_button_count,
    mouse_released: [mouse_button_count]bool = [_]bool{false} ** mouse_button_count,
    mouse_clicks: [mouse_button_count]u8 = [_]u8{0} ** mouse_button_count,
    mouse_press_pos: [mouse_button_count]iface.MousePos = [_]iface.MousePos{.{ .x = 0, .y = 0 }} ** mouse_button_count,
    mouse_press_pos_valid: [mouse_button_count]bool = [_]bool{false} ** mouse_button_count,
    key_queue: std.ArrayList(KeyPress) = std.ArrayList(KeyPress).empty,
    key_queue_head: usize = 0,
    char_queue: std.ArrayList(TextPress) = std.ArrayList(TextPress).empty,
    char_queue_head: usize = 0,
    focus_queue: std.ArrayList(bool) = std.ArrayList(bool).empty,
    focus_queue_head: usize = 0,
    window_focused: bool = true,
    composing_text: std.ArrayList(u8) = std.ArrayList(u8).empty,
    composing_cursor: i32 = 0,
    composing_selection_len: i32 = 0,
    composing_active: bool = false,
    window_resized_flag: bool = false,
    text_input_state: text_input.TextInputState = text_input.initState(),
    pending_wait_event: sdl_api.c.SDL_Event = undefined,
    pending_wait_event_valid: bool = false,
};

pub const InputDomain = struct {
    allocator: std.mem.Allocator,
    window: *sdl_api.c.SDL_Window,
    mouse_scale: iface.MousePos,
    should_close_flag: *bool,
    key_down: []bool,
    key_pressed: []bool,
    key_repeated: []bool,
    key_released: []bool,
    mouse_down: []bool,
    mouse_pressed: []bool,
    mouse_released: []bool,
    mouse_clicks: []u8,
    mouse_press_pos: []iface.MousePos,
    mouse_press_pos_valid: []bool,
    key_queue: *std.ArrayList(KeyPress),
    key_queue_head: *usize,
    char_queue: *std.ArrayList(TextPress),
    char_queue_head: *usize,
    focus_queue: *std.ArrayList(bool),
    focus_queue_head: *usize,
    window_focused: *bool,
    composing_text: *std.ArrayList(u8),
    composing_cursor: *i32,
    composing_selection_len: *i32,
    composing_active: *bool,
    window_resized_flag: *bool,
    text_input_state: *text_input.TextInputState,
    pending_wait_event: *sdl_api.c.SDL_Event,
    pending_wait_event_valid: *bool,
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

pub fn snapshotTextCompositionDomain(domain: InputDomain) TextComposition {
    return snapshotTextComposition(
        domain.composing_text.items,
        domain.composing_cursor.*,
        domain.composing_selection_len.*,
        domain.composing_active.*,
    );
}

pub fn popKeyPress(queue: *std.ArrayList(KeyPress), head: *usize) ?KeyPress {
    if (head.* >= queue.items.len) return null;
    const value = queue.items[head.*];
    head.* += 1;
    return value;
}

pub fn popTextPress(queue: *std.ArrayList(TextPress), head: *usize) ?TextPress {
    if (head.* >= queue.items.len) return null;
    const value = queue.items[head.*];
    head.* += 1;
    return value;
}

pub fn popFocusEvent(queue: *std.ArrayList(bool), head: *usize) ?bool {
    if (head.* >= queue.items.len) return null;
    const value = queue.items[head.*];
    head.* += 1;
    return value;
}

pub fn popCharPressed(domain: InputDomain) ?u32 {
    const value = popTextPress(domain.char_queue, domain.char_queue_head) orelse return null;
    return value.codepoint;
}

pub fn popTextPressed(domain: InputDomain) ?TextPress {
    return popTextPress(domain.char_queue, domain.char_queue_head);
}

pub fn popFocusQueued(domain: InputDomain) ?bool {
    return popFocusEvent(domain.focus_queue, domain.focus_queue_head);
}

pub fn popKeyPressed(domain: InputDomain) ?KeyPress {
    return popKeyPress(domain.key_queue, domain.key_queue_head);
}

pub fn isKeyActive(keys: []const bool, key: i32) bool {
    if (key < 0) return false;
    const idx: usize = @intCast(key);
    if (idx >= keys.len) return false;
    return keys[idx];
}

pub fn isKeyDown(domain: InputDomain, key: i32) bool {
    return isKeyActive(domain.key_down, key);
}

pub fn isKeyPressed(domain: InputDomain, key: i32) bool {
    return isKeyActive(domain.key_pressed, key);
}

pub fn isKeyRepeated(domain: InputDomain, key: i32) bool {
    return isKeyActive(domain.key_repeated, key);
}

pub fn isKeyReleased(domain: InputDomain, key: i32) bool {
    return isKeyActive(domain.key_released, key);
}

pub fn isMouseButtonActive(buttons: []const bool, button: i32) bool {
    if (button < 0) return false;
    const idx: usize = @intCast(button);
    if (idx >= buttons.len) return false;
    return buttons[idx];
}

pub fn isMouseButtonPressed(domain: InputDomain, button: i32) bool {
    return isMouseButtonActive(domain.mouse_pressed, button);
}

pub fn isMouseButtonDown(domain: InputDomain, button: i32) bool {
    return isMouseButtonActive(domain.mouse_down, button);
}

pub fn isMouseButtonReleased(domain: InputDomain, button: i32) bool {
    return isMouseButtonActive(domain.mouse_released, button);
}

pub fn mouseButtonClicks(domain: InputDomain, button: i32) u8 {
    if (button < 0) return 0;
    const idx: usize = @intCast(button);
    if (idx >= domain.mouse_clicks.len) return 0;
    return domain.mouse_clicks[idx];
}

pub fn mouseButtonPressPos(domain: InputDomain, button: i32) ?iface.MousePos {
    if (button < 0) return null;
    const idx: usize = @intCast(button);
    if (idx >= domain.mouse_press_pos_valid.len) return null;
    if (!domain.mouse_press_pos_valid[idx]) return null;
    return domain.mouse_press_pos[idx];
}

pub fn anyMouseButtonsDown(domain: InputDomain) bool {
    for (domain.mouse_down) |down| {
        if (down) return true;
    }
    return false;
}

pub fn windowFocused(domain: InputDomain) bool {
    return domain.window_focused.*;
}

pub fn windowResized(domain: InputDomain) bool {
    return domain.window_resized_flag.*;
}

pub fn hasPendingWaitEvent(domain: InputDomain) bool {
    return domain.pending_wait_event_valid.*;
}

pub fn stagePendingWaitEvent(domain: InputDomain, event: sdl_api.c.SDL_Event) void {
    domain.pending_wait_event.* = event;
    domain.pending_wait_event_valid.* = true;
}

pub fn resetMouseWheel(delta: *f32) void {
    delta.* = 0.0;
}

pub fn addMouseWheel(delta: *f32, value: f32) void {
    delta.* += value;
}

pub fn startTextInput(domain: InputDomain) void {
    sdl_api.startTextInput(domain.window);
}

pub fn stopTextInput(domain: InputDomain) void {
    sdl_api.stopTextInput(domain.window);
}

pub fn deinit(domain: InputDomain) void {
    domain.key_queue.deinit(domain.allocator);
    domain.char_queue.deinit(domain.allocator);
    domain.focus_queue.deinit(domain.allocator);
    domain.composing_text.deinit(domain.allocator);
}
