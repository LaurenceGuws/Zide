const gl_backend = @import("gl_backend.zig");
const metal_backend = @import("metal_backend.zig");
const metal_text_sample_runtime = @import("metal_text_sample_runtime.zig");
const terminal_font = @import("../terminal_font.zig");
const iface = @import("interface.zig");

pub fn flushQueuedSurfaceDrawsBeforeTextWork(renderer: anytype) void {
    gl_backend.flushQueuedSurfaceDrawsNow(renderer);
}

pub fn drawAtlasSampleChar(renderer: anytype, char: u8, x: f32, y: f32, color: iface.Color) bool {
    return metal_backend.drawAtlasSampleChar(renderer, char, x, y, color);
}

pub fn drawTerminalCellRun(
    renderer: anytype,
    font: *terminal_font.TerminalFont,
    request: metal_text_sample_runtime.TerminalCellRunRequest,
) bool {
    return metal_backend.drawTerminalCellRun(renderer, font, request);
}
