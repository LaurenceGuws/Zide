const std = @import("std");
const syntax_mod = @import("../syntax.zig");
const selection_mod = @import("../view/selection.zig");
const draw_list_mod = @import("draw_list.zig");
const overlay_mod = @import("../../ui/widgets/editor_widget_draw_overlay.zig");
const text_mod = @import("../../ui/widgets/editor_widget_draw_text.zig");
const renderer_surface_host = @import("../../ui/renderer/renderer_surface_host.zig");

const HighlightToken = syntax_mod.HighlightToken;
const SelectionRange = selection_mod.SelectionRange;
const EditorDrawList = draw_list_mod.EditorDrawList;
const ByteRange = overlay_mod.ByteRange;

pub fn addEditorLineBaseOps(
    list: *EditorDrawList,
    r: anytype,
    line_num: usize,
    y: f32,
    x: f32,
    gutter_width: f32,
    content_width: f32,
    is_current: bool,
    num_buf: *[16]u8,
) bool {
    var ok = true;

    if (is_current) {
        ok = ok and overlay_mod.addRectOp(list, x + gutter_width, y, content_width - gutter_width, r.editor_char_height, r.theme.current_line);
        ok = ok and overlay_mod.addRectOp(list, x, y, gutter_width, r.editor_char_height, r.theme.current_line);
    }

    const num_str = std.fmt.bufPrint(num_buf, "{d: >4}", .{line_num + 1}) catch return false;
    const pad = 4 * r.uiScaleFactor();
    const line_color = if (is_current) r.theme.foreground else r.theme.line_number;
    const line_bg = if (is_current) r.theme.current_line else r.theme.line_number_bg;
    ok = ok and overlay_mod.addTextOpBg(list, x + pad, y, num_str, line_color, line_bg, false);
    return ok;
}

pub fn drawSelectionOverlays(
    view: anytype,
    r: anytype,
    line_idx: usize,
    cols: usize,
    line_width: usize,
    total_visual_lines: usize,
    seg_idx: usize,
    seg_start_col: usize,
    seg_end_col: usize,
    seg_band: anytype,
    text_start_x: f32,
    ranges: []const SelectionRange,
) void {
    if (ranges.len == 0) return;
    const sel_band = overlay_mod.selectionBandForRowBand(seg_band);
    const selection_color = overlay_mod.softSelectionColor(r.theme.selection);
    for (ranges) |range| {
        const sel_start = @max(range.start_col, seg_start_col);
        const sel_end = @min(range.end_col, seg_end_col);
        if (sel_end <= sel_start) continue;
        const sel_x = text_start_x + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.editor_char_width;
        const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.editor_char_width;
        const corner_mask = overlay_mod.selectionCornerMaskForSegment(view, line_idx, cols, line_width, seg_idx, total_visual_lines, seg_start_col, seg_end_col, range);
        overlay_mod.drawSoftSelectionRect(r, sel_x, sel_band.y_f, sel_w, sel_band.h_f, selection_color, corner_mask);
    }
}

pub fn addSelectionOverlayOps(
    list: *EditorDrawList,
    view: anytype,
    r: anytype,
    line_idx: usize,
    cols: usize,
    line_width: usize,
    total_visual_lines: usize,
    seg_idx: usize,
    seg_start_col: usize,
    seg_end_col: usize,
    seg_band: anytype,
    text_start_x: f32,
    ranges: []const SelectionRange,
) bool {
    if (ranges.len == 0) return true;
    const sel_band = overlay_mod.selectionBandForRowBand(seg_band);
    const selection_color = overlay_mod.softSelectionColor(r.theme.selection);
    var ok = true;
    for (ranges) |range| {
        const sel_start = @max(range.start_col, seg_start_col);
        const sel_end = @min(range.end_col, seg_end_col);
        if (sel_end <= sel_start) continue;
        const sel_x = text_start_x + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.editor_char_width;
        const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.editor_char_width;
        const corner_mask = overlay_mod.selectionCornerMaskForSegment(view, line_idx, cols, line_width, seg_idx, total_visual_lines, seg_start_col, seg_end_col, range);
        ok = ok and overlay_mod.addSoftSelectionRectOp(list, r, sel_x, sel_band.y_f, sel_w, sel_band.h_f, selection_color, corner_mask);
    }
    return ok;
}

