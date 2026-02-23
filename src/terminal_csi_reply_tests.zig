const std = @import("std");
const csi = @import("terminal/protocol/csi.zig");

const FakePty = struct {
    writes: std.ArrayList(u8),

    fn init() FakePty {
        return .{ .writes = .empty };
    }

    fn deinit(self: *FakePty) void {
        self.writes.deinit(std.testing.allocator);
    }

    pub fn write(self: *FakePty, bytes: []const u8) !usize {
        try self.writes.appendSlice(std.testing.allocator, bytes);
        return bytes.len;
    }
};

test "CSI DA primary reply bytes" {
    var pty = FakePty.init();
    defer pty.deinit();
    try std.testing.expect(csi.writeDaPrimaryReply(&pty));
    try std.testing.expectEqualStrings("\x1b[?62;1;2;4;6;7;8;9;15;18;21;22;28;29c", pty.writes.items);
}

test "CSI DSR CPR reply bytes" {
    var pty = FakePty.init();
    defer pty.deinit();
    try std.testing.expect(csi.writeDsrReply(&pty, 0, 6, 12, 34));
    try std.testing.expectEqualStrings("\x1b[12;34R", pty.writes.items);
}

test "CSI DSR status reply bytes" {
    var pty = FakePty.init();
    defer pty.deinit();
    try std.testing.expect(csi.writeDsrReply(&pty, 0, 5, 0, 0));
    try std.testing.expectEqualStrings("\x1b[0n", pty.writes.items);
}

test "CSI DEC private DSR cursor reply bytes" {
    var pty = FakePty.init();
    defer pty.deinit();
    try std.testing.expect(csi.writeDsrReply(&pty, '?', 6, 7, 9));
    try std.testing.expectEqualStrings("\x1b[?7;9R", pty.writes.items);
}

test "CSI DEC private DSR keyboard status reply bytes" {
    var pty = FakePty.init();
    defer pty.deinit();
    try std.testing.expect(csi.writeDsrReply(&pty, '?', 26, 0, 0));
    try std.testing.expectEqualStrings("\x1b[?27;1;0;0n", pty.writes.items);
}

test "CSI DSR unsupported mode returns false and writes nothing" {
    var pty = FakePty.init();
    defer pty.deinit();
    try std.testing.expect(!csi.writeDsrReply(&pty, 0, 999, 0, 0));
    try std.testing.expectEqual(@as(usize, 0), pty.writes.items.len);
}

test "CSI DECRQM private reply bytes" {
    var pty = FakePty.init();
    defer pty.deinit();
    try std.testing.expect(csi.writeDecrqmReply(&pty, true, 1004, .set));
    try std.testing.expectEqualStrings("\x1b[?1004;1$y", pty.writes.items);
}

test "CSI DECRQM ansi reply bytes" {
    var pty = FakePty.init();
    defer pty.deinit();
    try std.testing.expect(csi.writeDecrqmReply(&pty, false, 20, .reset));
    try std.testing.expectEqualStrings("\x1b[20;2$y", pty.writes.items);
}
