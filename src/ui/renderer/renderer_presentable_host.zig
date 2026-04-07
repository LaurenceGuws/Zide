const present_trace_runtime = @import("present_trace_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");

const PresentableDraw = presentable_contract.PresentableDraw;
const PresentableSurface = presentable_contract.PresentableSurface;

pub fn ensurePresentable(renderer: anytype, surface: PresentableSurface, width: i32, height: i32) bool {
    return renderer.backend.ops.presentable.ensurePresentable(renderer, surface, width, height);
}

pub fn beginPresentable(renderer: anytype, surface: PresentableSurface) bool {
    const begun = renderer.backend.ops.presentable.beginPresentable(renderer, surface);
    if (begun and surface == .editor) {
        present_trace_runtime.notePresentableUpdate(renderer, .editor);
    }
    return begun;
}

pub fn endPresentable(renderer: anytype, surface: PresentableSurface) void {
    if (surface == .editor) {
        present_trace_runtime.notePresentableEnded(renderer, .editor);
    }
    renderer.backend.ops.presentable.endPresentable(renderer, surface);
}

pub fn drawPresentableBackdrop(renderer: anytype, surface: PresentableSurface, x: f32, y: f32, w: f32, h: f32, color: @import("types.zig").Rgba) void {
    renderer.backend.ops.presentable.drawPresentableBackdrop(renderer, surface, x, y, w, h, color);
}

pub fn drawPresentable(renderer: anytype, surface: PresentableSurface, draw: PresentableDraw) void {
    if (surface == .editor) {
        present_trace_runtime.notePresentableDraw(renderer, .editor, null);
    } else if (surface == .terminal) {
        present_trace_runtime.notePresentableDraw(renderer, .terminal, draw.generation);
    }
    renderer.backend.ops.presentable.drawPresentable(renderer, surface, draw);
}

pub fn scrollPresentable(renderer: anytype, surface: PresentableSurface, dx: i32, dy: i32) bool {
    return renderer.backend.ops.presentable.scrollPresentable(renderer, surface, dx, dy);
}

pub fn presentableInfo(renderer: anytype, surface: PresentableSurface) @TypeOf(renderer.backend.ops.presentable.presentableInfo(renderer, surface)) {
    return renderer.backend.ops.presentable.presentableInfo(renderer, surface);
}
