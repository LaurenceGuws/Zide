const app_logger = @import("../../app_logger.zig");

pub fn setTitle(self: anytype, text: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    self.title_buffer.clearRetainingCapacity();
    const max_len: usize = 256;
    const slice = if (text.len > max_len) text[0..max_len] else text;
    _ = self.title_buffer.appendSlice(self.allocator, slice) catch |err| {
        log.logf(.warning, "osc title append failed: {s}", .{@errorName(err)});
        return;
    };
    self.title = self.title_buffer.items;
}
