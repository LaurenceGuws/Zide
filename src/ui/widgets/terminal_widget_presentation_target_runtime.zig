const retained_targets_runtime = @import("../renderer/retained_targets_runtime.zig");

pub const PresentableDraw = retained_targets_runtime.SurfaceDraw;

pub fn presentableAvailable(renderer: anytype) bool {
    return retained_targets_runtime.surfaceAvailable(renderer, .terminal);
}

pub fn ensurePresentable(renderer: anytype, width: i32, height: i32) bool {
    return retained_targets_runtime.ensureSurface(renderer, .terminal, width, height);
}

pub fn beginPresentable(renderer: anytype) bool {
    return retained_targets_runtime.beginSurface(renderer, .terminal);
}

pub fn drawPresentable(renderer: anytype, draw: PresentableDraw) void {
    retained_targets_runtime.drawSurface(renderer, .terminal, draw);
}

pub fn scrollPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    return retained_targets_runtime.scrollSurface(renderer, .terminal, dx, dy);
}
