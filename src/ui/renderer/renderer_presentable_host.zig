const present_trace_runtime = @import("present_trace_runtime.zig");

pub fn ensurePresentable(renderer: anytype, surface: anytype, width: i32, height: i32) bool {
    return renderer.backend_ops.presentable.ensurePresentable(renderer, surface, width, height);
}

pub fn beginPresentable(renderer: anytype, surface: anytype) bool {
    const begun = renderer.backend_ops.presentable.beginPresentable(renderer, surface);
    if (begun and surface == .editor) {
        present_trace_runtime.notePresentableUpdate(renderer, .editor);
    }
    return begun;
}

pub fn presentableAvailable(renderer: anytype, surface: anytype) bool {
    return renderer.backend_ops.presentable.presentableAvailable(renderer, surface);
}

pub fn endPresentable(renderer: anytype, surface: anytype) void {
    if (surface == .editor) {
        present_trace_runtime.notePresentableEnded(renderer, .editor);
    }
    renderer.backend_ops.presentable.endPresentable(renderer, surface);
}

pub fn drawPresentable(renderer: anytype, surface: anytype, draw: anytype) void {
    switch (surface) {
        .editor => present_trace_runtime.notePresentableDraw(renderer, .editor, null),
        .terminal => present_trace_runtime.notePresentableDraw(renderer, .terminal, draw.generation),
    }
    renderer.backend_ops.presentable.drawPresentable(renderer, surface, draw);
}

pub fn scrollPresentable(renderer: anytype, surface: anytype, dx: i32, dy: i32) bool {
    return renderer.backend_ops.presentable.scrollPresentable(renderer, surface, dx, dy);
}

pub fn presentableInfo(renderer: anytype, surface: anytype) @TypeOf(renderer.backend_ops.presentable.presentableInfo(renderer, surface)) {
    return renderer.backend_ops.presentable.presentableInfo(renderer, surface);
}
