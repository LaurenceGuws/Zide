pub fn ensurePresentable(renderer: anytype, surface: anytype, width: i32, height: i32) bool {
    return renderer.backend_ops.ensurePresentable(renderer, surface, width, height);
}

pub fn beginPresentable(renderer: anytype, surface: anytype) bool {
    return renderer.backend_ops.beginPresentable(renderer, surface);
}

pub fn presentableAvailable(renderer: anytype, surface: anytype) bool {
    return renderer.backend_ops.presentableAvailable(renderer, surface);
}

pub fn endPresentable(renderer: anytype, surface: anytype) void {
    renderer.backend_ops.endPresentable(renderer, surface);
}

pub fn drawPresentable(renderer: anytype, surface: anytype, draw: anytype) void {
    renderer.backend_ops.drawPresentable(renderer, surface, draw);
}

pub fn scrollPresentable(renderer: anytype, surface: anytype, dx: i32, dy: i32) bool {
    return renderer.backend_ops.scrollPresentable(renderer, surface, dx, dy);
}

pub fn presentableInfo(renderer: anytype, surface: anytype) @TypeOf(renderer.backend_ops.presentableInfo(renderer, surface)) {
    return renderer.backend_ops.presentableInfo(renderer, surface);
}
