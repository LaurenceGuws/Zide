const renderer_mod = @import("../renderer.zig");

pub const PresentableDraw = renderer_mod.PresentableDraw;

pub fn presentableAvailable(renderer: anytype) bool {
    return renderer.presentableAvailable(.terminal);
}

pub fn ensurePresentable(renderer: anytype, width: i32, height: i32) bool {
    return renderer.ensurePresentable(.terminal, width, height);
}

pub fn beginPresentable(renderer: anytype) bool {
    return renderer.beginPresentable(.terminal);
}

pub fn endPresentable(renderer: anytype) void {
    renderer.endPresentable(.terminal);
}

pub fn drawPresentable(renderer: anytype, draw: PresentableDraw) void {
    renderer.drawPresentable(.terminal, draw);
}

pub fn scrollPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    return renderer.scrollPresentable(.terminal, dx, dy);
}
