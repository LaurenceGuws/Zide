const std = @import("std");
const editor_mod = @import("../editor.zig");

const Editor = editor_mod.Editor;

pub const SelectionRange = struct {
    start_col: usize,
    end_col: usize,
};

pub fn collectSelectionRanges(
    editor: *Editor,
    line_idx: usize,
    line_text: []const u8,
    cluster_offsets: ?[]const u32,
    ranges: *[8]SelectionRange,
    count: *usize,
) void {
    const line_len = line_text.len;
    if (line_len == 0) {
        if (editor.selection) |sel| {
            const norm = sel.normalized();
            if (!norm.isEmpty() and line_idx >= norm.start.line and line_idx <= norm.end.line) {
                addSelectionRange(ranges, count, 0, 1);
            }
        }
        for (editor.selections.items) |sel| {
            const norm = sel.normalized();
            if (norm.isEmpty()) continue;
            if (line_idx < norm.start.line or line_idx > norm.end.line) continue;
            addSelectionRange(ranges, count, 0, 1);
        }
        return;
    }
    if (editor.selection) |sel| {
        const norm = sel.normalized();
        if (line_idx >= norm.start.line and line_idx <= norm.end.line) {
            var start_col: usize = 0;
            var end_col: usize = line_len;
            if (line_idx == norm.start.line) start_col = @min(norm.start.col, line_len);
            if (line_idx == norm.end.line) end_col = @min(norm.end.col, line_len);
            const start_vis = visualColumnForByteIndex(line_text, start_col, cluster_offsets);
            const end_vis = visualColumnForByteIndex(line_text, end_col, cluster_offsets);
            addSelectionRange(ranges, count, start_vis, end_vis);
        }
    }
    for (editor.selections.items) |sel| {
        const norm = sel.normalized();
        if (line_idx < norm.start.line or line_idx > norm.end.line) continue;
        var start_col: usize = 0;
        var end_col: usize = line_len;
        if (line_idx == norm.start.line) start_col = @min(norm.start.col, line_len);
        if (line_idx == norm.end.line) end_col = @min(norm.end.col, line_len);
        const start_vis = visualColumnForByteIndex(line_text, start_col, cluster_offsets);
        const end_vis = visualColumnForByteIndex(line_text, end_col, cluster_offsets);
        addSelectionRange(ranges, count, start_vis, end_vis);
    }
}

pub fn visualColumnForByteIndex(text: []const u8, byte_index: usize, cluster_offsets: ?[]const u32) usize {
    if (cluster_offsets) |clusters| {
        if (clusters.len == 0) return utf8ColumnForByteIndex(text, byte_index);
        const target = @min(byte_index, text.len);
        var idx: usize = 0;
        while (idx < clusters.len and clusters[idx] < target) : (idx += 1) {}
        return idx;
    }
    return utf8ColumnForByteIndex(text, byte_index);
}

pub fn byteIndexForVisualColumn(text: []const u8, column: usize, cluster_offsets: ?[]const u32) usize {
    if (cluster_offsets) |clusters| {
        if (clusters.len == 0) return utf8ByteIndexForColumn(text, column);
        if (column >= clusters.len) return text.len;
        return @min(@as(usize, clusters[column]), text.len);
    }
    return utf8ByteIndexForColumn(text, column);
}

fn addSelectionRange(ranges: *[8]SelectionRange, count: *usize, start_col: usize, end_col: usize) void {
    if (end_col <= start_col) return;
    if (count.* >= ranges.len) return;
    ranges[count.*] = .{ .start_col = start_col, .end_col = end_col };
    count.* += 1;
}

fn utf8ColumnForByteIndex(line_text: []const u8, byte_index: usize) usize {
    if (byte_index == 0 or line_text.len == 0) return 0;
    const target = @min(byte_index, line_text.len);
    var it = std.unicode.Utf8View.initUnchecked(line_text).iterator();
    var col: usize = 0;
    var idx: usize = 0;
    while (it.nextCodepointSlice()) |slice| {
        const next_idx = idx + slice.len;
        if (target < next_idx) return col;
        idx = next_idx;
        const cp = std.unicode.utf8Decode(slice) catch 0xFFFD;
        col += cellWidthForCodepoint(cp, col);
    }
    return col;
}

