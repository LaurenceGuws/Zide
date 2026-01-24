const std = @import("std");

pub fn visualLineCountForWidth(cols: usize, width: usize) usize {
    if (cols == 0) return 1;
    if (width == 0) return 1;
    return @max(@as(usize, 1), (width + cols - 1) / cols);
}

test "visual line count rounds to viewport columns" {
    const cols: usize = 4;
    try std.testing.expectEqual(@as(usize, 3), visualLineCountForWidth(cols, 10));
}
