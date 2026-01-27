const std = @import("std");
const syntax_mod = @import("editor/syntax.zig");
const text_store = @import("editor/text_store.zig");
const ts_api = @import("editor/treesitter_api.zig");
const c = ts_api.c_api;

const TextStore = text_store.TextStore;
const HighlightToken = syntax_mod.HighlightToken;

const Edit = struct {
    needle: ?[]const u8,
    delete_len: usize,
    insert_text: []const u8,
};

fn pointForByte(store: *TextStore, byte_offset: usize) c.TSPoint {
    const line = store.lineIndexForOffset(byte_offset);
    const line_start = store.lineStart(line);
    return .{
        .row = @as(u32, @intCast(line)),
        .column = @as(u32, @intCast(byte_offset - line_start)),
    };
}

fn findOffset(store: *TextStore, needle: []const u8, allocator: std.mem.Allocator) !usize {
    const total = store.totalLen();
    const text = try store.readRangeAlloc(0, total);
    defer allocator.free(text);
    const idx = std.mem.indexOf(u8, text, needle) orelse return error.TestUnexpectedResult;
    return idx;
}

fn applyEdit(
    store: *TextStore,
    highlighter: *syntax_mod.SyntaxHighlighter,
    start: usize,
    delete_len: usize,
    insert_text: []const u8,
    allocator: std.mem.Allocator,
) !void {
    const start_point = pointForByte(store, start);
    const old_end = start + delete_len;
    const old_end_point = pointForByte(store, old_end);

    if (delete_len > 0) {
        try store.deleteRange(start, delete_len);
    }
    if (insert_text.len > 0) {
        try store.insertBytes(start, insert_text);
    }

    const new_end = start + insert_text.len;
    const ranges = try highlighter.applyEdit(
        start,
        old_end,
        new_end,
        start_point,
        old_end_point,
        allocator,
    );
    allocator.free(ranges);
}

fn applyEditWithRanges(
    store: *TextStore,
    highlighter: *syntax_mod.SyntaxHighlighter,
    start: usize,
    delete_len: usize,
    insert_text: []const u8,
    allocator: std.mem.Allocator,
) ![]syntax_mod.SyntaxHighlighter.ChangedRange {
    const start_point = pointForByte(store, start);
    const old_end = start + delete_len;
    const old_end_point = pointForByte(store, old_end);

    if (delete_len > 0) {
        try store.deleteRange(start, delete_len);
    }
    if (insert_text.len > 0) {
        try store.insertBytes(start, insert_text);
    }

    const new_end = start + insert_text.len;
    return highlighter.applyEdit(
        start,
        old_end,
        new_end,
        start_point,
        old_end_point,
        allocator,
    );
}

fn rangesToLineSpan(store: *TextStore, ranges: []const syntax_mod.SyntaxHighlighter.ChangedRange) ?struct {
    start_line: usize,
    end_line: usize,
} {
    if (ranges.len == 0) return null;
    var min_line = store.lineIndexForOffset(ranges[0].start_byte);
    var max_line = store.lineIndexForOffset(ranges[0].end_byte) + 1;
    for (ranges[1..]) |range| {
        const start_line = store.lineIndexForOffset(range.start_byte);
        const end_line = store.lineIndexForOffset(range.end_byte) + 1;
        if (start_line < min_line) min_line = start_line;
        if (end_line > max_line) max_line = end_line;
    }
    return .{ .start_line = min_line, .end_line = max_line };
}

fn tokenLessThan(_: void, a: HighlightToken, b: HighlightToken) bool {
    if (a.start != b.start) return a.start < b.start;
    if (a.end != b.end) return a.end < b.end;
    if (a.kind != b.kind) return @intFromEnum(a.kind) < @intFromEnum(b.kind);
    if (a.priority != b.priority) return a.priority < b.priority;
    if (a.conceal_lines != b.conceal_lines) return !a.conceal_lines and b.conceal_lines;
    return false;
}

fn expectTokenEqual(a: HighlightToken, b: HighlightToken) !void {
    try std.testing.expectEqual(a.start, b.start);
    try std.testing.expectEqual(a.end, b.end);
    try std.testing.expectEqual(a.kind, b.kind);
    try std.testing.expectEqual(a.priority, b.priority);
    try std.testing.expectEqual(a.conceal_lines, b.conceal_lines);

    if (a.conceal) |value| {
        try std.testing.expect(b.conceal != null);
        try std.testing.expectEqualStrings(value, b.conceal.?);
    } else {
        try std.testing.expect(b.conceal == null);
    }

    if (a.url) |value| {
        try std.testing.expect(b.url != null);
        try std.testing.expectEqualStrings(value, b.url.?);
    } else {
        try std.testing.expect(b.url == null);
    }
}

fn compareHighlights(
    store: *TextStore,
    incremental: *syntax_mod.SyntaxHighlighter,
    full: *syntax_mod.SyntaxHighlighter,
    allocator: std.mem.Allocator,
) !void {
    const total = store.totalLen();
    var inc_tokens = try incremental.highlightRange(0, total, allocator);
    defer allocator.free(inc_tokens);
    var full_tokens = try full.highlightRange(0, total, allocator);
    defer allocator.free(full_tokens);

    std.sort.heap(HighlightToken, inc_tokens, {}, tokenLessThan);
    std.sort.heap(HighlightToken, full_tokens, {}, tokenLessThan);

    try std.testing.expect(inc_tokens.len > 0);
    try std.testing.expectEqual(inc_tokens.len, full_tokens.len);
    for (inc_tokens, full_tokens) |inc, full_token| {
        try expectTokenEqual(inc, full_token);
    }
}

