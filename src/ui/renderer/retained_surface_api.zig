const retained_targets_runtime = @import("retained_targets_runtime.zig");

pub fn ensureTerminalSurface(renderer: anytype, width: i32, height: i32) bool {
    return retained_targets_runtime.ensureTerminalTexture(renderer, width, height);
}

pub fn ensureEditorSurface(renderer: anytype, width: i32, height: i32) bool {
    return retained_targets_runtime.ensureEditorTexture(renderer, width, height);
}

pub fn beginTerminalSurface(renderer: anytype) bool {
    return retained_targets_runtime.beginTerminalTexture(renderer);
}

pub fn endTerminalSurface(renderer: anytype) void {
    retained_targets_runtime.endTerminalTexture(renderer);
}

pub fn beginEditorSurface(renderer: anytype) bool {
    return retained_targets_runtime.beginEditorTexture(renderer);
}

pub fn endEditorSurface(renderer: anytype) void {
    retained_targets_runtime.endEditorTexture(renderer);
}

pub fn drawTerminalSurface(renderer: anytype, x: f32, y: f32, width: f32, height: f32) void {
    retained_targets_runtime.drawTerminalTexture(renderer, x, y, width, height);
}

pub fn scrollTerminalSurface(renderer: anytype, dx: i32, dy: i32) bool {
    return retained_targets_runtime.scrollTerminalTexture(renderer, dx, dy);
}

pub fn drawEditorSurface(renderer: anytype, x: f32, y: f32) void {
    retained_targets_runtime.drawEditorTexture(renderer, x, y);
}
