pub fn appendHyperlink(self: anytype, uri: []const u8, max_hyperlinks: usize) ?u32 {
    if (uri.len == 0) return 0;
    if (self.hyperlink_table.items.len >= max_hyperlinks) {
        for (self.hyperlink_table.items) |link| {
            self.allocator.free(link.uri);
        }
        self.hyperlink_table.clearRetainingCapacity();
    }
    const duped = self.allocator.dupe(u8, uri) catch return null;
    _ = self.hyperlink_table.append(self.allocator, .{ .uri = duped }) catch {
        self.allocator.free(duped);
        return null;
    };
    return @intCast(self.hyperlink_table.items.len);
}

pub fn hyperlinkUri(self: anytype, link_id: u32) ?[]const u8 {
    if (link_id == 0) return null;
    const idx = link_id - 1;
    if (idx >= self.hyperlink_table.items.len) return null;
    return self.hyperlink_table.items[idx].uri;
}
