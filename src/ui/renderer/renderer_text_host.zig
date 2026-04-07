const iface = @import("interface.zig");
const text_runtime = @import("text_runtime.zig");

const Color = iface.Color;

pub fn drawText(renderer: anytype, text: []const u8, x: f32, y: f32, color: Color) void {
    text_runtime.drawText(renderer, text, x, y, color);
}

pub fn drawTextMonospace(renderer: anytype, text: []const u8, x: f32, y: f32, color: Color) void {
    text_runtime.drawTextMonospace(renderer, text, x, y, color);
}

pub fn drawTextMonospacePolicy(renderer: anytype, text: []const u8, x: f32, y: f32, color: Color, disable_programming_ligatures: bool) void {
    text_runtime.drawTextMonospacePolicy(renderer, text, x, y, color, disable_programming_ligatures);
}

pub fn drawTextMonospaceStyledPolicy(renderer: anytype, text: []const u8, x: f32, y: f32, color: Color, disable_programming_ligatures: bool, italic: bool) void {
    text_runtime.drawTextMonospaceStyledPolicy(renderer, text, x, y, color, disable_programming_ligatures, italic);
}

pub fn drawTextMonospaceOnBg(renderer: anytype, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
    text_runtime.drawTextMonospaceOnBg(renderer, text, x, y, color, bg);
}

pub fn drawTextMonospaceOnBgPolicy(renderer: anytype, text: []const u8, x: f32, y: f32, color: Color, bg: Color, disable_programming_ligatures: bool) void {
    text_runtime.drawTextMonospaceOnBgPolicy(renderer, text, x, y, color, bg, disable_programming_ligatures);
}

pub fn drawTextMonospaceOnBgStyledPolicy(renderer: anytype, text: []const u8, x: f32, y: f32, color: Color, bg: Color, disable_programming_ligatures: bool, italic: bool) void {
    text_runtime.drawTextMonospaceOnBgStyledPolicy(renderer, text, x, y, color, bg, disable_programming_ligatures, italic);
}

pub fn drawTextOnBg(renderer: anytype, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
    text_runtime.drawTextOnBg(renderer, text, x, y, color, bg);
}

pub fn drawTextSized(renderer: anytype, text: []const u8, x: f32, y: f32, size: f32, color: Color) void {
    text_runtime.drawTextSized(renderer, text, x, y, size, color);
}

pub fn drawIconText(renderer: anytype, text: []const u8, x: f32, y: f32, color: Color) void {
    text_runtime.drawIconText(renderer, text, x, y, color);
}

pub fn measureIconTextWidth(renderer: anytype, text: []const u8) f32 {
    return text_runtime.measureIconTextWidth(renderer, text);
}

pub fn drawChar(renderer: anytype, char: u8, x: f32, y: f32, color: Color) void {
    text_runtime.drawChar(renderer, char, x, y, color);
}
