const app_logger = @import("../../app_logger.zig");

pub fn appendHyperlink(self: anytype, uri: []const u8, max_hyperlinks: usize) ?u32 {
    const log = app_logger.logger("terminal.hyperlink");
    if (uri.len == 0) return 0;
    if (self.core.hyperlink_table.items.len >= max_hyperlinks) {
        for (self.core.hyperlink_table.items) |link| {
            self.allocator.free(link.uri);
        }
        self.core.hyperlink_table.clearRetainingCapacity();
    }
    const duped = self.allocator.dupe(u8, uri) catch |err| {
        log.logf(.warning, "hyperlink uri alloc failed len={d}: {s}", .{ uri.len, @errorName(err) });
        return null;
    };
    _ = self.core.hyperlink_table.append(self.allocator, .{ .uri = duped }) catch {
        self.allocator.free(duped);
        log.logf(.warning, "hyperlink table append failed len={d}", .{uri.len});
        return null;
    };
    return @intCast(self.core.hyperlink_table.items.len);
}

pub fn hyperlinkUri(self: anytype, link_id: u32) ?[]const u8 {
    if (link_id == 0) return null;
    const idx = link_id - 1;
    if (idx >= self.core.hyperlink_table.items.len) return null;
    return self.core.hyperlink_table.items[idx].uri;
}
