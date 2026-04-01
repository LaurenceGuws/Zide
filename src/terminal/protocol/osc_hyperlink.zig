const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub fn parseHyperlink(self: anytype, text: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
    const uri = text[split + 1 ..];
    self.core.osc_hyperlink.clearRetainingCapacity();
    if (uri.len == 0) {
        self.core.osc_hyperlink_active = false;
        self.core.current_hyperlink_id = 0;
        return;
    }
    _ = self.core.osc_hyperlink.appendSlice(self.allocator, uri) catch |err| {
        log.logf(.warning, "osc hyperlink append failed: {s}", .{@errorName(err)});
        return;
    };
    self.core.osc_hyperlink_active = true;
    self.core.current_hyperlink_id = self.appendHyperlink(uri) orelse 0;
}
