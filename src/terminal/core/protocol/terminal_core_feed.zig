const terminal_core_mod = @import("../terminal_core.zig");

pub const FeedResult = terminal_core_mod.TerminalCore.OutputFeedResult;

pub fn feedOutputBytesLocked(self: anytype, bytes: []const u8) FeedResult {
    return self.core.feedOutputBytesLocked(self, bytes);
}

pub fn feedOutputBytes(self: anytype, bytes: []const u8) void {
    self.session.control.state_mutex.lock();
    defer self.session.control.state_mutex.unlock();
    const result = feedOutputBytesLocked(self, bytes);
    var exec = @import("../session/protocol_execution.zig").ProtocolExecution.init(self, self.core);
    exec.consumeFeedResult(result, "feed_output_bytes");
}
