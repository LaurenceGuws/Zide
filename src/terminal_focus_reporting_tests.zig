const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const terminal = @import("terminal/core/terminal.zig");
const pty_mod = @import("terminal/io/pty.zig");
const terminal_widget_mod = @import("ui/widgets/terminal_widget.zig");

fn requireUnix() !void {
    if (builtin.os.tag != .linux and builtin.os.tag != .macos) return error.SkipZigTest;
}

const PipeCapture = struct {
    read_fd: posix.fd_t,
    pty: pty_mod.Pty,

    fn init() !PipeCapture {
        try requireUnix();
        const fds = try posix.pipe();
        return .{
            .read_fd = fds[0],
            .pty = .{ .master_fd = fds[1], .child_pid = null },
        };
    }

    fn deinit(self: *PipeCapture) void {
        posix.close(self.read_fd);
        self.pty.deinit();
    }

    fn readReply(self: *PipeCapture, allocator: std.mem.Allocator) ![]u8 {
        var fds = [_]posix.pollfd{.{ .fd = self.read_fd, .events = posix.POLL.IN, .revents = 0 }};
        const ready = try posix.poll(&fds, 50);
        if (ready <= 0 or (fds[0].revents & posix.POLL.IN) == 0) return error.NoReplyData;
        var buf: [4096]u8 = undefined;
        const n = try posix.read(self.read_fd, &buf);
        return allocator.dupe(u8, buf[0..n]);
    }

    fn expectNoReply(self: *PipeCapture) !void {
        try std.testing.expectError(error.NoReplyData, self.readReply(std.testing.allocator));
    }
};

fn withSessionAndCapture(test_fn: fn (*terminal.TerminalSession, *PipeCapture) anyerror!void) !void {
    try requireUnix();
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 6, 12);
    defer session.deinit();

    var capture = try PipeCapture.init();
    defer capture.deinit();

    session.pty = capture.pty;
    defer session.pty = null;

    try test_fn(session, &capture);
}

test "terminal focus reporting toggles via CSI ?1004 h/l" {
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 6, 12);
    defer session.deinit();

    try std.testing.expect(!session.focusReportingEnabled());
    terminal.debugFeedBytes(session, "\x1b[?1004h");
    try std.testing.expect(session.focusReportingEnabled());
    terminal.debugFeedBytes(session, "\x1b[?1004l");
    try std.testing.expect(!session.focusReportingEnabled());
}

test "terminal focus reporting writes focus in/out when enabled" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?1004h");
            try std.testing.expect(try session.reportFocusChanged(true));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[I", reply);
            }

            try std.testing.expect(try session.reportFocusChanged(false));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[O", reply);
            }
        }
    }.run);
}

test "terminal focus reporting suppresses writes when disabled or cleared" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            try std.testing.expect(!(try session.reportFocusChanged(true)));
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?1004h");
            terminal.debugFeedBytes(session, "\x1b[?1004l");
            try std.testing.expect(!(try session.reportFocusChanged(true)));
            try capture.expectNoReply();
        }
    }.run);
}

test "terminal DECRQM private query reports ?1004 set/reset state" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            terminal.debugFeedBytes(session, "\x1b[?1004$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?1004;2$y", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[?1004h");
            terminal.debugFeedBytes(session, "\x1b[?1004$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?1004;1$y", reply);
            }
        }
    }.run);
}

test "terminal DECRQM private queries report common mode set/reset states" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            const Case = struct {
                mode: i32,
                set_seq: []const u8,
                reset_seq: []const u8,
                default_set: bool = false,
            };
            const cases = [_]Case{
                .{ .mode = 1, .set_seq = "\x1b[?1h", .reset_seq = "\x1b[?1l" },
                .{ .mode = 3, .set_seq = "\x1b[?3h", .reset_seq = "\x1b[?3l" },
                .{ .mode = 5, .set_seq = "\x1b[?5h", .reset_seq = "\x1b[?5l" },
                .{ .mode = 6, .set_seq = "\x1b[?6h", .reset_seq = "\x1b[?6l" },
                .{ .mode = 7, .set_seq = "\x1b[?7h", .reset_seq = "\x1b[?7l", .default_set = true },
                .{ .mode = 8, .set_seq = "\x1b[?8h", .reset_seq = "\x1b[?8l", .default_set = true },
                .{ .mode = 9, .set_seq = "\x1b[?9h", .reset_seq = "\x1b[?9l" },
                .{ .mode = 12, .set_seq = "\x1b[?12h", .reset_seq = "\x1b[?12l", .default_set = true },
                .{ .mode = 45, .set_seq = "\x1b[?45h", .reset_seq = "\x1b[?45l" },
                .{ .mode = 25, .set_seq = "\x1b[?25h", .reset_seq = "\x1b[?25l", .default_set = true },
                .{ .mode = 47, .set_seq = "\x1b[?47h", .reset_seq = "\x1b[?47l" },
                .{ .mode = 1047, .set_seq = "\x1b[?1047h", .reset_seq = "\x1b[?1047l" },
                .{ .mode = 1048, .set_seq = "\x1b[?1048h", .reset_seq = "\x1b[?1048l" },
                .{ .mode = 1049, .set_seq = "\x1b[?1049h", .reset_seq = "\x1b[?1049l" },
                .{ .mode = 1000, .set_seq = "\x1b[?1000h", .reset_seq = "\x1b[?1000l" },
                .{ .mode = 1002, .set_seq = "\x1b[?1002h", .reset_seq = "\x1b[?1002l" },
                .{ .mode = 1003, .set_seq = "\x1b[?1003h", .reset_seq = "\x1b[?1003l" },
                .{ .mode = 1006, .set_seq = "\x1b[?1006h", .reset_seq = "\x1b[?1006l" },
                .{ .mode = 1007, .set_seq = "\x1b[?1007h", .reset_seq = "\x1b[?1007l", .default_set = true },
                .{ .mode = 1016, .set_seq = "\x1b[?1016h", .reset_seq = "\x1b[?1016l" },
                .{ .mode = 2004, .set_seq = "\x1b[?2004h", .reset_seq = "\x1b[?2004l" },
                .{ .mode = 2026, .set_seq = "\x1b[?2026h", .reset_seq = "\x1b[?2026l" },
                .{ .mode = 2027, .set_seq = "\x1b[?2027h", .reset_seq = "\x1b[?2027l" },
                .{ .mode = 2031, .set_seq = "\x1b[?2031h", .reset_seq = "\x1b[?2031l" },
                .{ .mode = 2048, .set_seq = "\x1b[?2048h", .reset_seq = "\x1b[?2048l" },
                .{ .mode = 5522, .set_seq = "\x1b[?5522h", .reset_seq = "\x1b[?5522l" },
            };

            for (cases) |case| {
                var qbuf: [32]u8 = undefined;
                const query = try std.fmt.bufPrint(&qbuf, "\x1b[?{d}$p", .{case.mode});
                terminal.debugFeedBytes(session, query);
                {
                    const reply = try capture.readReply(allocator);
                    defer allocator.free(reply);
                    const default_state: u8 = if (case.default_set) 1 else 2;
                    const expected = try std.fmt.allocPrint(allocator, "\x1b[?{d};{d}$y", .{ case.mode, default_state });
                    defer allocator.free(expected);
                    try std.testing.expectEqualStrings(expected, reply);
                }

                terminal.debugFeedBytes(session, case.set_seq);
                terminal.debugFeedBytes(session, query);
                {
                    const reply = try capture.readReply(allocator);
                    defer allocator.free(reply);
                    const expected = try std.fmt.allocPrint(allocator, "\x1b[?{d};1$y", .{case.mode});
                    defer allocator.free(expected);
                    try std.testing.expectEqualStrings(expected, reply);
                }

                terminal.debugFeedBytes(session, case.reset_seq);
                terminal.debugFeedBytes(session, query);
                {
                    const reply = try capture.readReply(allocator);
                    defer allocator.free(reply);
                    const expected = try std.fmt.allocPrint(allocator, "\x1b[?{d};2$y", .{case.mode});
                    defer allocator.free(expected);
                    try std.testing.expectEqualStrings(expected, reply);
                }
            }
        }
    }.run);
}