pub fn drawSearchOverlays(
    view: anytype,
    r: anytype,
    line_start: usize,
    seg_start_byte: usize,
    seg_end_byte: usize,
    seg_start_col: usize,
    line_text: []const u8,
    seg_band: anytype,
    text_start_x: f32,
) void {
    var search_ranges: [16]ByteRange = undefined;
    const search_count = text_mod.collectSearchByteRanges(line_start + seg_start_byte, line_start + seg_end_byte, view.searchMatches(), &search_ranges);
    if (search_count == 0) return;
    const search_color = overlay_mod.searchHighlightColor(r.theme);
    const active_search = overlay_mod.searchActiveByteRange(view);
    const search_band = overlay_mod.selectionBandForRowBand(seg_band);
    for (search_ranges[0..search_count]) |match| {
        const local_start = match.start - line_start;
        const local_end = match.end - line_start;
        const sx = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_start, text_start_x);
        const ex = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_end, text_start_x);
        if (ex <= sx) continue;
        const draw_color = if (active_search) |active| if (overlay_mod.rangeContains(active, match)) overlay_mod.activeSearchHighlightColor(r.theme) else search_color else search_color;
        renderer_surface_host.drawRect(r, @intFromFloat(sx), search_band.y_i, @intFromFloat(ex - sx), search_band.h_i, draw_color);
    }
}

pub fn addSearchOverlayOps(
    list: *EditorDrawList,
    view: anytype,
    r: anytype,
    line_start: usize,
    seg_start_byte: usize,
    seg_end_byte: usize,
    seg_start_col: usize,
    line_text: []const u8,
    seg_band: anytype,
    text_start_x: f32,
) bool {
    var search_ranges: [16]ByteRange = undefined;
    const search_count = text_mod.collectSearchByteRanges(line_start + seg_start_byte, line_start + seg_end_byte, view.searchMatches(), &search_ranges);
    if (search_count == 0) return true;
    const search_color = overlay_mod.searchHighlightColor(r.theme);
    const active_search = overlay_mod.searchActiveByteRange(view);
    const search_band = overlay_mod.selectionBandForRowBand(seg_band);
    var ok = true;
    for (search_ranges[0..search_count]) |match| {
        const local_start = match.start - line_start;
        const local_end = match.end - line_start;
        const sx = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_start, text_start_x);
        const ex = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_end, text_start_x);
        if (ex <= sx) continue;
        const draw_color = if (active_search) |active| if (overlay_mod.rangeContains(active, match)) overlay_mod.activeSearchHighlightColor(r.theme) else search_color else search_color;
        ok = ok and overlay_mod.addRectOp(list, sx, search_band.y_f, ex - sx, search_band.h_f, draw_color);
    }
    return ok;
}

