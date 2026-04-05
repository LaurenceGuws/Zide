const presentable_targets_runtime = @import("../renderer/presentable_targets_runtime.zig");

pub const PresentableDraw = presentable_targets_runtime.PresentableDraw;

pub fn presentableAvailable(renderer: anytype) bool {
    return presentable_targets_runtime.presentableAvailable(renderer, .terminal);
}

pub fn ensurePresentable(renderer: anytype, width: i32, height: i32) bool {
    return presentable_targets_runtime.ensurePresentable(renderer, .terminal, width, height);
}

pub fn beginPresentable(renderer: anytype) bool {
    return presentable_targets_runtime.beginPresentable(renderer, .terminal);
}

pub fn endPresentable(renderer: anytype) void {
    presentable_targets_runtime.endPresentable(renderer, .terminal);
}

pub fn drawPresentable(renderer: anytype, draw: PresentableDraw) void {
    presentable_targets_runtime.drawPresentable(renderer, .terminal, draw);
}

pub fn scrollPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    return presentable_targets_runtime.scrollPresentable(renderer, .terminal, dx, dy);
}
