const std = @import("std");
const editor_mod = @import("../editor.zig");
const layout_mod = @import("layout.zig");
const scroll_mod = @import("scroll.zig");
const cursor_mod = @import("cursor.zig");

const Editor = editor_mod.Editor;

pub const LineScratch = cursor_mod.LineScratch;
pub const LineSlice = cursor_mod.LineSlice;
pub const ClusterSlice = cursor_mod.ClusterSlice;
pub const LineData = cursor_mod.LineData;
pub const VisualLinePos = scroll_mod.VisualLinePos;

pub const EditorViewRuntime = struct {
    editor: *Editor,
    wrap_enabled: bool,
    ctx: *anyopaque,
    getLineText: *const fn (ctx: *anyopaque, line_idx: usize, scratch: *LineScratch) LineSlice,
    getClusters: *const fn (ctx: *anyopaque, line_idx: usize, line_text: []const u8) ClusterSlice,
    freeLineText: *const fn (ctx: *anyopaque, owned: []u8) void,
    freeClusters: *const fn (ctx: *anyopaque, owned: []const u32) void,

    pub fn visualLinesForLine(self: *const EditorViewRuntime, line_idx: usize, cols: usize) usize {
        if (!self.wrap_enabled) return 1;
        var scratch_buf: [4096]u8 = undefined;
        var scratch = LineScratch{ .buf = scratch_buf[0..] };
        var line = self.lineData(line_idx, &scratch);
        defer self.releaseLineData(&line);
        return layout_mod.visualLineCountForWidth(cols, line.width);
    }

    pub fn lineForVisualRow(self: *const EditorViewRuntime, visual_row: usize, cols: usize) ?VisualLinePos {
        return scroll_mod.lineForVisualRow(self.editor, visual_row, cols, self.wrap_enabled, @constCast(self), visualLinesForLineWithContext);
    }

    pub fn cursorSegmentForLine(self: *const EditorViewRuntime, line_idx: usize, cols: usize) ?usize {
        var scratch_buf: [4096]u8 = undefined;
        var scratch = LineScratch{ .buf = scratch_buf[0..] };
        var provider = self.lineProvider();
        return cursor_mod.cursorSegmentForLine(self.editor, line_idx, cols, &provider, &scratch);
    }

    pub fn cursorRowOffset(self: *const EditorViewRuntime, cursor_line: usize, cursor_seg: usize, cols: usize) i32 {
        return scroll_mod.cursorRowOffset(self.editor, cursor_line, cursor_seg, cols, @constCast(self), visualLinesForLineWithContext);
    }

    pub fn scrollVisual(self: *const EditorViewRuntime, delta_rows: i32, cols: usize) void {
        scroll_mod.scrollVisual(self.editor, delta_rows, cols, self.wrap_enabled, @constCast(self), visualLinesForLineWithContext);
    }

    pub fn cursorHorizontalScrollTarget(self: *const EditorViewRuntime, cols: usize) ?usize {
        var provider = self.lineProvider();
        var buf: [4096]u8 = undefined;
        var scratch = LineScratch{ .buf = buf[0..] };
        return cursor_mod.cursorHorizontalScrollTarget(self.editor, cols, &provider, &scratch);
    }

    pub fn horizontalScrollTarget(self: *const EditorViewRuntime, line_idx: usize, cols: usize, delta_cols: i32) ?usize {
        var provider = self.lineProvider();
        var buf: [4096]u8 = undefined;
        var scratch = LineScratch{ .buf = buf[0..] };
        return cursor_mod.horizontalScrollTarget(self.editor, line_idx, cols, delta_cols, &provider, &scratch);
    }

    pub fn moveCursorVisual(self: *const EditorViewRuntime, delta: i32, cols: usize) !bool {
        var provider = self.lineProvider();
        var buf_a: [4096]u8 = undefined;
        var buf_b: [4096]u8 = undefined;
        var scratch_a = LineScratch{ .buf = buf_a[0..] };
        var scratch_b = LineScratch{ .buf = buf_b[0..] };
        return cursor_mod.moveCaretSetVisual(self.editor, delta, cols, self.wrap_enabled, &provider, &scratch_a, &scratch_b);
    }

    pub fn extendSelectionVisual(self: *const EditorViewRuntime, delta: i32, cols: usize) bool {
        var provider = self.lineProvider();
        var buf_a: [4096]u8 = undefined;
        var buf_b: [4096]u8 = undefined;
        var scratch_a = LineScratch{ .buf = buf_a[0..] };
        var scratch_b = LineScratch{ .buf = buf_b[0..] };
        return cursor_mod.extendSelectionVisual(self.editor, delta, cols, self.wrap_enabled, &provider, &scratch_a, &scratch_b);
    }

    pub fn lineData(self: *const EditorViewRuntime, line_idx: usize, scratch: *LineScratch) LineData {
        var provider = self.lineProvider();
        return cursor_mod.lineData(self.editor, &provider, line_idx, scratch);
    }

    pub fn releaseLineData(self: *const EditorViewRuntime, data: *LineData) void {
        var provider = self.lineProvider();
        cursor_mod.releaseLineData(&provider, data);
    }

    fn lineProvider(self: *const EditorViewRuntime) cursor_mod.LineProvider {
        return .{
            .ctx = self.ctx,
            .getLineText = self.getLineText,
            .getClusters = self.getClusters,
            .freeLineText = self.freeLineText,
            .freeClusters = self.freeClusters,
        };
    }
};

fn visualLinesForLineWithContext(ctx: *anyopaque, line_idx: usize, cols: usize) usize {
    const runtime: *EditorViewRuntime = @ptrCast(@alignCast(ctx));
    return runtime.visualLinesForLine(line_idx, cols);
}