test "terminal DECRQM private query reports keypad mode ?66 via DECPAM/DECPNM state" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            terminal.debugFeedBytes(session, "\x1b[?66$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?66;2$y", reply);
            }

            terminal.debugFeedBytes(session, "\x1b=");
            terminal.debugFeedBytes(session, "\x1b[?66$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?66;1$y", reply);
            }

            terminal.debugFeedBytes(session, "\x1b>");
            terminal.debugFeedBytes(session, "\x1b[?66$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?66;2$y", reply);
            }
        }
    }.run);
}

test "terminal DECRQM strategic fixed-off private modes report permanently reset (Pm=4)" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            const modes = [_]i32{ 67, 1001, 1005, 1015, 1034, 1035, 1036, 1042, 1070 };

            for (modes) |mode| {
                var qbuf: [32]u8 = undefined;
                const query = try std.fmt.bufPrint(&qbuf, "\x1b[?{d}$p", .{mode});
                terminal.debugFeedBytes(session, query);
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                const expected = try std.fmt.allocPrint(allocator, "\x1b[?{d};4$y", .{mode});
                defer allocator.free(expected);
                try std.testing.expectEqualStrings(expected, reply);
            }
        }
    }.run);
}

test "terminal DECRQM emits no Pm=3 replies in current policy scope" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            const queries = [_][]const u8{
                "\x1b[4$p",      // ANSI IRM
                "\x1b[12$p",     // ANSI local echo
                "\x1b[20$p",     // ANSI newline
                "\x1b[?1$p",     // DECCKM
                "\x1b[?7$p",     // DECAWM
                "\x1b[?8$p",     // DECARM
                "\x1b[?25$p",    // DECTCEM
                "\x1b[?45$p",    // reverse-wrap
                "\x1b[?66$p",    // keypad mode
                "\x1b[?1004$p",  // focus reporting
                "\x1b[?1016$p",  // SGR pixel mouse
                "\x1b[?2027$p",  // grapheme shaping mode
                "\x1b[?2031$p",  // color-scheme notify
                "\x1b[?2048$p",  // in-band resize notify
                "\x1b[?5522$p",  // kitty paste events
                "\x1b[?67$p",    // strategic fixed-off
                "\x1b[?1001$p",  // strategic fixed-off
            };

            for (queries) |query| {
                terminal.debugFeedBytes(session, query);
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expect(std.mem.indexOf(u8, reply, ";3$y") == null);
            }
        }
    }.run);
}

test "terminal DECRQM private query returns Pm=0 for unsupported mode" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?9999$p");
            const reply = try capture.readReply(allocator);
            defer allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b[?9999;0$y", reply);
        }
    }.run);
}

test "terminal reverse-wrap mode ?45 enables BS wrap to previous wrapped row" {
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    terminal.debugFeedBytes(session, "ABCDX");
    terminal.debugFeedBytes(session, "\r");

    terminal.debugFeedBytes(session, "\x08");
    {
        const snap = session.snapshot();
        try std.testing.expectEqual(@as(usize, 1), snap.cursor.row);
        try std.testing.expectEqual(@as(usize, 0), snap.cursor.col);
    }

    terminal.debugFeedBytes(session, "\x1b[?45h");
    terminal.debugFeedBytes(session, "\x08");
    {
        const snap = session.snapshot();
        try std.testing.expectEqual(@as(usize, 0), snap.cursor.row);
        try std.testing.expectEqual(@as(usize, 3), snap.cursor.col);
    }
}

test "terminal reverse-wrap mode ?45 enables CUB wrap to previous wrapped row" {
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    terminal.debugFeedBytes(session, "ABCDX");
    terminal.debugFeedBytes(session, "\x1b[2;1H");

    terminal.debugFeedBytes(session, "\x1b[D");
    {
        const snap = session.snapshot();
        try std.testing.expectEqual(@as(usize, 1), snap.cursor.row);
        try std.testing.expectEqual(@as(usize, 0), snap.cursor.col);
    }

    terminal.debugFeedBytes(session, "\x1b[?45h");
    terminal.debugFeedBytes(session, "\x1b[2D");
    {
        const snap = session.snapshot();
        try std.testing.expectEqual(@as(usize, 0), snap.cursor.row);
        try std.testing.expectEqual(@as(usize, 2), snap.cursor.col);
    }
}

test "terminal DECRQM private query returns Pm=4 only for strategic fixed-off unsupported modes" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            const modes = [_]i32{ 67, 1001, 1005, 1015, 1034, 1035, 1036, 1042, 1070 };

            for (modes) |mode| {
                var qbuf: [32]u8 = undefined;
                const query = try std.fmt.bufPrint(&qbuf, "\x1b[?{d}$p", .{mode});
                terminal.debugFeedBytes(session, query);
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                const expected = try std.fmt.allocPrint(allocator, "\x1b[?{d};4$y", .{mode});
                defer allocator.free(expected);
                try std.testing.expectEqualStrings(expected, reply);
            }
        }
    }.run);
}

