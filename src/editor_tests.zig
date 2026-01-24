const std = @import("std");
const Editor = @import("editor/editor.zig").Editor;

test "editor selection replace uses single undo" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("hello world");
    editor.selection = .{
        .start = .{ .line = 0, .col = 6, .offset = 6 },
        .end = .{ .line = 0, .col = 11, .offset = 11 },
    };

    try editor.insertText("zide");
    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("hello zide", after);

    try std.testing.expect(try editor.undo());
    const undone = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(undone);
    try std.testing.expectEqualStrings("hello world", undone);
}

test "editor grouped undo with mixed insert/delete" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("abcdef");
    editor.selection = .{
        .start = .{ .line = 0, .col = 2, .offset = 2 },
        .end = .{ .line = 0, .col = 4, .offset = 4 },
    };
    try editor.insertText("XY");
    try editor.insertText("!");

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("abXY!ef", after);

    try std.testing.expect(try editor.undo());
    const undone = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(undone);
    try std.testing.expectEqualStrings("abXYef", undone);
}

test "editor explicit undo group wraps multiple ops" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    editor.beginUndoGroup();
    try editor.insertText("foo");
    try editor.insertText("bar");
    try editor.endUndoGroup();

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("foobar", after);

    try std.testing.expect(try editor.undo());
    const undone = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(undone);
    try std.testing.expectEqualStrings("", undone);
}

test "editor undo redo updates cursor offset" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("word1 word2");
    editor.selection = .{
        .start = .{ .line = 0, .col = 5, .offset = 5 },
        .end = .{ .line = 0, .col = 11, .offset = 11 },
    };
    try editor.deleteSelection();

    const after_delete = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after_delete);
    try std.testing.expectEqualStrings("word1", after_delete);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.col);

    try std.testing.expect(try editor.undo());
    const after_undo = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after_undo);
    try std.testing.expectEqualStrings("word1 word2", after_undo);
    try std.testing.expectEqual(@as(usize, 11), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 11), editor.cursor.col);

    try std.testing.expect(try editor.redo());
    const after_redo = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after_redo);
    try std.testing.expectEqualStrings("word1", after_redo);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.col);
}

test "editor line width cache counts utf8 codepoints" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("aé文𐍈");
    const line = try editor.getLineAlloc(0);
    defer allocator.free(line);
    try std.testing.expectEqual(@as(usize, 4), editor.lineWidthCached(0, line, null));
}

test "editor line width cache uses grapheme clusters when provided" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    // "a" + combining acute accent + "b" should be 2 grapheme clusters.
    try editor.insertText("a\u{0301}b");
    const line = try editor.getLineAlloc(0);
    defer allocator.free(line);

    const clusters = [_]u32{ 0, 3 };
    try std.testing.expectEqual(@as(usize, 2), editor.lineWidthCached(0, line, &clusters));
}

test "editor selection normalization merges overlaps" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("abcdef");
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 3, .offset = 3 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 2, .offset = 2 },
        .end = .{ .line = 0, .col = 5, .offset = 5 },
    });
    try editor.normalizeSelections();

    try std.testing.expectEqual(@as(usize, 1), editor.selectionCount());
    const sel = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 1), sel.start.offset);
    try std.testing.expectEqual(@as(usize, 5), sel.end.offset);
}

test "editor rectangular selections do not merge" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("one\ntwo\nthree");
    try editor.addRectSelection(.{ .line = 0, .col = 0, .offset = 0 }, .{ .line = 0, .col = 2, .offset = 2 });
    try editor.addRectSelection(.{ .line = 0, .col = 1, .offset = 1 }, .{ .line = 0, .col = 3, .offset = 3 });
    try editor.normalizeSelections();

    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    const first = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    const second = editor.selectionAt(1) orelse return error.TestUnexpectedResult;
    try std.testing.expect(first.is_rectangular);
    try std.testing.expect(second.is_rectangular);
}

test "editor expand rect selection creates per-line selections" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("one\ntwo\nthree");
    try editor.expandRectSelection(0, 2, 1, 3);
    try std.testing.expectEqual(@as(usize, 3), editor.selectionCount());
}

test "editor insert across rectangular selections" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("one\ntwo\nthree");
    try editor.expandRectSelection(0, 2, 1, 2);
    try editor.insertChar('X');

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("oXe\ntXo\ntXree", after);
}

const draw_mod = @import("ui/widgets/editor_widget_draw.zig");
const editor_render = @import("editor/render/renderer_ops.zig");

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

const Theme = struct {
    background: Color = Color{ .r = 40, .g = 42, .b = 54 },
    foreground: Color = Color{ .r = 248, .g = 248, .b = 242 },
    selection: Color = Color{ .r = 68, .g = 71, .b = 90 },
    cursor: Color = Color{ .r = 248, .g = 248, .b = 242 },
    link: Color = Color{ .r = 139, .g = 233, .b = 253 },
    line_number: Color = Color{ .r = 98, .g = 114, .b = 164 },
    line_number_bg: Color = Color{ .r = 33, .g = 34, .b = 44 },
    current_line: Color = Color{ .r = 50, .g = 52, .b = 66 },
    comment_color: Color = Color{ .r = 98, .g = 114, .b = 164 },
    string: Color = Color{ .r = 241, .g = 250, .b = 140 },
    keyword: Color = Color{ .r = 255, .g = 121, .b = 198 },
    number: Color = Color{ .r = 189, .g = 147, .b = 249 },
    function: Color = Color{ .r = 80, .g = 250, .b = 123 },
    variable: Color = Color{ .r = 248, .g = 248, .b = 242 },
    type_name: Color = Color{ .r = 139, .g = 233, .b = 253 },
    operator: Color = Color{ .r = 255, .g = 121, .b = 198 },
    builtin_color: Color = Color{ .r = 139, .g = 233, .b = 253 },
    punctuation: Color = Color{ .r = 248, .g = 248, .b = 242 },
    constant: Color = Color{ .r = 189, .g = 147, .b = 249 },
    attribute: Color = Color{ .r = 80, .g = 250, .b = 123 },
    namespace: Color = Color{ .r = 139, .g = 233, .b = 253 },
    label: Color = Color{ .r = 139, .g = 233, .b = 253 },
    error_token: Color = Color{ .r = 255, .g = 85, .b = 85 },
};

