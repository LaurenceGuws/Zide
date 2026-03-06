const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub fn parseHyperlink(self: anytype, text: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
    const uri = text[split + 1 ..];
    self.osc_hyperlink.clearRetainingCapacity();
    if (uri.len == 0) {
        self.osc_hyperlink_active = false;
        self.current_hyperlink_id = 0;
        return;
    }
    _ = self.osc_hyperlink.appendSlice(self.allocator, uri) catch |err| {
        log.logf(.warning, "osc hyperlink append failed: {s}", .{@errorName(err)});
        return;
    };
    self.osc_hyperlink_active = true;
    self.current_hyperlink_id = self.appendHyperlink(uri) orelse 0;
}