test "terminal kitty paste events mode emits OSC 5522 mime list and serves text/plain/text/html/uri-list/image-png reads" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            terminal.debugFeedBytes(session, "\x1b[?5522h");
            try std.testing.expect(session.kittyPasteEvents5522Enabled());

            const png = [_]u8{ 0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n' };
            try std.testing.expect(try session.sendKittyPasteEvent5522WithMimeRich("hi", "<b>hi</b>", "file:///tmp/a\n", &png));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(
                    "\x1b]5522;type=read:status=OK\x1b\\" ++ "\x1b]5522;type=read:status=DATA:mime=Lg==;dGV4dC9wbGFpbgo=\x1b\\" ++ "\x1b]5522;type=read:status=DATA:mime=Lg==;dGV4dC9odG1sCg==\x1b\\" ++ "\x1b]5522;type=read:status=DATA:mime=Lg==;dGV4dC91cmktbGlzdAo=\x1b\\" ++ "\x1b]5522;type=read:status=DATA:mime=Lg==;aW1hZ2UvcG5nCg==\x1b\\" ++ "\x1b]5522;type=read:status=DONE\x1b\\",
                    reply,
                );
            }

            terminal.debugFeedBytes(session, "\x1b]5522;type=read;dGV4dC9wbGFpbg==\x1b\\");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(
                    "\x1b]5522;type=read:status=OK\x1b\\" ++ "\x1b]5522;type=read:status=DATA:mime=dGV4dC9wbGFpbg==;aGk=\x1b\\" ++ "\x1b]5522;type=read:status=DONE\x1b\\",
                    reply,
                );
            }

            terminal.debugFeedBytes(session, "\x1b]5522;type=read;dGV4dC9odG1s\x1b\\");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(
                    "\x1b]5522;type=read:status=OK\x1b\\" ++ "\x1b]5522;type=read:status=DATA:mime=dGV4dC9odG1s;PGI+aGk8L2I+\x1b\\" ++ "\x1b]5522;type=read:status=DONE\x1b\\",
                    reply,
                );
            }

            terminal.debugFeedBytes(session, "\x1b]5522;type=read;dGV4dC91cmktbGlzdA==\x1b\\");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(
                    "\x1b]5522;type=read:status=OK\x1b\\" ++ "\x1b]5522;type=read:status=DATA:mime=dGV4dC91cmktbGlzdA==;ZmlsZTovLy90bXAvYQo=\x1b\\" ++ "\x1b]5522;type=read:status=DONE\x1b\\",
                    reply,
                );
            }

            terminal.debugFeedBytes(session, "\x1b]5522;type=read;aW1hZ2UvcG5n\x1b\\");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(
                    "\x1b]5522;type=read:status=OK\x1b\\" ++ "\x1b]5522;type=read:status=DATA:mime=aW1hZ2UvcG5n;iVBORw0KGgo=\x1b\\" ++ "\x1b]5522;type=read:status=DONE\x1b\\",
                    reply,
                );
            }
        }
    }.run);
}

test "terminal kitty paste events mode supports image-only clipboard payloads" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            const png = [_]u8{ 0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n' };

            terminal.debugFeedBytes(session, "\x1b[?5522h");
            try std.testing.expect(try session.sendKittyPasteEvent5522WithMimeRich("", null, null, &png));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(
                    "\x1b]5522;type=read:status=OK\x1b\\" ++ "\x1b]5522;type=read:status=DATA:mime=Lg==;aW1hZ2UvcG5nCg==\x1b\\" ++ "\x1b]5522;type=read:status=DONE\x1b\\",
                    reply,
                );
            }
        }
    }.run);
}

test "terminal OSC 5522 read echoes sanitized id metadata" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?5522h");
            try std.testing.expect(try session.sendKittyPasteEvent5522("hi"));
            {
                const unsolicited = try capture.readReply(allocator);
                defer allocator.free(unsolicited);
            }

            // `!` is stripped; `+._-` are preserved.
            terminal.debugFeedBytes(session, "\x1b]5522;type=read:id=ab!c+._-9;dGV4dC9wbGFpbg==\x1b\\");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(
                    "\x1b]5522;type=read:status=OK:id=abc+._-9\x1b\\" ++ "\x1b]5522;type=read:status=DATA:mime=dGV4dC9wbGFpbg==:id=abc+._-9;aGk=\x1b\\" ++ "\x1b]5522;type=read:status=DONE:id=abc+._-9\x1b\\",
                    reply,
                );
            }
        }
    }.run);
}

test "terminal OSC 5522 read preserves BEL terminator" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?5522h");
            try std.testing.expect(try session.sendKittyPasteEvent5522("hi"));
            {
                const unsolicited = try capture.readReply(allocator);
                defer allocator.free(unsolicited);
            }

            terminal.debugFeedBytes(session, "\x1b]5522;type=read;dGV4dC9wbGFpbg==\x07");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(
                    "\x1b]5522;type=read:status=OK\x07" ++ "\x1b]5522;type=read:status=DATA:mime=dGV4dC9wbGFpbg==;aGk=\x07" ++ "\x1b]5522;type=read:status=DONE\x07",
                    reply,
                );
            }
        }
    }.run);
}

test "terminal OSC 5522 read returns ENOSYS for unsupported MIME request" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?5522h");
            try std.testing.expect(try session.sendKittyPasteEvent5522("hi"));
            {
                const unsolicited = try capture.readReply(allocator);
                defer allocator.free(unsolicited);
            }

            terminal.debugFeedBytes(session, "\x1b]5522;type=read;YXBwbGljYXRpb24vanNvbg==\x1b\\");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b]5522;type=read:status=ENOSYS\x1b\\", reply);
            }
        }
    }.run);
}

test "terminal OSC 5522 read returns ENOSYS for loc=primary" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?5522h");
            try std.testing.expect(try session.sendKittyPasteEvent5522("hi"));
            {
                const unsolicited = try capture.readReply(allocator);
                defer allocator.free(unsolicited);
            }

            terminal.debugFeedBytes(session, "\x1b]5522;type=read:loc=primary;dGV4dC9wbGFpbg==\x1b\\");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b]5522;type=read:status=ENOSYS\x1b\\", reply);
            }
        }
    }.run);
}

test "terminal OSC 5522 read returns EINVAL for malformed payload" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b]5522;type=read;%%%\x1b\\");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b]5522;type=read:status=EINVAL\x1b\\", reply);
            }
        }
    }.run);
}