pub fn drawSegmentText(
    r: anytype,
    line_text: []const u8,
    cluster_slice: ?[]const u32,
    seg_y: f32,
    text_start_x: f32,
    line_start: usize,
    seg_start_byte: usize,
    seg_end_byte: usize,
    seg_start_col: usize,
    seg_end_col: usize,
    effective_tokens: []const HighlightToken,
    selection_ranges: []const SelectionRange,
    is_current: bool,
    disable_programming_ligatures: bool,
) void {
    const base_bg = if (is_current) r.theme.current_line else r.theme.background;
    const selection_bg = overlay_mod.softSelectionColor(r.theme.selection);
    var sel_bytes: [8]ByteRange = undefined;
    const sel_count = if (selection_ranges.len > 0)
        text_mod.buildSelectionByteRanges(line_text, cluster_slice, seg_start_col, seg_end_col, seg_start_byte, seg_end_byte, selection_ranges, &sel_bytes)
    else
        0;

    if (effective_tokens.len == 0) {
        text_mod.drawTextSliceWithSelectionBg(r, text_start_x, seg_y, line_text, seg_start_byte, seg_start_col, seg_start_byte, seg_end_byte, r.theme.foreground, base_bg, selection_bg, sel_bytes[0..sel_count], disable_programming_ligatures);
    } else {
        text_mod.drawHighlightedLineSegment(r, line_text, seg_y, text_start_x, line_start, seg_start_byte, seg_end_byte, seg_start_col, effective_tokens, base_bg, selection_bg, sel_bytes[0..sel_count], disable_programming_ligatures);
    }
}

const FakeColor = struct { r: u8, g: u8, b: u8, a: u8 = 255 };
const FakeTheme = struct {
    current_line: FakeColor = .{ .r = 30, .g = 31, .b = 32 },
    foreground: FakeColor = .{ .r = 220, .g = 221, .b = 222 },
    line_number: FakeColor = .{ .r = 100, .g = 101, .b = 102 },
    line_number_bg: FakeColor = .{ .r = 10, .g = 11, .b = 12 },
    selection: FakeColor = .{ .r = 90, .g = 91, .b = 92, .a = 180 },
    ui_accent: FakeColor = .{ .r = 200, .g = 120, .b = 40, .a = 255 },
    background: FakeColor = .{ .r = 1, .g = 2, .b = 3 },
};

const FakeRenderer = struct {
    theme: FakeTheme = .{},
    char_width: f32 = 8,
    char_height: f32 = 16,

    fn uiScaleFactor(_: @This()) f32 {
        return 1.0;
    }
};

const FakeSearchEditor = struct {
    matches: []const struct { start: usize, end: usize },

    fn searchMatches(self: @This()) []const struct { start: usize, end: usize } {
        return self.matches;
    }
};

const FakeCursorPos = struct {
    line: usize,
    col: usize,
    offset: usize,
};

const FakeSelection = struct {
    start: FakeCursorPos,
    end: FakeCursorPos,

    fn normalized(self: @This()) @This() {
        if (self.start.offset <= self.end.offset) return self;
        return .{ .start = self.end, .end = self.start };
    }

    fn isEmpty(self: @This()) bool {
        return self.start.offset == self.end.offset;
    }
};

const FakeSelectionEditor = struct {
    selection: ?FakeSelection = null,
    selections: struct { items: []const FakeSelection } = .{ .items = &[_]FakeSelection{} },

    fn lineCount(_: @This()) usize {
        return 1;
    }
};

const FakeWidget = struct {
    editor: FakeSelectionEditor,
};

test "addEditorLineBaseOps emits current-line rects and gutter text op" {
    var list = EditorDrawList.init(std.testing.allocator);
    defer list.deinit();
    const renderer = FakeRenderer{};
    var num_buf: [16]u8 = undefined;

    try std.testing.expect(addEditorLineBaseOps(&list, renderer, 2, 10, 4, 20, 120, true, &num_buf));
    try std.testing.expectEqual(@as(usize, 3), list.ops.items.len);
    try std.testing.expect(list.ops.items[0] == .rect);
    try std.testing.expect(list.ops.items[1] == .rect);
    try std.testing.expect(list.ops.items[2] == .text);
    try std.testing.expectEqualStrings("   3", list.ops.items[2].text.text);
}

test "addEditorLineBaseOps for non-current line only emits gutter text" {
    var list = EditorDrawList.init(std.testing.allocator);
    defer list.deinit();
    const renderer = FakeRenderer{};
    var num_buf: [16]u8 = undefined;

    try std.testing.expect(addEditorLineBaseOps(&list, renderer, 0, 0, 0, 20, 120, false, &num_buf));
    try std.testing.expectEqual(@as(usize, 1), list.ops.items.len);
    try std.testing.expect(list.ops.items[0] == .text);
    try std.testing.expectEqualStrings("   1", list.ops.items[0].text.text);
}

