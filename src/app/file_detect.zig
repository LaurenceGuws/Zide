const std = @import("std");

pub fn isProbablyTextFile(path: []const u8) bool {
    var file = if (std.fs.path.isAbsolute(path))
        std.fs.openFileAbsolute(path, .{ .mode = .read_only }) catch return false
    else
        std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch return false;
    defer file.close();
    const stat = file.stat() catch return false;
    if (stat.kind != .file) return false;
    var buf: [8192]u8 = undefined;
    const n = file.read(&buf) catch return false;
    if (n == 0) return true;
    if (std.mem.indexOfScalar(u8, buf[0..n], 0) != null) return false;
    return std.unicode.utf8ValidateSlice(buf[0..n]);
}