test "terminal SGR pixel mouse mode ?1016 emits pixel coordinates when enabled" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?1000h\x1b[?1002h\x1b[?1006h");

            _ = try session.reportMouseEvent(.{
                .kind = .press,
                .button = .left,
                .row = 1,
                .col = 2,
                .pixel_x = 19,
                .pixel_y = 33,
                .mod = terminal.VTERM_MOD_NONE,
                .buttons_down = 1,
            });
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[<0;3;2M", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[?1016h");
            _ = try session.reportMouseEvent(.{
                .kind = .press,
                .button = .left,
                .row = 1,
                .col = 2,
                .pixel_x = 19,
                .pixel_y = 33,
                .mod = terminal.VTERM_MOD_NONE,
                .buttons_down = 1,
            });
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[<0;20;34M", reply);
            }

            _ = try session.reportMouseEvent(.{
                .kind = .move,
                .button = .none,
                .row = 2,
                .col = 3,
                .pixel_x = 27,
                .pixel_y = 49,
                .mod = terminal.VTERM_MOD_NONE,
                .buttons_down = 1,
            });
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[<32;28;50M", reply);
            }

            _ = try session.reportMouseEvent(.{
                .kind = .release,
                .button = .left,
                .row = 2,
                .col = 3,
                .pixel_x = 27,
                .pixel_y = 49,
                .mod = terminal.VTERM_MOD_NONE,
                .buttons_down = 0,
            });
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[<0;28;50m", reply);
            }

            const WheelCase = struct {
                button: terminal.MouseButton,
                mod: terminal.Modifier,
                expected: []const u8,
            };
            const wheel_cases = [_]WheelCase{
                .{ .button = .wheel_up, .mod = terminal.VTERM_MOD_SHIFT, .expected = "\x1b[<68;41;61M" },
                .{ .button = .wheel_down, .mod = terminal.VTERM_MOD_ALT, .expected = "\x1b[<73;41;61M" },
                .{ .button = .wheel_up, .mod = terminal.VTERM_MOD_CTRL, .expected = "\x1b[<80;41;61M" },
                .{ .button = .wheel_up, .mod = terminal.VTERM_MOD_SHIFT | terminal.VTERM_MOD_ALT, .expected = "\x1b[<76;41;61M" },
                .{ .button = .wheel_down, .mod = terminal.VTERM_MOD_SHIFT | terminal.VTERM_MOD_CTRL, .expected = "\x1b[<85;41;61M" },
            };
            for (wheel_cases) |case| {
                _ = try session.reportMouseEvent(.{
                    .kind = .wheel,
                    .button = case.button,
                    .row = 4,
                    .col = 5,
                    .pixel_x = 40,
                    .pixel_y = 60,
                    .mod = case.mod,
                    .buttons_down = 0,
                });
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(case.expected, reply);
            }

            // Lock wheel up/down ordering explicitly in pixel-SGR mode.
            _ = try session.reportMouseEvent(.{
                .kind = .wheel,
                .button = .wheel_down,
                .row = 4,
                .col = 5,
                .pixel_x = 40,
                .pixel_y = 60,
                .mod = terminal.VTERM_MOD_NONE,
                .buttons_down = 0,
            });
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[<65;41;61M", reply);
            }
            _ = try session.reportMouseEvent(.{
                .kind = .wheel,
                .button = .wheel_up,
                .row = 4,
                .col = 5,
                .pixel_x = 40,
                .pixel_y = 60,
                .mod = terminal.VTERM_MOD_NONE,
                .buttons_down = 0,
            });
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[<64;41;61M", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[?1006l");
            _ = try session.reportMouseEvent(.{
                .kind = .press,
                .button = .left,
                .row = 1,
                .col = 2,
                .pixel_x = 99,
                .pixel_y = 199,
                .mod = terminal.VTERM_MOD_NONE,
                .buttons_down = 1,
            });
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqual(@as(usize, 6), reply.len);
                try std.testing.expectEqual(@as(u8, 0x1b), reply[0]);
                try std.testing.expectEqual(@as(u8, '['), reply[1]);
                try std.testing.expectEqual(@as(u8, 'M'), reply[2]);
                try std.testing.expectEqual(@as(u8, 32), reply[3]);
                try std.testing.expectEqual(@as(u8, 35), reply[4]);
                try std.testing.expectEqual(@as(u8, 34), reply[5]);
            }
        }
    }.run);
}

test "terminal in-band resize notifications ?2048 emit CSI 48 t when enabled" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            session.setCellSize(8, 16);

            try session.resize(7, 13);
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?2048h");
            try session.resize(7, 13);
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[48;7;13;112;104t", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[?2048l");
            try session.resize(8, 14);
            try capture.expectNoReply();
        }
    }.run);
}

test "terminal in-band resize notifications ?2048 use zero pixel fallback when cell size unknown" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?2048h");
            try session.resize(6, 12);
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[48;6;12;0;0t", reply);
            }
        }
    }.run);
}

test "terminal color scheme notifications ?2031 reply to DSR ?996 and emit on change" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            terminal.debugFeedBytes(session, "\x1b[?996n");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?997;1n", reply);
            }

            try std.testing.expect(!(try session.reportColorSchemeChanged(false)));
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?2031h");
            try std.testing.expect(try session.reportColorSchemeChanged(false));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?997;2n", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[?996n");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?997;2n", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[?2031l");
            try std.testing.expect(!(try session.reportColorSchemeChanged(true)));
            try capture.expectNoReply();
        }
    }.run);
}

test "terminal legacy DCS sync updates toggles ?2026 mode state" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            terminal.debugFeedBytes(session, "\x1b[?2026$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?2026;2$y", reply);
            }

            terminal.debugFeedBytes(session, "\x1bP=1s\x1b\\");
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?2026$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?2026;1$y", reply);
            }

            terminal.debugFeedBytes(session, "\x1bP=2s\x1b\\");
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?2026$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?2026;2$y", reply);
            }

            // Unsupported legacy DCS value is ignored and does not emit a reply.
            terminal.debugFeedBytes(session, "\x1bP=3s\x1b\\");
            try capture.expectNoReply();
            terminal.debugFeedBytes(session, "\x1b[?2026$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?2026;2$y", reply);
            }
        }
    }.run);
}

