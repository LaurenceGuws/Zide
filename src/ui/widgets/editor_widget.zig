const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");
const editor_mod = @import("../../editor/editor.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const chrome_geometry_mod = @import("../../editor/view/chrome_geometry.zig");
const frame_view_mod = @import("../../editor/view/frame.zig");
const metrics_mod = @import("../../editor/view/metrics.zig");
const runtime_mod = @import("../../editor/view/runtime.zig");
const render_cache_mod = @import("../../editor/render/cache.zig");
const input_mod = @import("editor_widget_input.zig");
const draw_mod = @import("editor_widget_draw.zig");
const types = @import("../../editor/types.zig");

const hb = @import("../terminal_font.zig").c;

const Shell = app_shell.Shell;
const Editor = editor_mod.Editor;
const EditorRenderCache = render_cache_mod.EditorRenderCache;
const LineScratch = runtime_mod.LineScratch;
const LineSlice = runtime_mod.LineSlice;
const ClusterSlice = runtime_mod.ClusterSlice;
const EditorViewRuntime = runtime_mod.EditorViewRuntime;
const EditorFrameView = frame_view_mod.EditorFrameView;

const CursorLineCtx = struct {
    widget: *EditorWidget,
    r: *Shell,
};

fn cursorLineText(ctx: *anyopaque, line_idx: usize, scratch: *LineScratch) LineSlice {
    const log = app_logger.logger("editor.input");
    const payload: *CursorLineCtx = @ptrCast(@alignCast(ctx));
    const editor = payload.widget.editor;
    const line_len = editor.lineLen(line_idx);
    if (line_len <= scratch.buf.len) {
        const len = editor.getLine(line_idx, scratch.buf);
        return .{ .text = scratch.buf[0..len], .owned = null };
    }
    const owned = editor.getLineAlloc(line_idx) catch |err| {
        log.logf(.warning, "cursorLineText getLineAlloc failed line={d} err={s}", .{ line_idx, @errorName(err) });
        return .{ .text = &[_]u8{}, .owned = null };
    };
    return .{ .text = owned, .owned = owned };
}

fn cursorClusters(ctx: *anyopaque, line_idx: usize, line_text: []const u8) ClusterSlice {
    const payload: *CursorLineCtx = @ptrCast(@alignCast(ctx));
    var slice: ?[]const u32 = null;
    var owned = false;
    payload.widget.clusterOffsets(payload.r, line_idx, line_text, &slice, &owned);
    return .{ .clusters = slice, .owned = owned };
}

fn cursorFreeLineText(ctx: *anyopaque, owned: []u8) void {
    const payload: *CursorLineCtx = @ptrCast(@alignCast(ctx));
    payload.widget.editor.allocator.free(owned);
}

fn cursorFreeClusters(ctx: *anyopaque, owned: []const u32) void {
    const payload: *CursorLineCtx = @ptrCast(@alignCast(ctx));
    payload.widget.editor.allocator.free(owned);
}

/// Editor widget for drawing a text editor view
pub const EditorWidget = struct {
    editor: *Editor,
    gutter_width: f32,
    scroll_x: f32,
    scroll_y: f32,
    cluster_cache: ?*ClusterCache,
    wrap_enabled: bool,

    pub fn init(editor: *Editor, wrap_enabled: bool) EditorWidget {
        return .{
            .editor = editor,
            .gutter_width = 50,
            .scroll_x = 0,
            .scroll_y = 0,
            .cluster_cache = null,
            .wrap_enabled = wrap_enabled,
        };
    }

    pub fn initWithCache(editor: *Editor, cache: *ClusterCache, wrap_enabled: bool) EditorWidget {
        var widget = init(editor, wrap_enabled);
        widget.cluster_cache = cache;
        return widget;
    }

    pub fn draw(
        self: *EditorWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        input: shared_types.input.InputSnapshot,
    ) void {
        draw_mod.draw(self, shell, x, y, width, height, input);
    }

    pub fn drawCached(
        self: *EditorWidget,
        shell: *Shell,
        cache: *EditorRenderCache,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        frame_id: u64,
        input: shared_types.input.InputSnapshot,
    ) void {
        draw_mod.drawCached(self, shell, cache, x, y, width, height, frame_id, input);
    }

    pub fn frameView(self: *EditorWidget) EditorFrameView {
        return EditorFrameView.init(self.editor, self.wrap_enabled);
    }

    fn initViewRuntime(self: *EditorWidget, ctx: *CursorLineCtx) EditorViewRuntime {
        return .{
            .editor = self.editor,
            .wrap_enabled = self.wrap_enabled,
            .ctx = ctx,
            .getLineText = cursorLineText,
            .getClusters = cursorClusters,
            .freeLineText = cursorFreeLineText,
            .freeClusters = cursorFreeClusters,
        };
    }

    pub fn viewportColumns(self: *EditorWidget, shell: *Shell) usize {
        const r = shell.rendererPtr();
        return metrics_mod.viewportColumns(r.width, self.gutter_width, r.char_width);
    }

    pub fn clusterOffsets(
        self: *EditorWidget,
        shell: *Shell,
        line_idx: usize,
        line_text: []const u8,
        out_slice: *?[]const u32,
        out_owned: *bool,
    ) void {
        if (self.editor.shouldDeferClusterOffsets()) {
            out_slice.* = null;
            out_owned.* = false;
            return;
        }
        const r = shell.rendererPtr();
        const result = getClusterOffsets(self.cluster_cache, self.editor, self.editor.allocator, r.terminal_font.hb_font, line_idx, line_text);
        out_slice.* = result.slice;
        out_owned.* = result.owned;
    }

    pub fn lineData(self: *EditorWidget, shell: *Shell, line_idx: usize, scratch: *LineScratch) runtime_mod.LineData {
        var ctx = CursorLineCtx{ .widget = self, .r = shell };
        const runtime = self.initViewRuntime(&ctx);
        return runtime.lineData(line_idx, scratch);
    }

    pub fn releaseLineData(self: *EditorWidget, data: *runtime_mod.LineData) void {
        if (data.owned_text) |owned| self.editor.allocator.free(owned);
        if (data.owned_clusters) {
            if (data.clusters) |clusters| self.editor.allocator.free(clusters);
        }
    }

    pub fn handleMouseClick(
        self: *EditorWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        mouse_x: f32,
        mouse_y: f32,
    ) bool {
        return input_mod.handleMouseClick(self, shell, x, y, width, height, mouse_x, mouse_y);
    }

    pub fn cursorFromMouse(
        self: *EditorWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        mouse_x: f32,
        mouse_y: f32,
        clamp: bool,
    ) ?types.CursorPos {
        const r = shell.rendererPtr();
        const view = self.frameView();
        const frame_metrics = chrome_geometry_mod.frameMetrics(x, height, r.uiScaleFactor(), r.char_height);
        self.gutter_width = frame_metrics.gutter_width;
        if (width <= 0 or height <= 0) return null;
        if (view.lineCount() == 0) return null;
        var local_x = mouse_x;
        var local_y = mouse_y;
        if (clamp) {
            local_x = @min(@max(mouse_x, x), x + width);
            local_y = @min(@max(mouse_y, y), y + height);
        } else {
            if (mouse_x < x or mouse_x > x + width) return null;
            if (mouse_y < y or mouse_y > y + height) return null;
        }
        const line_offset = @as(usize, @intFromFloat((local_y - y) / r.char_height));
        const line = self.lineForVisualRow(shell, line_offset) orelse return null;

        const text_start_x = frame_metrics.text_start_x;
        var col: usize = 0;
        if (local_x > text_start_x) {
            col = @as(usize, @intFromFloat((local_x - text_start_x) / r.char_width));
        }
        var line_buf: [4096]u8 = undefined;
        var scratch = LineScratch{ .buf = line_buf[0..] };
        var line_data = self.lineData(shell, line.line_idx, &scratch);
        defer self.releaseLineData(&line_data);
        const seg_start_col = line.seg_idx * line.cols + (if (self.wrap_enabled) 0 else view.scroll_col);
        const byte_col = selection_mod.byteIndexForVisualColumn(line_data.text, seg_start_col + col, line_data.clusters);
        const clamped_col = @min(byte_col, line_data.len);
        const line_start = view.lineStart(line.line_idx);
        return .{
            .line = line.line_idx,
            .col = clamped_col,
            .offset = line_start + clamped_col,
        };
    }

    const VisualLinePos = runtime_mod.VisualLinePos;

    fn lineForVisualRow(self: *EditorWidget, shell: *Shell, visual_row: usize) ?VisualLinePos {
        const cols = self.viewportColumns(shell);
        var ctx = CursorLineCtx{ .widget = self, .r = shell };
        const runtime = self.initViewRuntime(&ctx);
        return runtime.lineForVisualRow(visual_row, cols);
    }

    /// Handle input, returns true if any input was processed
    pub fn handleInput(self: *EditorWidget, shell: *Shell, height: f32, input_batch: *shared_types.input.InputBatch) !bool {
        return input_mod.handleInput(self, shell, height, input_batch);
    }

    pub fn handleHorizontalScrollbarInput(
        self: *EditorWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        mouse: app_shell.MousePos,
        dragging: *bool,
        grab_offset: *f32,
        input_batch: *shared_types.input.InputBatch,
    ) bool {
        return input_mod.handleHorizontalScrollbarInput(self, shell, x, y, width, height, mouse, dragging, grab_offset, input_batch);
    }

    pub fn handleVerticalScrollbarInput(
        self: *EditorWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        mouse: app_shell.MousePos,
        dragging: *bool,
        grab_offset: *f32,
        input_batch: *shared_types.input.InputBatch,
    ) bool {
        return input_mod.handleVerticalScrollbarInput(self, shell, x, y, width, height, mouse, dragging, grab_offset, input_batch);
    }

    pub fn ensureCursorVisible(self: *EditorWidget, shell: *Shell, height: f32) void {
        const r = shell.rendererPtr();
        const line_count = self.editor.lineCount();
        if (line_count == 0) return;
        const visible_lines = @max(@as(usize, 1), @as(usize, @intFromFloat(height / r.char_height)));
        const view = self.editor.viewState();

        if (!self.wrap_enabled) {
            if (self.editor.cursor.line < view.scroll_line) {
                self.editor.setScrollLine(self.editor.cursor.line);
            } else if (self.editor.cursor.line >= view.scroll_line + visible_lines) {
                self.editor.setScrollLine(self.editor.cursor.line - (visible_lines - 1));
            }
            self.ensureCursorVisibleHorizontal(shell);
            self.editor.setScrollRowOffset(0);
            return;
        }

        const cols = self.viewportColumns(shell);
        if (cols == 0) return;
        var ctx = CursorLineCtx{ .widget = self, .r = shell };
        const runtime = self.initViewRuntime(&ctx);
        const cursor_seg = runtime.cursorSegmentForLine(self.editor.cursor.line, cols) orelse return;
        const offset = runtime.cursorRowOffset(self.editor.cursor.line, cursor_seg, cols);
        if (offset < 0) {
            self.editor.setVerticalScroll(self.editor.cursor.line, cursor_seg);
            return;
        }
        if (offset >= @as(i32, @intCast(visible_lines))) {
            const delta = offset - @as(i32, @intCast(visible_lines - 1));
            self.scrollVisual(shell, delta);
        }
    }

    fn ensureCursorVisibleHorizontal(self: *EditorWidget, shell: *Shell) void {
        const cols = self.viewportColumns(shell);
        if (cols == 0) return;
        var ctx = CursorLineCtx{ .widget = self, .r = shell };
        const runtime = self.initViewRuntime(&ctx);
        if (runtime.cursorHorizontalScrollTarget(cols)) |scroll_col| {
            self.editor.setScrollCol(scroll_col);
        }
    }

    pub fn scrollHorizontal(self: *EditorWidget, shell: *Shell, delta_cols: i32) void {
        if (delta_cols == 0) return;
        const cols = self.viewportColumns(shell);
        if (cols == 0) return;
        const line_idx = self.editor.cursor.line;
        var ctx = CursorLineCtx{ .widget = self, .r = shell };
        const runtime = self.initViewRuntime(&ctx);
        if (runtime.horizontalScrollTarget(line_idx, cols, delta_cols)) |next| {
            self.editor.setScrollCol(next);
        }
    }

    pub fn scrollVisual(self: *EditorWidget, shell: *Shell, delta_rows: i32) void {
        const cols = self.viewportColumns(shell);
        var ctx = CursorLineCtx{ .widget = self, .r = shell };
        const runtime = self.initViewRuntime(&ctx);
        runtime.scrollVisual(delta_rows, cols);
    }

    pub fn moveCursorVisual(self: *EditorWidget, shell: *Shell, delta: i32) bool {
        const log = app_logger.logger("editor.widget");
        const cols = self.viewportColumns(shell);
        var ctx = CursorLineCtx{ .widget = self, .r = shell };
        const runtime = self.initViewRuntime(&ctx);
        return runtime.moveCursorVisual(delta, cols) catch |err| blk: {
            log.logf(.warning, "moveCursorVisual failed err={s}", .{@errorName(err)});
            break :blk false;
        };
    }

    pub fn extendSelectionVisual(self: *EditorWidget, shell: *Shell, delta: i32) bool {
        const cols = self.viewportColumns(shell);
        var ctx = CursorLineCtx{ .widget = self, .r = shell };
        const runtime = self.initViewRuntime(&ctx);
        return runtime.extendSelectionVisual(delta, cols);
    }
};

pub const ClusterCache = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ClusterCache {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ClusterCache) void {
        _ = self;
    }

    pub fn beginFrame(self: *ClusterCache, frame_id: u64) void {
        _ = self;
        _ = frame_id;
    }

    pub fn clear(self: *ClusterCache) void {
        _ = self;
    }

    pub fn getOrCompute(
        self: *ClusterCache,
        editor: *Editor,
        line_idx: usize,
        hb_font: *hb.hb_font_t,
        text: []const u8,
    ) ?[]const u32 {
        _ = self;
        const log = app_logger.logger("editor.widget");
        const perf_log = app_logger.logger("editor.perf");
        if (!hasNonAscii(text)) return null;
        if (editor.cachedClusterOffsets(line_idx, text)) |cached| return cached;
        const t_start = std.time.nanoTimestamp();
        const clusters = graphemeClusterOffsets(editor.allocator, hb_font, text) catch |err| {
            log.logf(.warning, "cluster compute failed line={d} err={s}", .{ line_idx, @errorName(err) });
            return null;
        };
        const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
        perf_log.logf(.info, "cluster_compute cache=true line={d} bytes={d} clusters={d} time_us={d}", .{ line_idx, text.len, clusters.len, elapsed_us });
        return editor.cacheClusterOffsets(line_idx, text, clusters);
    }
};

