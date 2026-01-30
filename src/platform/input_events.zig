const gl = @import("../ui/renderer/gl.zig");
const std = @import("std");

const sdl = gl.c;

pub const KeyPress = struct {
    scancode: i32,
    repeated: bool,
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
    const sc = @as(i32, @intCast(event.key.keysym.scancode));
    const sym = @as(i32, @intCast(event.key.keysym.sym));
    const repeat: u8 = @intCast(event.key.repeat);
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
    const sc = @as(i32, @intCast(event.key.keysym.scancode));
    const sym = @as(i32, @intCast(event.key.keysym.sym));
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
    return @floatFromInt(event.wheel.y);
}

pub fn handleTextInput(
    event: *const sdl.SDL_Event,
    char_queue: *std.ArrayList(u32),
    allocator: std.mem.Allocator,
) usize {
    const text = std.mem.span(@as([*:0]const u8, @ptrCast(&event.text.text)));
    var it = std.unicode.Utf8View.initUnchecked(text).iterator();
    while (it.nextCodepoint()) |cp| {
        _ = char_queue.append(allocator, cp) catch {};
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
    const text = std.mem.span(@as([*:0]const u8, @ptrCast(&event.edit.text)));
    composing_text.clearRetainingCapacity();
    _ = composing_text.appendSlice(allocator, text) catch {};
    composing_cursor.* = event.edit.start;
    composing_selection_len.* = event.edit.length;
    composing_active.* = text.len > 0;
    return .{
        .bytes = text.len,
        .cursor = event.edit.start,
        .selection_len = event.edit.length,
        .active = text.len > 0,
    };
}