test "terminal grapheme cluster mode ?2027 first slice is queryable no-op for text model" {
    const allocator = std.testing.allocator;

    var a = try terminal.TerminalSession.init(allocator, 6, 12);
    defer a.deinit();
    var b = try terminal.TerminalSession.init(allocator, 6, 12);
    defer b.deinit();

    // Representative multicodepoint sequence (emoji ZWJ family) should currently
    // behave the same in Zide regardless of ?2027 until shaping semantics are implemented.
    const seq = "\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7";

    terminal.debugFeedBytes(a, seq);
    terminal.debugFeedBytes(b, "\x1b[?2027h");
    terminal.debugFeedBytes(b, seq);

    try std.testing.expect(!a.grapheme_cluster_shaping_2027);
    try std.testing.expect(b.grapheme_cluster_shaping_2027);

    const posa = a.getCursorPos();
    const posb = b.getCursorPos();
    try std.testing.expectEqual(posa.row, posb.row);
    try std.testing.expectEqual(posa.col, posb.col);

    var row: usize = 0;
    while (row < 2) : (row += 1) {
        var col: usize = 0;
        while (col < 8) : (col += 1) {
            const ca = a.getCell(row, col);
            const cb = b.getCell(row, col);
            try std.testing.expectEqual(ca.codepoint, cb.codepoint);
            try std.testing.expectEqual(ca.width, cb.width);
            try std.testing.expectEqual(ca.combining_len, cb.combining_len);
        }
    }
}

test "terminal DECSTR restores default-set modes ?8 and ?1007" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?8l\x1b[?1007l");

            terminal.debugFeedBytes(session, "\x1b[?8$p\x1b[?1007$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?8;2$y\x1b[?1007;2$y", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[!p");
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?8$p\x1b[?1007$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?8;1$y\x1b[?1007;1$y", reply);
            }
        }
    }.run);
}

test "terminal DECSTR suppresses ?2031 and ?2048 live emissions after reset" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            session.setCellSize(8, 16);

            terminal.debugFeedBytes(session, "\x1b[?2031h\x1b[?2048h");

            try std.testing.expect(try session.reportColorSchemeChanged(false));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?997;2n", reply);
            }

            try session.resize(7, 13);
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[48;7;13;112;104t", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[!p");
            try capture.expectNoReply();

            try std.testing.expect(!(try session.reportColorSchemeChanged(true)));
            try capture.expectNoReply();

            try session.resize(8, 14);
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?2048h");
            try session.resize(9, 15);
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[48;9;15;144;120t", reply);
            }
        }
    }.run);
}

test "terminal DECSTR suppresses ?5522 unsolicited paste events until re-enabled" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            terminal.debugFeedBytes(session, "\x1b[?5522h");
            try std.testing.expect(session.kittyPasteEvents5522Enabled());
            try std.testing.expect(try session.sendKittyPasteEvent5522("hi"));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expect(std.mem.startsWith(u8, reply, "\x1b]5522;type=read:status=OK"));
            }

            terminal.debugFeedBytes(session, "\x1b[!p");
            try capture.expectNoReply();
            try std.testing.expect(!session.kittyPasteEvents5522Enabled());

            try std.testing.expect(!(try session.sendKittyPasteEvent5522("hi")));
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?5522h");
            try std.testing.expect(session.kittyPasteEvents5522Enabled());
            try std.testing.expect(try session.sendKittyPasteEvent5522("hi"));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expect(std.mem.startsWith(u8, reply, "\x1b]5522;type=read:status=OK"));
            }
        }
    }.run);
}

test "terminal DECARM ?8 disables repeat key output" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            try session.sendKeyAction(terminal.VTERM_KEY_UP, terminal.VTERM_MOD_NONE, .repeat);
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[A", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[?8l");
            try session.sendKeyAction(terminal.VTERM_KEY_UP, terminal.VTERM_MOD_NONE, .repeat);
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?8h");
            try session.sendKeyAction(terminal.VTERM_KEY_UP, terminal.VTERM_MOD_NONE, .repeat);
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[A", reply);
            }
        }
    }.run);
}

test "terminal alt-scroll ?1007 emits arrows in alt screen" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            try std.testing.expect(!(try session.reportAlternateScrollWheel(1, terminal.VTERM_MOD_NONE)));
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?1049h");
            try std.testing.expect(try session.reportAlternateScrollWheel(2, terminal.VTERM_MOD_NONE));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[A\x1b[A", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[?1007l");
            try std.testing.expect(!(try session.reportAlternateScrollWheel(-1, terminal.VTERM_MOD_NONE)));
            try capture.expectNoReply();

            terminal.debugFeedBytes(session, "\x1b[?1007h");
            try std.testing.expect(try session.reportAlternateScrollWheel(-1, terminal.VTERM_MOD_NONE));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[B", reply);
            }
        }
    }.run);
}

test "terminal DECRQM ansi queries report mode 4, 12 and 20 set/reset state" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            const Case = struct {
                mode: i32,
                set_seq: []const u8,
                reset_seq: []const u8,
                default_set: bool = false,
            };
            const cases = [_]Case{
                .{ .mode = 4, .set_seq = "\x1b[4h", .reset_seq = "\x1b[4l" },
                .{ .mode = 12, .set_seq = "\x1b[12h", .reset_seq = "\x1b[12l" },
                .{ .mode = 20, .set_seq = "\x1b[20h", .reset_seq = "\x1b[20l" },
            };

            for (cases) |case| {
                var qbuf: [32]u8 = undefined;
                const query = try std.fmt.bufPrint(&qbuf, "\x1b[{d}$p", .{case.mode});
                terminal.debugFeedBytes(session, query);
                {
                    const reply = try capture.readReply(allocator);
                    defer allocator.free(reply);
                    const default_state: u8 = if (case.default_set) 1 else 2;
                    const expected = try std.fmt.allocPrint(allocator, "\x1b[{d};{d}$y", .{ case.mode, default_state });
                    defer allocator.free(expected);
                    try std.testing.expectEqualStrings(expected, reply);
                }

                terminal.debugFeedBytes(session, case.set_seq);
                terminal.debugFeedBytes(session, query);
                {
                    const reply = try capture.readReply(allocator);
                    defer allocator.free(reply);
                    const expected = try std.fmt.allocPrint(allocator, "\x1b[{d};1$y", .{case.mode});
                    defer allocator.free(expected);
                    try std.testing.expectEqualStrings(expected, reply);
                }

                terminal.debugFeedBytes(session, case.reset_seq);
                terminal.debugFeedBytes(session, query);
                {
                    const reply = try capture.readReply(allocator);
                    defer allocator.free(reply);
                    const expected = try std.fmt.allocPrint(allocator, "\x1b[{d};2$y", .{case.mode});
                    defer allocator.free(expected);
                    try std.testing.expectEqualStrings(expected, reply);
                }
            }
        }
    }.run);
}