const ClusterResult = struct {
    slice: ?[]const u32,
    owned: bool,
};

fn getClusterOffsets(
    cache: ?*ClusterCache,
    editor: *Editor,
    allocator: std.mem.Allocator,
    hb_font: *hb.hb_font_t,
    line_idx: usize,
    text: []const u8,
) ClusterResult {
    const log = app_logger.logger("editor.widget");
    const perf_log = app_logger.logger("editor.perf");
    if (cache) |cluster_cache| {
        const slice = cluster_cache.getOrCompute(editor, line_idx, hb_font, text);
        return .{ .slice = slice, .owned = false };
    }
    if (!hasNonAscii(text)) return .{ .slice = null, .owned = false };
    const t_start = std.time.nanoTimestamp();
    const slice = graphemeClusterOffsets(allocator, hb_font, text) catch |err| blk: {
        log.logf(.warning, "cluster offsets compute failed line={d} err={s}", .{ line_idx, @errorName(err) });
        break :blk null;
    };
    if (slice) |clusters| {
        const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
        perf_log.logf(.info, "cluster_compute cache=false line={d} bytes={d} clusters={d} time_us={d}", .{ line_idx, text.len, clusters.len, elapsed_us });
    }
    return .{ .slice = slice, .owned = slice != null };
}