test "incremental edits match full reparse highlights" {
    const allocator = std.testing.allocator;
    const initial = "const foo = 1;\nconst bar = 2;\n";

    var store = try TextStore.init(allocator, initial);
    defer store.deinit();

    const incremental = try syntax_mod.createZigHighlighter(allocator, store);
    defer incremental.destroy();
    const full = try syntax_mod.createZigHighlighter(allocator, store);
    defer full.destroy();

    try compareHighlights(store, incremental, full, allocator);

    const edits = [_]Edit{
        .{ .needle = "foo", .delete_len = 0, .insert_text = "x" },
        .{ .needle = "bar", .delete_len = 3, .insert_text = "baz" },
        .{ .needle = "\nconst ", .delete_len = 7, .insert_text = "" },
        .{ .needle = null, .delete_len = 0, .insert_text = "\nconst qux = 9;" },
    };

    for (edits) |edit| {
        const start = if (edit.needle) |needle|
            try findOffset(store, needle, allocator)
        else
            store.totalLen();

        try applyEdit(store, incremental, start, edit.delete_len, edit.insert_text, allocator);
        try std.testing.expect(full.reparseFull());
        try compareHighlights(store, incremental, full, allocator);
    }
}

test "incremental edits match full reparse highlights with multiline delete" {
    const allocator = std.testing.allocator;
    const initial =
        "const foo = 1;\n" ++
        "/* multi\n" ++
        "line comment */\n" ++
        "const bar = 2;\n";

    var store = try TextStore.init(allocator, initial);
    defer store.deinit();

    const incremental = try syntax_mod.createZigHighlighter(allocator, store);
    defer incremental.destroy();
    const full = try syntax_mod.createZigHighlighter(allocator, store);
    defer full.destroy();

    try compareHighlights(store, incremental, full, allocator);

    const delete_text = "multi\nline ";
    const delete_len = delete_text.len;
    const start = try findOffset(store, delete_text, allocator);
    try applyEdit(store, incremental, start, delete_len, "", allocator);
    try std.testing.expect(full.reparseFull());
    try compareHighlights(store, incremental, full, allocator);
}

test "incremental edits match full reparse highlights with larger fixture" {
    const allocator = std.testing.allocator;
    const initial =
        "const std = @import(\"std\");\n" ++
        "const Foo = struct {\n" ++
        "    name: []const u8,\n" ++
        "    count: usize,\n" ++
        "};\n" ++
        "\n" ++
        "fn greet(foo: Foo) []const u8 {\n" ++
        "    if (foo.count > 0) {\n" ++
        "        return \"hello\";\n" ++
        "    }\n" ++
        "    return \"bye\";\n" ++
        "}\n" ++
        "\n" ++
        "pub fn main() void {\n" ++
        "    const foo = Foo{ .name = \"Zide\", .count = 2 };\n" ++
        "    _ = greet(foo);\n" ++
        "}\n";

    var store = try TextStore.init(allocator, initial);
    defer store.deinit();

    const incremental = try syntax_mod.createZigHighlighter(allocator, store);
    defer incremental.destroy();
    const full = try syntax_mod.createZigHighlighter(allocator, store);
    defer full.destroy();

    try compareHighlights(store, incremental, full, allocator);

    const edits = [_]Edit{
        .{ .needle = "greet", .delete_len = 5, .insert_text = "welcome" },
        .{ .needle = "Zide", .delete_len = 4, .insert_text = "Zed" },
        .{ .needle = "count: usize,\n", .delete_len = 14, .insert_text = "count: usize,\n    active: bool,\n" },
        .{ .needle = "return \"bye\";", .delete_len = 12, .insert_text = "return \"later\";" },
    };

    for (edits) |edit| {
        const start = try findOffset(store, edit.needle.?, allocator);
        try applyEdit(store, incremental, start, edit.delete_len, edit.insert_text, allocator);
        try std.testing.expect(full.reparseFull());
        try compareHighlights(store, incremental, full, allocator);
    }
}

test "applyEdit dirty ranges cover edited lines" {
    const allocator = std.testing.allocator;
    const initial =
        "const alpha = 1;\n" ++
        "const beta = 2;\n" ++
        "const gamma = 3;\n";

    var store = try TextStore.init(allocator, initial);
    defer store.deinit();

    const highlighter = try syntax_mod.createZigHighlighter(allocator, store);
    defer highlighter.destroy();

    const needle = "beta";
    const start = try findOffset(store, needle, allocator);
    const delete_len = needle.len;
    const start_line = store.lineIndexForOffset(start);
    const end_line = store.lineIndexForOffset(start + delete_len) + 1;

    const ranges = try applyEditWithRanges(store, highlighter, start, delete_len, "beta_long", allocator);
    defer allocator.free(ranges);

    try std.testing.expect(ranges.len > 0);
    const span = rangesToLineSpan(store, ranges) orelse return error.TestUnexpectedResult;
    try std.testing.expect(span.start_line <= start_line);
    try std.testing.expect(span.end_line >= end_line);
}
