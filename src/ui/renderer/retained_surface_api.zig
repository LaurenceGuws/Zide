pub fn ensureTerminalSurface(renderer: anytype, width: i32, height: i32) bool {
    return renderer.ensureTerminalTexture(width, height);
}

pub fn ensureEditorSurface(renderer: anytype, width: i32, height: i32) bool {
    return renderer.ensureEditorTexture(width, height);
}

pub fn beginTerminalSurface(renderer: anytype) bool {
    return renderer.beginTerminalTexture();
}

pub fn endTerminalSurface(renderer: anytype) void {
    renderer.endTerminalTexture();
}

pub fn beginEditorSurface(renderer: anytype) bool {
    return renderer.beginEditorTexture();
}

pub fn endEditorSurface(renderer: anytype) void {
    renderer.endEditorTexture();
}

pub fn drawTerminalSurface(renderer: anytype, x: f32, y: f32, width: f32, height: f32) void {
    renderer.drawTerminalTexture(x, y, width, height);
}

pub fn scrollTerminalSurface(renderer: anytype, dx: i32, dy: i32) bool {
    return renderer.scrollTerminalTexture(dx, dy);
}

pub fn drawEditorSurface(renderer: anytype, x: f32, y: f32) void {
    renderer.drawEditorTexture(x, y);
}
