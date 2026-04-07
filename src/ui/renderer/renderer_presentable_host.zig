const present_trace_runtime = @import("present_trace_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");

const PresentableDraw = presentable_contract.PresentableDraw;

pub fn ensureTerminalPresentable(renderer: anytype, width: i32, height: i32) bool {
    return renderer.backend.ops.presentable.ensurePresentable(renderer, width, height);
}

pub fn updateTerminalPresentable(renderer: anytype, ctx: anytype, comptime body: fn (@TypeOf(ctx), @TypeOf(renderer)) void) bool {
    if (!renderer.backend.ops.presentable.beginPresentable(renderer)) return false;
    defer renderer.backend.ops.presentable.endPresentable(renderer);
    body(ctx, renderer);
    return true;
}

pub fn drawTerminalPresentableBackdrop(renderer: anytype, x: f32, y: f32, w: f32, h: f32, color: @import("types.zig").Rgba) void {
    renderer.backend.ops.presentable.drawPresentableBackdrop(renderer, x, y, w, h, color);
}

pub fn drawTerminalPresentable(renderer: anytype, draw: PresentableDraw) void {
    present_trace_runtime.noteTerminalPresentation(renderer, draw.generation);
    renderer.backend.ops.presentable.drawPresentable(renderer, draw);
}

pub fn scrollTerminalPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    return renderer.backend.ops.presentable.scrollPresentable(renderer, dx, dy);
}

pub fn terminalPresentableInfo(renderer: anytype) @TypeOf(renderer.backend.ops.presentable.presentableInfo(renderer)) {
    return renderer.backend.ops.presentable.presentableInfo(renderer);
}
