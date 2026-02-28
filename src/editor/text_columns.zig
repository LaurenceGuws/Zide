const std = @import("std");

pub fn visualColumnForByteIndex(text: []const u8, byte_index: usize) usize {
    if (byte_index == 0 or text.len == 0) return 0;
    const target = @min(byte_index, text.len);
    var it = std.unicode.Utf8View.initUnchecked(text).iterator();
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

pub fn byteIndexForVisualColumn(text: []const u8, column: usize) usize {
    if (column == 0 or text.len == 0) return 0;
    var it = std.unicode.Utf8View.initUnchecked(text).iterator();
    var col: usize = 0;
    var idx: usize = 0;
    while (it.nextCodepointSlice()) |slice| {
        const cp = std.unicode.utf8Decode(slice) catch 0xFFFD;
        const width = cellWidthForCodepoint(cp, col);
        if (width == 0) {
            idx += slice.len;
            continue;
        }
        if (col >= column) return idx;
        if (col + width > column) return idx;
        idx += slice.len;
        col += width;
    }
    return text.len;
}

pub fn visualWidth(text: []const u8) usize {
    return visualColumnForByteIndex(text, text.len);
}

pub fn visualColumnForByteIndexWithClusters(text: []const u8, byte_index: usize, clusters: ?[]const u32) usize {
    if (clusters) |cluster_offsets| {
        if (cluster_offsets.len == 0) return visualColumnForByteIndex(text, byte_index);
        const target = @min(byte_index, text.len);
        var vis: usize = 0;
        var idx: usize = 0;
        while (idx < cluster_offsets.len) : (idx += 1) {
            const start = @min(@as(usize, cluster_offsets[idx]), text.len);
            const end = if (idx + 1 < cluster_offsets.len) @min(@as(usize, cluster_offsets[idx + 1]), text.len) else text.len;
            if (target <= start) return vis;
            if (target < end) return vis;
            vis += visualWidth(text[start..end]);
        }
        return vis;
    }
    return visualColumnForByteIndex(text, byte_index);
}

pub fn byteIndexForVisualColumnWithClusters(text: []const u8, column: usize, clusters: ?[]const u32) usize {
    if (clusters) |cluster_offsets| {
        if (cluster_offsets.len == 0) return byteIndexForVisualColumn(text, column);
        var vis: usize = 0;
        var idx: usize = 0;
        while (idx < cluster_offsets.len) : (idx += 1) {
            const start = @min(@as(usize, cluster_offsets[idx]), text.len);
            const end = if (idx + 1 < cluster_offsets.len) @min(@as(usize, cluster_offsets[idx + 1]), text.len) else text.len;
            const width = visualWidth(text[start..end]);
            if (vis >= column) return start;
            if (vis + width > column) return start;
            vis += width;
        }
        return text.len;
    }
    return byteIndexForVisualColumn(text, column);
}

pub fn cellWidthForCodepoint(cp: u21, col: usize) usize {
    if (cp == '\t') {
        const tab_width: usize = 4;
        return tab_width - (col % tab_width);
    }
    if (isCombiningMark(cp)) return 0;
    if (isWideCodepoint(cp)) return 2;
    return 1;
}

fn isCombiningMark(cp: u21) bool {
    return (cp >= 0x0300 and cp <= 0x036F) or
        (cp >= 0x0483 and cp <= 0x0489) or
        (cp >= 0x0591 and cp <= 0x05BD) or
        cp == 0x05BF or
        (cp >= 0x05C1 and cp <= 0x05C2) or
        (cp >= 0x05C4 and cp <= 0x05C5) or
        cp == 0x05C7 or
        (cp >= 0x0610 and cp <= 0x061A) or
        (cp >= 0x064B and cp <= 0x065F) or
        cp == 0x0670 or
        (cp >= 0x06D6 and cp <= 0x06ED) or
        cp == 0x0711 or
        (cp >= 0x0730 and cp <= 0x074A) or
        (cp >= 0x07A6 and cp <= 0x07B0) or
        (cp >= 0x07EB and cp <= 0x07F3) or
        (cp >= 0x0816 and cp <= 0x082D) or
        (cp >= 0x0859 and cp <= 0x085B) or
        (cp >= 0x08D3 and cp <= 0x0902) or
        cp == 0x093A or
        cp == 0x093C or
        (cp >= 0x0941 and cp <= 0x0948) or
        cp == 0x094D or
        (cp >= 0x0951 and cp <= 0x0957) or
        (cp >= 0x0962 and cp <= 0x0963) or
        (cp >= 0x1AB0 and cp <= 0x1AFF) or
        (cp >= 0x1DC0 and cp <= 0x1DFF) or
        (cp >= 0x20D0 and cp <= 0x20FF) or
        (cp >= 0xFE00 and cp <= 0xFE0F) or
        (cp >= 0xFE20 and cp <= 0xFE2F) or
        cp == 0x200C or cp == 0x200D or
        (cp >= 0xE0100 and cp <= 0xE01EF) or
        (cp >= 0x1F3FB and cp <= 0x1F3FF);
}

fn isWideCodepoint(cp: u21) bool {
    return (cp >= 0x1100 and cp <= 0x115F) or
        cp == 0x2329 or cp == 0x232A or
        (cp >= 0x2E80 and cp <= 0xA4CF and cp != 0x303F) or
        (cp >= 0xAC00 and cp <= 0xD7A3) or
        (cp >= 0xF900 and cp <= 0xFAFF) or
        (cp >= 0xFE10 and cp <= 0xFE19) or
        (cp >= 0xFE30 and cp <= 0xFE6F) or
        (cp >= 0xFF00 and cp <= 0xFF60) or
        (cp >= 0xFFE0 and cp <= 0xFFE6) or
        (cp >= 0x1F300 and cp <= 0x1FAFF) or
        (cp >= 0x20000 and cp <= 0x3FFFD);
}

test "text columns handle tabs combining marks and wide glyphs" {
    try std.testing.expectEqual(@as(usize, 4), visualColumnForByteIndex("\tX", 1));
    try std.testing.expectEqual(@as(usize, 1), visualColumnForByteIndex("e\u{0301}x", 3));
    try std.testing.expectEqual(@as(usize, 2), visualColumnForByteIndex("界x", 3));
    try std.testing.expectEqual(@as(usize, 3), byteIndexForVisualColumn("e\u{0301}x", 1));
    try std.testing.expectEqual(@as(usize, 0), byteIndexForVisualColumn("界x", 1));
    try std.testing.expectEqual(@as(usize, 3), byteIndexForVisualColumn("界x", 2));
}