fn utf8ByteIndexForColumn(line_text: []const u8, column: usize) usize {
    if (column == 0 or line_text.len == 0) return 0;
    var it = std.unicode.Utf8View.initUnchecked(line_text).iterator();
    var col: usize = 0;
    var idx: usize = 0;
    while (it.nextCodepointSlice()) |slice| {
        if (col >= column) return idx;
        const cp = std.unicode.utf8Decode(slice) catch 0xFFFD;
        const width = cellWidthForCodepoint(cp, col);
        if (col + width > column) return idx;
        idx += slice.len;
        col += width;
    }
    return line_text.len;
}

fn cellWidthForCodepoint(cp: u21, col: usize) usize {
    if (cp == '\t') {
        const tab_width: usize = 4;
        return tab_width - (col % tab_width);
    }
    return 1;
}

test "utf8 column mapping" {
    const s = "a😀b";
    try std.testing.expectEqual(@as(usize, 0), utf8ColumnForByteIndex(s, 0));
    try std.testing.expectEqual(@as(usize, 1), utf8ColumnForByteIndex(s, 1));
    try std.testing.expectEqual(@as(usize, 1), utf8ColumnForByteIndex(s, 3));
    try std.testing.expectEqual(@as(usize, 2), utf8ColumnForByteIndex(s, 5));
    try std.testing.expectEqual(@as(usize, 3), utf8ColumnForByteIndex(s, 6));

    try std.testing.expectEqual(@as(usize, 0), utf8ByteIndexForColumn(s, 0));
    try std.testing.expectEqual(@as(usize, 1), utf8ByteIndexForColumn(s, 1));
    try std.testing.expectEqual(@as(usize, 5), utf8ByteIndexForColumn(s, 2));
    try std.testing.expectEqual(@as(usize, 6), utf8ByteIndexForColumn(s, 3));
    try std.testing.expectEqual(@as(usize, s.len), utf8ByteIndexForColumn(s, 4));
    try std.testing.expectEqual(@as(usize, s.len), utf8ByteIndexForColumn(s, 5));
}

test "ligature-like ascii cursor mapping remains stable" {
    const s = "a->b ~> c === d != e <= f >= g <=> h";
    var i: usize = 0;
    while (i <= s.len) : (i += 1) {
        const col = visualColumnForByteIndex(s, i, null);
        const back = byteIndexForVisualColumn(s, col, null);
        try std.testing.expectEqual(i, back);
    }
}

test "selection range mapping around operator chains" {
    const s = "fn x() { return a->b ~= c; }";
    const start = 16; // points to 'a'
    const end = 22; // points after 'c'
    const start_col = visualColumnForByteIndex(s, start, null);
    const end_col = visualColumnForByteIndex(s, end, null);
    try std.testing.expectEqual(@as(usize, 16), start_col);
    try std.testing.expectEqual(@as(usize, 22), end_col);
    try std.testing.expectEqual(start, byteIndexForVisualColumn(s, start_col, null));
    try std.testing.expectEqual(end, byteIndexForVisualColumn(s, end_col, null));
}

test "tab expansion visual columns" {
    const s = "\tfoo";
    try std.testing.expectEqual(@as(usize, 0), utf8ColumnForByteIndex(s, 0));
    try std.testing.expectEqual(@as(usize, 4), utf8ColumnForByteIndex(s, 1));
    try std.testing.expectEqual(@as(usize, 5), utf8ColumnForByteIndex(s, 2));
    try std.testing.expectEqual(@as(usize, 0), utf8ByteIndexForColumn(s, 0));
    try std.testing.expectEqual(@as(usize, 0), utf8ByteIndexForColumn(s, 3));
    try std.testing.expectEqual(@as(usize, 1), utf8ByteIndexForColumn(s, 4));
}