fn hasNonAscii(text: []const u8) bool {
    for (text) |byte| {
        if (byte & 0x80 != 0) return true;
    }
    return false;
}

fn graphemeClusterOffsets(allocator: std.mem.Allocator, hb_font: *hb.hb_font_t, text: []const u8) ![]u32 {
    if (text.len == 0) return allocator.alloc(u32, 0);
    const buffer = hb.hb_buffer_create();
    defer hb.hb_buffer_destroy(buffer);
    hb.hb_buffer_add_utf8(buffer, text.ptr, @intCast(text.len), 0, @intCast(text.len));
    hb.hb_buffer_guess_segment_properties(buffer);
    hb.hb_shape(hb_font, buffer, null, 0);

    var length: u32 = 0;
    const infos = hb.hb_buffer_get_glyph_infos(buffer, &length);
    if (infos == null or length == 0) return allocator.alloc(u32, 0);

    var clusters = std.ArrayList(u32).empty;
    defer clusters.deinit(allocator);
    try clusters.ensureTotalCapacity(allocator, @intCast(length));
    for (infos[0..length]) |info| {
        clusters.appendAssumeCapacity(info.cluster);
    }

    std.sort.block(u32, clusters.items, {}, struct {
        fn lessThan(_: void, a: u32, b: u32) bool {
            return a < b;
        }
    }.lessThan);

    var write: usize = 0;
    for (clusters.items) |cluster| {
        if (write == 0 or cluster != clusters.items[write - 1]) {
            clusters.items[write] = cluster;
            write += 1;
        }
    }
    clusters.items.len = write;
    return try clusters.toOwnedSlice(allocator);
}