test "addSearchOverlayOps emits one rect per visible search match" {
    var list = EditorDrawList.init(std.testing.allocator);
    defer list.deinit();
    const renderer = FakeRenderer{};
    const editor = FakeSearchEditor{
        .matches = &[_]struct { start: usize, end: usize }{
            .{ .start = 1, .end = 3 },
            .{ .start = 5, .end = 7 },
        },
    };
    const seg_band = struct { y_i: i32 = 0, h_i: i32 = 16, y_f: f32 = 0, h_f: f32 = 16 }{};

    try std.testing.expect(addSearchOverlayOps(&list, editor, renderer, 0, 0, 8, 0, "abcdefgh", seg_band, 20));
    try std.testing.expectEqual(@as(usize, 2), list.ops.items.len);
    try std.testing.expect(list.ops.items[0] == .rect);
    try std.testing.expect(list.ops.items[1] == .rect);
    try std.testing.expectEqual(@as(f32, 28), list.ops.items[0].rect.x);
    try std.testing.expectEqual(@as(f32, 16), list.ops.items[0].rect.w);
    try std.testing.expectEqual(@as(f32, 60), list.ops.items[1].rect.x);
    try std.testing.expectEqual(@as(f32, 16), list.ops.items[1].rect.w);
}

test "addSearchOverlayOps clips matches to the visible segment" {
    var list = EditorDrawList.init(std.testing.allocator);
    defer list.deinit();
    const renderer = FakeRenderer{};
    const editor = FakeSearchEditor{
        .matches = &[_]struct { start: usize, end: usize }{
            .{ .start = 0, .end = 3 },
            .{ .start = 3, .end = 9 },
            .{ .start = 9, .end = 12 },
        },
    };
    const seg_band = struct { y_i: i32 = 0, h_i: i32 = 16, y_f: f32 = 0, h_f: f32 = 16 }{};

    try std.testing.expect(addSearchOverlayOps(&list, editor, renderer, 0, 2, 8, 2, "abcdefghijkl", seg_band, 10));
    try std.testing.expectEqual(@as(usize, 2), list.ops.items.len);
    try std.testing.expectEqual(@as(f32, 10), list.ops.items[0].rect.x);
    try std.testing.expectEqual(@as(f32, 8), list.ops.items[0].rect.w);
    try std.testing.expectEqual(@as(f32, 18), list.ops.items[1].rect.x);
    try std.testing.expectEqual(@as(f32, 40), list.ops.items[1].rect.w);
}

test "addSelectionOverlayOps emits selection rect for selected span" {
    var list = EditorDrawList.init(std.testing.allocator);
    defer list.deinit();
    const renderer = FakeRenderer{};
    const widget = FakeWidget{
        .editor = .{
            .selection = .{
                .start = .{ .line = 0, .col = 1, .offset = 1 },
                .end = .{ .line = 0, .col = 3, .offset = 3 },
            },
        },
    };
    const seg_band = struct { y_i: i32 = 0, h_i: i32 = 16, y_f: f32 = 0, h_f: f32 = 16 }{};
    const ranges = [_]SelectionRange{.{ .start_col = 1, .end_col = 3 }};

    try std.testing.expect(addSelectionOverlayOps(&list, widget, renderer, 0, 8, 8, 1, 0, 0, 8, seg_band, 20, &ranges));
    try std.testing.expectEqual(@as(usize, 1), list.ops.items.len);
    try std.testing.expect(list.ops.items[0] == .rect);
    try std.testing.expectEqual(@as(f32, 27), list.ops.items[0].rect.x);
    try std.testing.expectEqual(@as(f32, 10), list.ops.items[0].rect.w);
}
