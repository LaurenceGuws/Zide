const draw_ops = @import("draw_ops.zig");

pub fn beginTerminalBatch(renderer: anytype) void {
    draw_ops.beginTerminalBatch(renderer);
}

pub fn flushTerminalBatch(renderer: anytype) void {
    draw_ops.flushTerminalBatch(renderer);
}

pub fn beginEditorBatch(renderer: anytype) void {
    draw_ops.beginEditorBatch(renderer);
}

pub fn flushEditorBatch(renderer: anytype) void {
    draw_ops.flushEditorBatch(renderer);
}