test "terminal DECRQM representative unsupported ANSI modes return Pm=0" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            const unsupported_modes = [_]i32{ 1, 2, 3, 5, 6, 10, 13, 14, 18, 19 };

            for (unsupported_modes) |mode| {
                var qbuf: [32]u8 = undefined;
                const query = try std.fmt.bufPrint(&qbuf, "\x1b[{d}$p", .{mode});
                terminal.debugFeedBytes(session, query);
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);

                const expected = try std.fmt.allocPrint(allocator, "\x1b[{d};0$y", .{mode});
                defer allocator.free(expected);
                try std.testing.expectEqualStrings(expected, reply);
            }
        }
    }.run);
}

test "terminal ANSI local echo mode 12 echoes chars only without PTY" {
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 3, 6);
    defer session.deinit();

    terminal.debugFeedBytes(session, "\x1b[12h");
    try session.sendChar('a', terminal.VTERM_MOD_NONE);
    {
        const snap = session.snapshot();
        try std.testing.expectEqual(@as(u32, 'a'), snap.cellAt(0, 0).codepoint);
        try std.testing.expectEqual(@as(usize, 1), snap.cursor.col);
    }

    terminal.debugFeedBytes(session, "\x1b[12l");
    try session.sendChar('b', terminal.VTERM_MOD_NONE);
    {
        const snap = session.snapshot();
        try std.testing.expectEqual(@as(u32, 0), snap.cellAt(0, 1).codepoint);
        try std.testing.expectEqual(@as(usize, 1), snap.cursor.col);
    }
}

test "terminal grapheme cluster mode ?2027 keeps shaping-priority combining mark on overflow" {
    const allocator = std.testing.allocator;
    var off = try terminal.TerminalSession.init(allocator, 3, 8);
    defer off.deinit();
    var on = try terminal.TerminalSession.init(allocator, 3, 8);
    defer on.deinit();

    // Turn mode on only for `on`.
    terminal.debugFeedBytes(on, "\x1b[?2027h");

    // Base + 3 combining marks (capacity is 2); VS16 is the shaping-priority mark.
    terminal.debugFeedBytes(off, "A\u{0301}\u{0300}\u{FE0F}");
    terminal.debugFeedBytes(on, "A\u{0301}\u{0300}\u{FE0F}");

    {
        const snap_off = off.snapshot();
        const cell_off = snap_off.cellAt(0, 0);
        try std.testing.expectEqual(@as(u8, 2), cell_off.combining_len);
        try std.testing.expectEqual(@as(u32, 0x0301), cell_off.combining[0]);
        try std.testing.expectEqual(@as(u32, 0x0300), cell_off.combining[1]);
    }

    {
        const snap_on = on.snapshot();
        const cell_on = snap_on.cellAt(0, 0);
        try std.testing.expectEqual(@as(u8, 2), cell_on.combining_len);
        try std.testing.expectEqual(@as(u32, 0x0301), cell_on.combining[0]);
        try std.testing.expectEqual(@as(u32, 0xFE0F), cell_on.combining[1]);
    }
}

test "terminal DECRQM ansi query returns Pm=0 for unsupported mode per xterm-foot convention" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[999$p");
            const reply = try capture.readReply(allocator);
            defer allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b[999;0$y", reply);
        }
    }.run);
}

test "terminal CSI !p does not trigger DECRQM reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            terminal.debugFeedBytes(session, "\x1b[!p");
            try capture.expectNoReply();
        }
    }.run);
}

test "terminal DECSTR soft reset clears mode subset and preserves grid" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            terminal.debugFeedBytes(session, "AB");
            terminal.debugFeedBytes(
                session,
                "\x1b[?1004h" ++ // focus reporting
                    "\x1b[?2004h" ++ // bracketed paste
                    "\x1b[?1002h" ++ // mouse button tracking
                    "\x1b[?1006h" ++ // SGR mouse
                    "\x1b[?1h" ++ // app cursor keys
                    "\x1b[?5h" ++ // reverse video
                    "\x1b[?6h" ++ // origin mode
                    "\x1b[?25l" ++ // cursor invisible
                    "\x1b=" ++ // app keypad
                    "\x1b[>13u" ++ // kitty key mode flags
                    "\x1b[3;5H" ++ // cursor move
                    "\x1b[2;4r", // scroll region
            );

            try std.testing.expect(session.focusReportingEnabled());
            try std.testing.expect(session.bracketedPasteEnabled());
            try std.testing.expect(session.mouseReportingEnabled());
            try std.testing.expect(session.app_cursor_keys);
            try std.testing.expect(session.app_keypad);
            try std.testing.expect(session.keyModeFlagsValue() != 0);

            terminal.debugFeedBytes(session, "\x1b[!p");
            try capture.expectNoReply();

            // Content is preserved (soft reset, not hard reset).
            try std.testing.expectEqual(@as(u32, 'A'), session.getCell(0, 0).codepoint);
            try std.testing.expectEqual(@as(u32, 'B'), session.getCell(0, 1).codepoint);

            // Key global/session modes reset to defaults.
            try std.testing.expect(!session.focusReportingEnabled());
            try std.testing.expect(!session.bracketedPasteEnabled());
            try std.testing.expect(!session.mouseReportingEnabled());
            try std.testing.expect(!session.app_cursor_keys);
            try std.testing.expect(!session.app_keypad);
            try std.testing.expectEqual(@as(u32, 0), session.keyModeFlagsValue());

            // Active-screen soft reset defaults restored.
            const pos = session.getCursorPos();
            try std.testing.expectEqual(@as(usize, 0), pos.row);
            try std.testing.expectEqual(@as(usize, 0), pos.col);

            const screen = session.activeScreen();
            try std.testing.expect(screen.cursor_visible);
            try std.testing.expect(!screen.screen_reverse);
            try std.testing.expect(!screen.origin_mode);
            try std.testing.expect(screen.auto_wrap);
            try std.testing.expectEqual(@as(usize, 0), screen.scroll_top);
            try std.testing.expectEqual(@as(usize, @intCast(screen.grid.rows - 1)), screen.scroll_bottom);
        }
    }.run);
}

