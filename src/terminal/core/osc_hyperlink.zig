const std = @import("std");

pub fn parseHyperlink(self: anytype, text: []const u8) void {
    const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
    const uri = text[split + 1 ..];
    self.osc_hyperlink.clearRetainingCapacity();
    if (uri.len == 0) {
        self.osc_hyperlink_active = false;
        self.current_hyperlink_id = 0;
        return;
    }
    _ = self.osc_hyperlink.appendSlice(self.allocator, uri) catch return;
    self.osc_hyperlink_active = true;
    self.current_hyperlink_id = self.appendHyperlink(uri) orelse 0;
}
