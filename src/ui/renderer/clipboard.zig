const std = @import("std");
const sdl_api = @import("../../platform/sdl_api.zig");

pub fn setText(text: [*:0]const u8) void {
    sdl_api.setClipboardText(text);
}

pub fn getText() ?[]const u8 {
    return sdl_api.getClipboardText();
}

pub fn freeText(text: []const u8) void {
    sdl_api.freeClipboardText(text);
}

pub fn getData(mime_type: [*:0]const u8) ?[]const u8 {
    return sdl_api.getClipboardData(mime_type);
}

pub fn freeData(data: []const u8) void {
    sdl_api.freeClipboardData(data);
}