test "terminal DECSTR resets DECRQM-queryable modes to defaults" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?1004h\x1b[?1002h\x1b[?1016h\x1b[?2004h\x1b[?2027h\x1b[?2031h\x1b[?2048h\x1b[?5522h\x1b[20h\x1b=");

            const Case = struct {
                query: []const u8,
                before_reply: []const u8,
                after_reply: []const u8,
            };
            const cases = [_]Case{
                .{ .query = "\x1b[?1004$p", .before_reply = "\x1b[?1004;1$y", .after_reply = "\x1b[?1004;2$y" },
                .{ .query = "\x1b[?1002$p", .before_reply = "\x1b[?1002;1$y", .after_reply = "\x1b[?1002;2$y" },
                .{ .query = "\x1b[?1016$p", .before_reply = "\x1b[?1016;1$y", .after_reply = "\x1b[?1016;2$y" },
                .{ .query = "\x1b[?2004$p", .before_reply = "\x1b[?2004;1$y", .after_reply = "\x1b[?2004;2$y" },
                .{ .query = "\x1b[?2027$p", .before_reply = "\x1b[?2027;1$y", .after_reply = "\x1b[?2027;2$y" },
                .{ .query = "\x1b[?2031$p", .before_reply = "\x1b[?2031;1$y", .after_reply = "\x1b[?2031;2$y" },
                .{ .query = "\x1b[?2048$p", .before_reply = "\x1b[?2048;1$y", .after_reply = "\x1b[?2048;2$y" },
                .{ .query = "\x1b[?5522$p", .before_reply = "\x1b[?5522;1$y", .after_reply = "\x1b[?5522;2$y" },
                .{ .query = "\x1b[20$p", .before_reply = "\x1b[20;1$y", .after_reply = "\x1b[20;2$y" },
                .{ .query = "\x1b[?66$p", .before_reply = "\x1b[?66;1$y", .after_reply = "\x1b[?66;2$y" },
            };

            for (cases) |case| {
                terminal.debugFeedBytes(session, case.query);
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(case.before_reply, reply);
            }

            terminal.debugFeedBytes(session, "\x1b[!p");
            try capture.expectNoReply(); // DECSTR itself

            for (cases) |case| {
                terminal.debugFeedBytes(session, case.query);
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings(case.after_reply, reply);
            }
        }
    }.run);
}

test "terminal DECSTR in alt screen preserves active screen selection and primary contents" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            terminal.debugFeedBytes(session, "P");
            terminal.debugFeedBytes(session, "\x1b[?1049h");
            terminal.debugFeedBytes(session, "A");
            terminal.debugFeedBytes(session, "\x1b[!p");
            try capture.expectNoReply();

            // Still in alt screen after DECSTR.
            terminal.debugFeedBytes(session, "\x1b[?1049$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[?1049;1$y", reply);
            }

            {
                const snap = session.snapshot();
                try std.testing.expect(snap.alt_active);
                try std.testing.expectEqual(@as(u32, 'A'), session.getCell(0, 0).codepoint);
            }

            terminal.debugFeedBytes(session, "\x1b[?1049l");

            {
                const snap = session.snapshot();
                try std.testing.expect(!snap.alt_active);
                try std.testing.expectEqual(@as(u32, 'P'), session.getCell(0, 0).codepoint);
            }
        }
    }.run);
}

test "terminal DECSTR invalidates saved cursor restore slot" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            terminal.debugFeedBytes(session, "\x1b[3;5H\x1b[s\x1b[1;1H\x1b[!p\x1b[u");
            try capture.expectNoReply();
            const pos = session.getCursorPos();
            try std.testing.expectEqual(@as(usize, 0), pos.row);
            try std.testing.expectEqual(@as(usize, 0), pos.col);
        }
    }.run);
}

test "terminal DECSTR resets parser charset and clears saved charset restore" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            terminal.debugFeedBytes(session, "\x1b(0"); // DEC special G0 active in GL by default
            terminal.debugFeedBytes(session, "j");
            const before = session.getCell(0, 0).codepoint;
            try std.testing.expect(before != @as(u32, 'j'));

            terminal.debugFeedBytes(session, "\x1b[s"); // save cursor + charset state
            terminal.debugFeedBytes(session, "\x1b(B"); // back to ASCII
            terminal.debugFeedBytes(session, "\x1b[!p"); // DECSTR clears saved charset + parser state
            try capture.expectNoReply();
            terminal.debugFeedBytes(session, "\x1b[u"); // should not restore saved charset/cursor after DECSTR
            terminal.debugFeedBytes(session, "j");

            try std.testing.expectEqual(@as(u32, 'j'), session.getCell(0, 0).codepoint);
            try std.testing.expectEqual(@as(usize, 1), session.getCursorPos().col);
        }
    }.run);
}

test "terminal DECSTR resets cursor style to default" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            terminal.debugFeedBytes(session, "\x1b[6 q"); // bar, steady
            {
                const snap = session.snapshot();
                try std.testing.expectEqual(.bar, snap.cursor_style.shape);
                try std.testing.expect(!snap.cursor_style.blink);
            }

            terminal.debugFeedBytes(session, "\x1b[!p");
            try capture.expectNoReply();

            {
                const snap = session.snapshot();
                try std.testing.expectEqual(.block, snap.cursor_style.shape);
                try std.testing.expect(snap.cursor_style.blink);
            }
        }
    }.run);
}

test "terminal DECSTR resets title to default" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            terminal.debugFeedBytes(session, "\x1b]2;custom title\x07");
            try std.testing.expectEqualStrings("custom title", terminal.debugSnapshot(session).title);

            terminal.debugFeedBytes(session, "\x1b[!p");
            try capture.expectNoReply();

            try std.testing.expectEqualStrings("Terminal", terminal.debugSnapshot(session).title);
        }
    }.run);
}

test "terminal DECSTR clears active-screen kitty state while alt screen remains active" {
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 6, 12);
    defer session.deinit();

    terminal.debugFeedBytes(session, "\x1b[?1047h");
    terminal.debugFeedBytes(
        session,
        "\x1b_Ga=t,f=100,i=1;iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=\x1b\\" ++
            "\x1b_Ga=p,i=1,c=2,r=1,x=1,y=1\x1b\\",
    );

    {
        const snap = session.snapshot();
        try std.testing.expect(snap.alt_active);
        try std.testing.expectEqual(@as(usize, 1), snap.kitty_images.len);
        try std.testing.expectEqual(@as(usize, 1), snap.kitty_placements.len);
    }

    terminal.debugFeedBytes(session, "\x1b[!p");

    {
        const snap = session.snapshot();
        try std.testing.expect(snap.alt_active);
        try std.testing.expectEqual(@as(usize, 0), snap.kitty_images.len);
        try std.testing.expectEqual(@as(usize, 0), snap.kitty_placements.len);
    }
}

