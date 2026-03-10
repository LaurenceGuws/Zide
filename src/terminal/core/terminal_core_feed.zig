const parser_mod = @import("../parser/parser.zig");

pub const FeedResult = struct {
    parsed: bool,
    scroll_offset: usize,
};

pub fn feedOutputBytesLocked(self: anytype, bytes: []const u8) FeedResult {
    if (bytes.len == 0) return .{ .parsed = false, .scroll_offset = self.core.history.scrollOffset() };
    self.core.parser.handleSlice(parser_mod.Parser.SessionFacade.from(self), bytes);
    return .{
        .parsed = true,
        .scroll_offset = self.core.history.scrollOffset(),
    };
}
