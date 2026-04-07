const present_trace_runtime = @import("present_trace_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");

const PresentableDraw = presentable_contract.PresentableDraw;

pub fn ensurePresentable(renderer: anytype, width: i32, height: i32) bool {
    return renderer.backend.ops.presentable.ensurePresentable(renderer, width, height);
}

pub fn beginPresentable(renderer: anytype) bool {
    return renderer.backend.ops.presentable.beginPresentable(renderer);
}

pub fn endPresentable(renderer: anytype) void {
    renderer.backend.ops.presentable.endPresentable(renderer);
}

pub fn drawPresentableBackdrop(renderer: anytype, x: f32, y: f32, w: f32, h: f32, color: @import("types.zig").Rgba) void {
    renderer.backend.ops.presentable.drawPresentableBackdrop(renderer, x, y, w, h, color);
}

pub fn drawPresentable(renderer: anytype, draw: PresentableDraw) void {
    present_trace_runtime.notePresentableDraw(renderer, .terminal, draw.generation);
    renderer.backend.ops.presentable.drawPresentable(renderer, draw);
}

pub fn scrollPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    return renderer.backend.ops.presentable.scrollPresentable(renderer, dx, dy);
}

pub fn presentableInfo(renderer: anytype) @TypeOf(renderer.backend.ops.presentable.presentableInfo(renderer)) {
    return renderer.backend.ops.presentable.presentableInfo(renderer);
}
