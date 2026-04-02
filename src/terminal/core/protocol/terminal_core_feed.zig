pub const FeedResult = struct {
    parsed: bool,
    scroll_offset: usize,
};

pub fn feedOutputBytesLocked(self: anytype, bytes: []const u8) FeedResult {
    if (bytes.len == 0) return .{ .parsed = false, .scroll_offset = self.core.history.scrollOffset() };
    self.core.parser.handleSlice(self, bytes);
    return .{
        .parsed = true,
        .scroll_offset = self.core.history.scrollOffset(),
    };
}

pub fn feedOutputBytes(self: anytype, bytes: []const u8) void {
    self.session.control.state_mutex.lock();
    defer self.session.control.state_mutex.unlock();
    const result = feedOutputBytesLocked(self, bytes);
    @import("../publication/publication_flow.zig").publishFeedResultLocked(self, result);
}
