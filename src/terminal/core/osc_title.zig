pub fn setTitle(self: anytype, text: []const u8) void {
    self.title_buffer.clearRetainingCapacity();
    const max_len: usize = 256;
    const slice = if (text.len > max_len) text[0..max_len] else text;
    _ = self.title_buffer.appendSlice(self.allocator, slice) catch return;
    self.title = self.title_buffer.items;
}
