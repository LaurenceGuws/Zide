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
        var buf: [64]u8 = undefined;
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
                .{ .mode = 25, .set_seq = "\x1b[?25h", .reset_seq = "\x1b[?25l", .default_set = true },
                .{ .mode = 47, .set_seq = "\x1b[?47h", .reset_seq = "\x1b[?47l" },
                .{ .mode = 1047, .set_seq = "\x1b[?1047h", .reset_seq = "\x1b[?1047l" },
                .{ .mode = 1049, .set_seq = "\x1b[?1049h", .reset_seq = "\x1b[?1049l" },
                .{ .mode = 1000, .set_seq = "\x1b[?1000h", .reset_seq = "\x1b[?1000l" },
                .{ .mode = 1002, .set_seq = "\x1b[?1002h", .reset_seq = "\x1b[?1002l" },
                .{ .mode = 1003, .set_seq = "\x1b[?1003h", .reset_seq = "\x1b[?1003l" },
                .{ .mode = 1006, .set_seq = "\x1b[?1006h", .reset_seq = "\x1b[?1006l" },
                .{ .mode = 2004, .set_seq = "\x1b[?2004h", .reset_seq = "\x1b[?2004l" },
                .{ .mode = 2026, .set_seq = "\x1b[?2026h", .reset_seq = "\x1b[?2026l" },
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

test "terminal DECRQM private query returns Pm=4 for permanently-reset unsupported modes" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            const modes = [_]i32{ 9, 45, 67, 1001, 1005, 1015, 1016, 1034, 1035, 1036, 1042 };

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

test "terminal DECRQM ansi query reports mode 20 newline set/reset state" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;

            terminal.debugFeedBytes(session, "\x1b[20$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[20;2$y", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[20h");
            terminal.debugFeedBytes(session, "\x1b[20$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[20;1$y", reply);
            }

            terminal.debugFeedBytes(session, "\x1b[20l");
            terminal.debugFeedBytes(session, "\x1b[20$p");
            {
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                try std.testing.expectEqualStrings("\x1b[20;2$y", reply);
            }
        }
    }.run);
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
