const terminal_core_mod = @import("../terminal_core.zig");

pub const FeedResult = terminal_core_mod.TerminalCore.OutputFeedResult;

pub fn feedOutputBytesLocked(self: anytype, bytes: []const u8) FeedResult {
    return self.core.feedOutputBytesLocked(self, bytes);
}

pub fn feedOutputBytes(self: anytype, bytes: []const u8) void {
    self.session.control.state_mutex.lock();
    defer self.session.control.state_mutex.unlock();
    const result = feedOutputBytesLocked(self, bytes);
    @import("../publication/publication_flow.zig").publishFeedResultLocked(self, result);
}
