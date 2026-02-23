const gl = @import("../ui/renderer/gl.zig");
const sdl_api = @import("sdl_api.zig");
const std = @import("std");

const sdl = gl.c;

pub const KeyPress = struct {
    scancode: i32,
    sym: i32,
    repeated: bool,
};

pub const TextPress = struct {
    codepoint: u32,
    utf8_len: u8,
    utf8: [4]u8,
    text_is_composed: bool,
};

pub const KeyEventInfo = struct {
    scancode: i32,
    sym: i32,
    repeat: u8,
    handled: bool,
};

pub const TextEditInfo = struct {
    bytes: usize,
    cursor: i32,
    selection_len: i32,
    active: bool,
};

pub fn handleKeyDown(
    event: *const sdl.SDL_Event,
    key_down: []bool,
    key_pressed: []bool,
    key_repeated: []bool,
    key_queue: *std.ArrayList(KeyPress),
    allocator: std.mem.Allocator,
) KeyEventInfo {
    const sc = sdl_api.keyScancode(event);
    const sym = sdl_api.keySym(event);
    const repeat: u8 = sdl_api.keyRepeat(event);
    var handled = false;
    if (sc >= 0 and @as(usize, @intCast(sc)) < key_down.len) {
        key_down[@intCast(sc)] = true;
        if (repeat == 0) {
            key_pressed[@intCast(sc)] = true;
        } else {
            key_repeated[@intCast(sc)] = true;
        }
        _ = key_queue.append(allocator, .{
            .scancode = sc,
            .sym = sym,
            .repeated = repeat != 0,
        }) catch {};
        handled = true;
    }
    return .{ .scancode = sc, .sym = sym, .repeat = repeat, .handled = handled };
}

pub fn handleKeyUp(
    event: *const sdl.SDL_Event,
    key_down: []bool,
    key_released: []bool,
) KeyEventInfo {
    const sc = sdl_api.keyScancode(event);
    const sym = sdl_api.keySym(event);
    var handled = false;
    if (sc >= 0 and @as(usize, @intCast(sc)) < key_down.len) {
        key_down[@intCast(sc)] = false;
        key_released[@intCast(sc)] = true;
        handled = true;
    }
    return .{ .scancode = sc, .sym = sym, .repeat = 0, .handled = handled };
}

pub fn handleMouseButtonDown(
    event: *const sdl.SDL_Event,
    mouse_down: []bool,
    mouse_pressed: []bool,
) void {
    const btn = @as(i32, @intCast(event.button.button));
    if (btn >= 0 and @as(usize, @intCast(btn)) < mouse_down.len) {
        mouse_down[@intCast(btn)] = true;
        mouse_pressed[@intCast(btn)] = true;
    }
}

pub fn handleMouseButtonUp(
    event: *const sdl.SDL_Event,
    mouse_down: []bool,
    mouse_released: []bool,
) void {
    const btn = @as(i32, @intCast(event.button.button));
    if (btn >= 0 and @as(usize, @intCast(btn)) < mouse_down.len) {
        mouse_down[@intCast(btn)] = false;
        mouse_released[@intCast(btn)] = true;
    }
}

pub fn wheelDelta(event: *const sdl.SDL_Event) f32 {
    return sdl_api.wheelDelta(event);
}

pub fn handleTextInput(
    event: *const sdl.SDL_Event,
    char_queue: *std.ArrayList(TextPress),
    allocator: std.mem.Allocator,
    text_is_composed: bool,
) usize {
    const len = sdl_api.textInputLen(event);
    const text_field = event.text;
    const text = if (@hasField(@TypeOf(text_field), "text"))
        sdl_api.textSpanWithLen(text_field.text, len)
    else
        "";
    var it = std.unicode.Utf8View.init(text) catch return 0;
    var iter = it.iterator();
    while (iter.nextCodepoint()) |cp| {
        var utf8: [4]u8 = .{ 0, 0, 0, 0 };
        const utf8_len: u8 = @intCast(std.unicode.utf8Encode(cp, &utf8) catch 0);
        _ = char_queue.append(allocator, .{
            .codepoint = cp,
            .utf8_len = utf8_len,
            .utf8 = utf8,
            .text_is_composed = text_is_composed,
        }) catch {};
    }
    return text.len;
}

pub fn handleTextEditing(
    event: *const sdl.SDL_Event,
    composing_text: *std.ArrayList(u8),
    composing_cursor: *i32,
    composing_selection_len: *i32,
    composing_active: *bool,
    allocator: std.mem.Allocator,
) TextEditInfo {
    const len = sdl_api.textEditingLen(event);
    const edit_field = event.edit;
    const text = if (@hasField(@TypeOf(edit_field), "text"))
        sdl_api.textSpanWithLen(edit_field.text, len)
    else
        "";
    const cursor = sdl_api.textEditingCursor(event);
    const selection_len = sdl_api.textEditingSelectionLen(event);
    composing_text.clearRetainingCapacity();
    _ = composing_text.appendSlice(allocator, text) catch {};
    composing_cursor.* = cursor;
    composing_selection_len.* = selection_len;
    composing_active.* = text.len > 0;
    return .{
        .bytes = text.len,
        .cursor = cursor,
        .selection_len = selection_len,
        .active = text.len > 0,
    };
}
