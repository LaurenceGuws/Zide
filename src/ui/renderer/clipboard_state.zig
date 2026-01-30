const clipboard = @import("clipboard.zig");
const std = @import("std");

pub fn getText(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8)) ?[]const u8 {
    const slice = clipboard.getText() orelse return null;
    if (slice.len == 0) {
        clipboard.freeText(slice);
        return null;
    }
    buffer.clearRetainingCapacity();
    _ = buffer.appendSlice(allocator, slice) catch {
        clipboard.freeText(slice);
        return null;
    };
    clipboard.freeText(slice);
    return buffer.items;
}
