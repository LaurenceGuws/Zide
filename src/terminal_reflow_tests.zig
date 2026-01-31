const std = @import("std");
const term_mod = @import("terminal/core/terminal.zig");

test "terminal reflow merges wrapped scrollback rows" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "ABCDEFG\nHIJ\n");
    try session.resize(2, 8);

    const row = session.scrollbackRow(0) orelse return error.MissingScrollback;
    try std.testing.expectEqual(@as(usize, 8), row.len);
    try std.testing.expectEqual(@as(u32, 'A'), row[0].codepoint);
    try std.testing.expectEqual(@as(u32, 'B'), row[1].codepoint);
    try std.testing.expectEqual(@as(u32, 'C'), row[2].codepoint);
    try std.testing.expectEqual(@as(u32, 'D'), row[3].codepoint);
    try std.testing.expectEqual(@as(u32, 'E'), row[4].codepoint);
    try std.testing.expectEqual(@as(u32, 'F'), row[5].codepoint);
    try std.testing.expectEqual(@as(u32, 'G'), row[6].codepoint);
    try std.testing.expectEqual(@as(u32, 0), row[7].codepoint);
}