test "terminal DECSTR alt-screen kitty placement does not leak to primary after exit" {
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 6, 12);
    defer session.deinit();

    terminal.debugFeedBytes(session, "P");
    terminal.debugFeedBytes(session, "\x1b[?1049h");
    terminal.debugFeedBytes(
        session,
        "\x1b_Ga=t,f=100,i=1;iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=\x1b\\" ++
            "\x1b_Ga=p,i=1,c=2,r=1,x=1,y=1\x1b\\",
    );
    terminal.debugFeedBytes(session, "\x1b[!p");

    {
        const snap = session.snapshot();
        try std.testing.expect(snap.alt_active);
        try std.testing.expectEqual(@as(usize, 0), snap.kitty_placements.len);
    }

    terminal.debugFeedBytes(session, "\x1b[?1047l");

    {
        const snap = session.snapshot();
        try std.testing.expect(!snap.alt_active);
        try std.testing.expectEqual(@as(usize, 0), snap.kitty_placements.len);
        try std.testing.expectEqual(@as(u32, 'P'), session.getCell(0, 0).codepoint);
    }
}

test "terminal DECSTR clears hidden primary kitty state while alt screen is active" {
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 6, 12);
    defer session.deinit();

    // Seed kitty state on primary.
    terminal.debugFeedBytes(
        session,
        "\x1b_Ga=t,f=100,i=1;iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=\x1b\\" ++
            "\x1b_Ga=p,i=1,c=2,r=1,x=1,y=1\x1b\\",
    );
    {
        const snap = session.snapshot();
        try std.testing.expect(!snap.alt_active);
        try std.testing.expectEqual(@as(usize, 1), snap.kitty_images.len);
        try std.testing.expectEqual(@as(usize, 1), snap.kitty_placements.len);
    }

    // Switch to alt, issue DECSTR (applies to both screens now), then return.
    terminal.debugFeedBytes(session, "\x1b[?1049h");
    terminal.debugFeedBytes(session, "\x1b[!p");
    terminal.debugFeedBytes(session, "\x1b[?1049l");

    {
        const snap = session.snapshot();
        try std.testing.expect(!snap.alt_active);
        try std.testing.expectEqual(@as(usize, 0), snap.kitty_images.len);
        try std.testing.expectEqual(@as(usize, 0), snap.kitty_placements.len);
    }
}

test "terminal DECSTR clears hidden alt kitty state while primary screen is active" {
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 6, 12);
    defer session.deinit();

    // Seed kitty state directly on hidden alt while primary is active.
    const rgba = try allocator.dupe(u8, &[_]u8{ 0xff, 0xff, 0xff, 0xff });
    try session.kitty_alt.images.append(allocator, .{
        .id = 1,
        .width = 1,
        .height = 1,
        .format = .rgba,
        .data = rgba,
        .version = 1,
    });
    try session.kitty_alt.placements.append(allocator, .{
        .image_id = 1,
        .placement_id = 0,
        .row = 0,
        .col = 0,
        .cols = 2,
        .rows = 1,
        .z = 0,
        .anchor_row = 0,
        .is_virtual = false,
        .parent_image_id = 0,
        .parent_placement_id = 0,
        .offset_x = 0,
        .offset_y = 0,
    });
    session.kitty_alt.total_bytes = rgba.len;

    try std.testing.expectEqual(@as(usize, 1), session.kitty_alt.images.items.len);
    try std.testing.expectEqual(@as(usize, 1), session.kitty_alt.placements.items.len);

    // DECSTR on primary now clears both active + hidden kitty states.
    terminal.debugFeedBytes(session, "\x1b[!p");
    try std.testing.expectEqual(@as(usize, 0), session.kitty_primary.images.items.len);
    try std.testing.expectEqual(@as(usize, 0), session.kitty_primary.placements.items.len);
    try std.testing.expectEqual(@as(usize, 0), session.kitty_alt.images.items.len);
    try std.testing.expectEqual(@as(usize, 0), session.kitty_alt.placements.items.len);

    // Re-enter alt to prove hidden-alt state was really cleared.
    terminal.debugFeedBytes(session, "\x1b[?1047h");
    {
        const snap = session.snapshot();
        try std.testing.expect(snap.alt_active);
        try std.testing.expectEqual(@as(usize, 0), snap.kitty_images.len);
        try std.testing.expectEqual(@as(usize, 0), snap.kitty_placements.len);
    }
}

test "terminal CSI ?1004p without $ intermediate does not trigger DECRQM reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            terminal.debugFeedBytes(session, "\x1b[?1004p");
            try capture.expectNoReply();
        }
    }.run);
}

test "terminal CSI #p does not trigger DECRQM reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            terminal.debugFeedBytes(session, "\x1b[#p");
            try capture.expectNoReply();
        }
    }.run);
}

test "terminal CSI malformed p-family intermediates do not trigger DECRQM or DECSTR" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const cases = [_][]const u8{
                "\x1b[?1004$!p", // malformed mixed DECRQM+DECSTR intermediates
                "\x1b[20!$p",    // malformed ansi mixed-intermediate form
                "\x1b[##p",      // unsupported repeated intermediate
                "\x1b[?!p",      // private+intermediate without DECRQM form
            };

            for (cases) |seq| {
                terminal.debugFeedBytes(session, seq);
                try capture.expectNoReply();
            }
        }
    }.run);
}

test "terminal CSI 18 t reports text area size in chars" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            terminal.debugFeedBytes(session, "\x1b[18t");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[8;6;12t", reply);
            }

            // Unsupported window-op mode: no reply.
            terminal.debugFeedBytes(session, "\x1b[99t");
            try capture.expectNoReply();
        }
    }.run);
}

test "terminal widget focus source toggles gate window and pane reports" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?1004h");

            var widget = terminal_widget_mod.TerminalWidget.init(session, .kitty);
            widget.setFocusReportSources(true, false);

            try std.testing.expect(try widget.reportFocusChangedFrom(.window, true));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[I", reply);
            }

            try std.testing.expect(!(try widget.reportFocusChangedFrom(.pane, false)));
            try capture.expectNoReply();
        }
    }.run);
}

test "terminal widget focus source dedupe suppresses duplicate state across sources" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            terminal.debugFeedBytes(session, "\x1b[?1004h");

            var widget = terminal_widget_mod.TerminalWidget.init(session, .kitty);
            widget.setFocusReportSources(true, true);

            try std.testing.expect(try widget.reportFocusChangedFrom(.window, true));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[I", reply);
            }

            try std.testing.expect(!(try widget.reportFocusChangedFrom(.pane, true)));
            try capture.expectNoReply();

            try std.testing.expect(try widget.reportFocusChangedFrom(.pane, false));
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[O", reply);
            }
        }
    }.run);
}
