const std = @import("std");
const gl = @import("gl.zig");
const sdl = gl.c;

pub fn setText(text: [*:0]const u8) void {
    _ = sdl.SDL_SetClipboardText(text);
}

pub fn getText() ?[]u8 {
    const ptr = sdl.SDL_GetClipboardText();
    if (ptr == null) return null;
    const slice = std.mem.span(ptr);
    return slice;
}

pub fn freeText(text: []u8) void {
    sdl.SDL_free(@ptrCast(text.ptr));
}
