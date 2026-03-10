const std = @import("std");
const hyperlink_table = @import("hyperlink_table.zig");

pub fn takeOscClipboardCopyLocked(self: anytype, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !bool {
    out.clearRetainingCapacity();
    if (!self.core.osc_clipboard_pending) return false;
    try out.appendSlice(allocator, self.core.osc_clipboard.items);
    self.core.osc_clipboard_pending = false;
    return true;
}

pub fn takeOscClipboardCopy(self: anytype, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !bool {
    self.lock();
    defer self.unlock();
    return takeOscClipboardCopyLocked(self, allocator, out);
}

pub fn tryTakeOscClipboardCopy(self: anytype, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !bool {
    out.clearRetainingCapacity();
    if (!self.tryLock()) return false;
    defer self.unlock();
    return takeOscClipboardCopyLocked(self, allocator, out);
}

pub fn copyHyperlinkUri(self: anytype, allocator: std.mem.Allocator, link_id: u32, out: *std.ArrayList(u8)) !?[]const u8 {
    self.lock();
    defer self.unlock();
    out.clearRetainingCapacity();
    const uri = hyperlink_table.hyperlinkUri(self, link_id) orelse return null;
    try out.appendSlice(allocator, uri);
    return out.items;
}