const DrawLog = struct {
    allocator: std.mem.Allocator,
    data: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) DrawLog {
        return .{ .allocator = allocator, .data = .empty };
    }

    pub fn deinit(self: *DrawLog) void {
        self.data.deinit(self.allocator);
    }

    pub fn append(self: *DrawLog, comptime fmt: []const u8, args: anytype) void {
        self.data.writer(self.allocator).print(fmt, args) catch {};
    }

    pub fn appendColor(self: *DrawLog, color: Color) void {
        self.append("#{X:0>2}{X:0>2}{X:0>2}{X:0>2}", .{ color.r, color.g, color.b, color.a });
    }

    pub fn appendEscaped(self: *DrawLog, text: []const u8) void {
        for (text) |ch| {
            switch (ch) {
                '\\' => self.append("\\\\", .{}),
                '"' => self.append("\\\"", .{}),
                '\n' => self.append("\\n", .{}),
                '\r' => self.append("\\r", .{}),
                '\t' => self.append("\\t", .{}),
                else => self.append("{c}", .{ch}),
            }
        }
    }
};

const FakeRenderer = struct {
    allocator: std.mem.Allocator,
    width: i32,
    height: i32,
    char_width: f32,
    char_height: f32,
    theme: Theme,
    log: DrawLog,

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32, char_width: f32, char_height: f32) FakeRenderer {
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .char_width = char_width,
            .char_height = char_height,
            .theme = .{},
            .log = DrawLog.init(allocator),
        };
    }

    pub fn deinit(self: *FakeRenderer) void {
        self.log.deinit();
    }

    pub fn uiScaleFactor(self: *FakeRenderer) f32 {
        _ = self;
        return 1.0;
    }

    pub fn drawRect(self: *FakeRenderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        self.log.append("rect {d} {d} {d} {d} ", .{ x, y, w, h });
        self.log.appendColor(color);
        self.log.append("\n", .{});
    }

    pub fn drawText(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: Color) void {
        const xi: i32 = @intFromFloat(x);
        const yi: i32 = @intFromFloat(y);
        self.log.append("text {d} {d} \"", .{ xi, yi });
        self.log.appendEscaped(text);
        self.log.append("\" ", .{});
        self.log.appendColor(color);
        self.log.append("\n", .{});
    }

    pub fn drawEditorLineBase(
        self: *FakeRenderer,
        line_num: usize,
        y: f32,
        x: f32,
        gutter_width: f32,
        content_width: f32,
        is_current: bool,
    ) void {
        editor_render.drawEditorLineBase(self, line_num, y, x, gutter_width, content_width, is_current);
    }

    pub fn drawCursor(self: *FakeRenderer, x: f32, y: f32, mode: enum { block, line, underline }) void {
        editor_render.drawCursor(self, x, y, mode);
    }
};

const FakeWidget = struct {
    editor: *Editor,
    gutter_width: f32,
    wrap_enabled: bool,

    pub fn viewportColumns(self: *FakeWidget, r: *FakeRenderer) usize {
        const editor_width = @max(0, r.width - @as(i32, @intFromFloat(self.gutter_width)));
        if (r.char_width <= 0) return 0;
        return @as(usize, @intFromFloat(@as(f32, @floatFromInt(editor_width)) / r.char_width));
    }

    pub fn clusterOffsets(
        self: *FakeWidget,
        r: *FakeRenderer,
        line_idx: usize,
        line_text: []const u8,
        out_slice: *?[]const u32,
        out_owned: *bool,
    ) void {
        _ = self;
        _ = r;
        _ = line_idx;
        _ = line_text;
        out_slice.* = null;
        out_owned.* = false;
    }
};

test "editor render snapshot baseline" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("hello\nworld");
    editor.setCursor(1, 2);

    var renderer = FakeRenderer.init(allocator, 320, 200, 8, 16);
    defer renderer.deinit();

    var widget = FakeWidget{
        .editor = editor,
        .gutter_width = 0,
        .wrap_enabled = false,
    };

    draw_mod.draw(&widget, &renderer, 0, 0, 320, 200);

    const expected =
        "rect 0 0 50 200 #21222CFF\n" ++
        "text 4 0 \"   1\" #6272A4FF\n" ++
        "text 58 0 \"hello\" #F8F8F2FF\n" ++
        "rect 50 16 270 16 #323442FF\n" ++
        "rect 0 16 50 16 #323442FF\n" ++
        "text 4 16 \"   2\" #F8F8F2FF\n" ++
        "text 58 16 \"world\" #F8F8F2FF\n" ++
        "rect 74 16 2 16 #F8F8F2FF\n";

    try std.testing.expectEqualStrings(expected, renderer.log.data.items);
}
