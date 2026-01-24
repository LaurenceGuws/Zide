const std = @import("std");
const renderer_mod = @import("../renderer.zig");
const editor_mod = @import("../../editor/editor.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const layout_mod = @import("../../editor/view/layout.zig");
const scroll_mod = @import("../../editor/view/scroll.zig");
const cursor_mod = @import("../../editor/view/cursor.zig");
const render_cache_mod = @import("../../editor/render/cache.zig");
const input_mod = @import("editor_widget_input.zig");
const draw_mod = @import("editor_widget_draw.zig");
const types = @import("../../editor/types.zig");

const hb = @import("../terminal_font.zig").c;

const Renderer = renderer_mod.Renderer;
const Editor = editor_mod.Editor;
const EditorRenderCache = render_cache_mod.EditorRenderCache;
const LineScratch = cursor_mod.LineScratch;
const LineSlice = cursor_mod.LineSlice;
const ClusterSlice = cursor_mod.ClusterSlice;
const LineProvider = cursor_mod.LineProvider;

const VisualLinesCtx = struct {
    widget: *EditorWidget,
    r: *Renderer,
};

fn visualLinesForLineWithContext(ctx: *anyopaque, line_idx: usize, cols: usize) usize {
    const payload: *VisualLinesCtx = @ptrCast(@alignCast(ctx));
    return payload.widget.visualLinesForLine(payload.r, line_idx, cols);
}

const CursorLineCtx = struct {
    widget: *EditorWidget,
    r: *Renderer,
};

fn cursorLineText(ctx: *anyopaque, line_idx: usize, scratch: *LineScratch) LineSlice {
    const payload: *CursorLineCtx = @ptrCast(@alignCast(ctx));
    const editor = payload.widget.editor;
    const line_len = editor.lineLen(line_idx);
    if (line_len <= scratch.buf.len) {
        const len = editor.getLine(line_idx, scratch.buf);
        return .{ .text = scratch.buf[0..len], .owned = null };
    }
    const owned = editor.getLineAlloc(line_idx) catch return .{ .text = &[_]u8{}, .owned = null };
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

    pub fn draw(self: *EditorWidget, r: *Renderer, x: f32, y: f32, width: f32, height: f32) void {
        draw_mod.draw(self, r, x, y, width, height);
    }

    pub fn drawCached(
        self: *EditorWidget,
        r: *Renderer,
        cache: *EditorRenderCache,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        frame_id: u64,
    ) void {
        draw_mod.drawCached(self, r, cache, x, y, width, height, frame_id);
    }

    pub fn viewportColumns(self: *EditorWidget, r: *Renderer) usize {
        const editor_width = @max(0, r.width - @as(i32, @intFromFloat(self.gutter_width)));
        if (r.char_width <= 0) return 0;
        return @as(usize, @intFromFloat(@as(f32, @floatFromInt(editor_width)) / r.char_width));
    }

    pub fn clusterOffsets(
        self: *EditorWidget,
        r: *Renderer,
        line_idx: usize,
        line_text: []const u8,
        out_slice: *?[]const u32,
        out_owned: *bool,
    ) void {
        const result = getClusterOffsets(self.cluster_cache, self.editor.allocator, r.terminal_font.hb_font, line_idx, line_text);
        out_slice.* = result.slice;
        out_owned.* = result.owned;
    }

    fn visualLinesForLine(self: *EditorWidget, r: *Renderer, line_idx: usize, cols: usize) usize {
        if (!self.wrap_enabled) return 1;
        var line_buf: [4096]u8 = undefined;
        const line_len = self.editor.lineLen(line_idx);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..self.editor.getLine(line_idx, &line_buf)]
        else blk: {
            const owned = self.editor.getLineAlloc(line_idx) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| self.editor.allocator.free(owned);

        const cluster_result = getClusterOffsets(
            self.cluster_cache,
            self.editor.allocator,
            r.terminal_font.hb_font,
            line_idx,
            line_text,
        );
        defer if (cluster_result.owned) {
            if (cluster_result.slice) |clusters| self.editor.allocator.free(clusters);
        };

        const width_cached = self.editor.lineWidthCached(line_idx, line_text, cluster_result.slice);
        const line_width = if (line_len == 0) 1 else width_cached;
        return layout_mod.visualLineCountForWidth(cols, line_width);
    }

    pub fn handleMouseClick(
        self: *EditorWidget,
        r: *Renderer,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        mouse_x: f32,
        mouse_y: f32,
    ) bool {
        return input_mod.handleMouseClick(self, r, x, y, width, height, mouse_x, mouse_y);
    }

    pub fn cursorFromMouse(
        self: *EditorWidget,
        r: *Renderer,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        mouse_x: f32,
        mouse_y: f32,
        clamp: bool,
    ) ?types.CursorPos {
        self.gutter_width = 50 * r.uiScaleFactor();
        if (width <= 0 or height <= 0) return null;
        if (self.editor.lineCount() == 0) return null;
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
        const line = self.lineForVisualRow(r, line_offset) orelse return null;

        const text_start_x = x + self.gutter_width + 8 * r.uiScaleFactor();
        var col: usize = 0;
        if (local_x > text_start_x) {
            col = @as(usize, @intFromFloat((local_x - text_start_x) / r.char_width));
        }
        const line_len = self.editor.lineLen(line.line_idx);
        var byte_col = col;
        var line_buf: [4096]u8 = undefined;
        if (line_len <= line_buf.len) {
            const len = self.editor.getLine(line.line_idx, &line_buf);
            const line_text = line_buf[0..len];
            const cluster_result = getClusterOffsets(
                self.cluster_cache,
                self.editor.allocator,
                r.terminal_font.hb_font,
                line.line_idx,
                line_text,
            );
            defer if (cluster_result.owned) {
                if (cluster_result.slice) |clusters| self.editor.allocator.free(clusters);
            };
            const seg_start_col = line.seg_idx * line.cols + (if (self.wrap_enabled) 0 else self.editor.scroll_col);
            byte_col = selection_mod.byteIndexForVisualColumn(line_text, seg_start_col + col, cluster_result.slice);
        } else {
            if (self.editor.getLineAlloc(line.line_idx)) |owned| {
                defer self.editor.allocator.free(owned);
                const cluster_result = getClusterOffsets(
                    self.cluster_cache,
                    self.editor.allocator,
                    r.terminal_font.hb_font,
                    line.line_idx,
                    owned,
                );
                defer if (cluster_result.owned) {
                    if (cluster_result.slice) |clusters| self.editor.allocator.free(clusters);
                };
                const seg_start_col = line.seg_idx * line.cols + (if (self.wrap_enabled) 0 else self.editor.scroll_col);
                byte_col = selection_mod.byteIndexForVisualColumn(owned, seg_start_col + col, cluster_result.slice);
            } else |_| {}
        }
        const clamped_col = @min(byte_col, line_len);
        const line_start = self.editor.lineStart(line.line_idx);
        return .{
            .line = line.line_idx,
            .col = clamped_col,
            .offset = line_start + clamped_col,
        };
    }

    const VisualLinePos = scroll_mod.VisualLinePos;

    fn lineForVisualRow(self: *EditorWidget, r: *Renderer, visual_row: usize) ?VisualLinePos {
        const cols = self.viewportColumns(r);
        var ctx = VisualLinesCtx{ .widget = self, .r = r };
        return scroll_mod.lineForVisualRow(
            self.editor,
            visual_row,
            cols,
            self.wrap_enabled,
            &ctx,
            visualLinesForLineWithContext,
        );
    }

    /// Handle input, returns true if any input was processed
    pub fn handleInput(self: *EditorWidget, r: *Renderer, height: f32) !bool {
        return input_mod.handleInput(self, r, height);
    }

    pub fn handleHorizontalScrollbarInput(
        self: *EditorWidget,
        r: *Renderer,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        mouse: renderer_mod.MousePos,
        dragging: *bool,
        grab_offset: *f32,
    ) bool {
        return input_mod.handleHorizontalScrollbarInput(self, r, x, y, width, height, mouse, dragging, grab_offset);
    }

    pub fn handleVerticalScrollbarInput(
        self: *EditorWidget,
        r: *Renderer,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        mouse: renderer_mod.MousePos,
        dragging: *bool,
        grab_offset: *f32,
    ) bool {
        return input_mod.handleVerticalScrollbarInput(self, r, x, y, width, height, mouse, dragging, grab_offset);
    }

    pub fn ensureCursorVisible(self: *EditorWidget, r: *Renderer, height: f32) void {
        const line_count = self.editor.lineCount();
        if (line_count == 0) return;
        const visible_lines = @max(@as(usize, 1), @as(usize, @intFromFloat(height / r.char_height)));

        if (!self.wrap_enabled) {
            if (self.editor.cursor.line < self.editor.scroll_line) {
                self.editor.scroll_line = self.editor.cursor.line;
            } else if (self.editor.cursor.line >= self.editor.scroll_line + visible_lines) {
                self.editor.scroll_line = self.editor.cursor.line - (visible_lines - 1);
            }
            self.ensureCursorVisibleHorizontal(r);
            self.editor.scroll_row_offset = 0;
            return;
        }

        const cols = self.viewportColumns(r);
        if (cols == 0) return;
        const cursor_seg = self.cursorSegmentForLine(r, self.editor.cursor.line, cols) orelse return;
        const offset = self.cursorRowOffset(r, self.editor.cursor.line, cursor_seg, cols);
        if (offset < 0) {
            self.editor.scroll_line = self.editor.cursor.line;
            self.editor.scroll_row_offset = cursor_seg;
            return;
        }
        if (offset >= @as(i32, @intCast(visible_lines))) {
            const delta = offset - @as(i32, @intCast(visible_lines - 1));
            self.scrollVisual(r, delta);
        }
    }

    fn cursorSegmentForLine(self: *EditorWidget, r: *Renderer, line_idx: usize, cols: usize) ?usize {
        var scratch_buf: [4096]u8 = undefined;
        var scratch = LineScratch{ .buf = scratch_buf[0..] };
        var ctx = CursorLineCtx{ .widget = self, .r = r };
        const provider = LineProvider{
            .ctx = &ctx,
            .getLineText = cursorLineText,
            .getClusters = cursorClusters,
            .freeLineText = cursorFreeLineText,
            .freeClusters = cursorFreeClusters,
        };
        return cursor_mod.cursorSegmentForLine(self.editor, line_idx, cols, &provider, &scratch);
    }

    fn ensureCursorVisibleHorizontal(self: *EditorWidget, r: *Renderer) void {
        const cols = self.viewportColumns(r);
        if (cols == 0) return;
        const line_idx = self.editor.cursor.line;
        if (line_idx >= self.editor.lineCount()) return;
        var line_buf: [4096]u8 = undefined;
        const line_len = self.editor.lineLen(line_idx);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..self.editor.getLine(line_idx, &line_buf)]
        else blk: {
            const owned = self.editor.getLineAlloc(line_idx) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| self.editor.allocator.free(owned);

        const cluster_result = getClusterOffsets(
            self.cluster_cache,
            self.editor.allocator,
            r.terminal_font.hb_font,
            line_idx,
            line_text,
        );
        defer if (cluster_result.owned) {
            if (cluster_result.slice) |clusters| self.editor.allocator.free(clusters);
        };

        const col_vis = selection_mod.visualColumnForByteIndex(line_text, self.editor.cursor.col, cluster_result.slice);
        const width_cached = self.editor.lineWidthCached(line_idx, line_text, cluster_result.slice);
        const line_width = if (line_len == 0) 1 else width_cached;
        const max_scroll = if (line_width > cols) line_width - cols else 0;
        var scroll_col = self.editor.scroll_col;
        if (col_vis < scroll_col) {
            scroll_col = col_vis;
        } else if (col_vis >= scroll_col + cols) {
            scroll_col = col_vis - (cols - 1);
        }
        if (scroll_col > max_scroll) scroll_col = max_scroll;
        self.editor.scroll_col = scroll_col;
    }

    pub fn scrollHorizontal(self: *EditorWidget, r: *Renderer, delta_cols: i32) void {
        if (delta_cols == 0) return;
        const cols = self.viewportColumns(r);
        if (cols == 0) return;
        const line_idx = self.editor.cursor.line;
        if (line_idx >= self.editor.lineCount()) return;
        var line_buf: [4096]u8 = undefined;
        const line_len = self.editor.lineLen(line_idx);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..self.editor.getLine(line_idx, &line_buf)]
        else blk: {
            const owned = self.editor.getLineAlloc(line_idx) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| self.editor.allocator.free(owned);

        const cluster_result = getClusterOffsets(
            self.cluster_cache,
            self.editor.allocator,
            r.terminal_font.hb_font,
            line_idx,
            line_text,
        );
        defer if (cluster_result.owned) {
            if (cluster_result.slice) |clusters| self.editor.allocator.free(clusters);
        };

        const width_cached = self.editor.lineWidthCached(line_idx, line_text, cluster_result.slice);
        const line_width = if (line_len == 0) 1 else width_cached;
        const max_scroll = if (line_width > cols) line_width - cols else 0;
        const current = self.editor.scroll_col;
        const next = if (delta_cols > 0)
            @min(current + @as(usize, @intCast(delta_cols)), max_scroll)
        else blk: {
            const delta_abs: usize = @intCast(-delta_cols);
            break :blk if (current > delta_abs) current - delta_abs else 0;
        };
        self.editor.scroll_col = next;
    }

    fn cursorRowOffset(self: *EditorWidget, r: *Renderer, cursor_line: usize, cursor_seg: usize, cols: usize) i32 {
        var ctx = VisualLinesCtx{ .widget = self, .r = r };
        return scroll_mod.cursorRowOffset(
            self.editor,
            cursor_line,
            cursor_seg,
            cols,
            &ctx,
            visualLinesForLineWithContext,
        );
    }

    pub fn scrollVisual(self: *EditorWidget, r: *Renderer, delta_rows: i32) void {
        const cols = self.viewportColumns(r);
        var ctx = VisualLinesCtx{ .widget = self, .r = r };
        scroll_mod.scrollVisual(
            self.editor,
            delta_rows,
            cols,
            self.wrap_enabled,
            &ctx,
            visualLinesForLineWithContext,
        );
    }

    pub fn moveCursorVisual(self: *EditorWidget, r: *Renderer, delta: i32) bool {
        const cols = self.viewportColumns(r);
        var ctx = CursorLineCtx{ .widget = self, .r = r };
        const provider = LineProvider{
            .ctx = &ctx,
            .getLineText = cursorLineText,
            .getClusters = cursorClusters,
            .freeLineText = cursorFreeLineText,
            .freeClusters = cursorFreeClusters,
        };
        var buf_a: [4096]u8 = undefined;
        var buf_b: [4096]u8 = undefined;
        var scratch_a = LineScratch{ .buf = buf_a[0..] };
        var scratch_b = LineScratch{ .buf = buf_b[0..] };
        return cursor_mod.moveCursorVisual(self.editor, delta, cols, self.wrap_enabled, &provider, &scratch_a, &scratch_b);
    }
};

pub const ClusterCache = struct {
    allocator: std.mem.Allocator,
    frame_id: u64,
    entries: std.AutoHashMap(usize, []u32),

    pub fn init(allocator: std.mem.Allocator) ClusterCache {
        return .{
            .allocator = allocator,
            .frame_id = 0,
            .entries = std.AutoHashMap(usize, []u32).init(allocator),
        };
    }

    pub fn deinit(self: *ClusterCache) void {
        self.clear();
        self.entries.deinit();
    }

    pub fn beginFrame(self: *ClusterCache, frame_id: u64) void {
        if (self.frame_id == frame_id) return;
        self.clear();
        self.frame_id = frame_id;
    }

    pub fn clear(self: *ClusterCache) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.entries.clearRetainingCapacity();
    }

    pub fn getOrCompute(
        self: *ClusterCache,
        line_idx: usize,
        hb_font: *hb.hb_font_t,
        text: []const u8,
    ) ?[]const u32 {
        if (!hasNonAscii(text)) return null;
        if (self.entries.get(line_idx)) |cached| return cached;
        const clusters = graphemeClusterOffsets(self.allocator, hb_font, text) catch return null;
        self.entries.put(line_idx, clusters) catch {
            self.allocator.free(clusters);
            return null;
        };
        return clusters;
    }
};

const ClusterResult = struct {
    slice: ?[]const u32,
    owned: bool,
};

fn getClusterOffsets(
    cache: ?*ClusterCache,
    allocator: std.mem.Allocator,
    hb_font: *hb.hb_font_t,
    line_idx: usize,
    text: []const u8,
) ClusterResult {
    if (cache) |cluster_cache| {
        const slice = cluster_cache.getOrCompute(line_idx, hb_font, text);
        return .{ .slice = slice, .owned = false };
    }
    if (!hasNonAscii(text)) return .{ .slice = null, .owned = false };
    const slice = graphemeClusterOffsets(allocator, hb_font, text) catch null;
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
