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

test "terminal DECRQM private query returns Pm=0 for provisional unsupported modes still on support path" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            const allocator = std.testing.allocator;
            const modes = [_]i32{ 9, 45, 1016, 2031, 2048, 5522 };

            for (modes) |mode| {
                var qbuf: [32]u8 = undefined;
                const query = try std.fmt.bufPrint(&qbuf, "\x1b[?{d}$p", .{mode});
                terminal.debugFeedBytes(session, query);
                const reply = try capture.readReply(allocator);
                defer allocator.free(reply);
                const expected = try std.fmt.allocPrint(allocator, "\x1b[?{d};0$y", .{mode});
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
            terminal.debugFeedBytes(session, "\x1b[?1004h\x1b[?1002h\x1b[?2004h\x1b[20h\x1b=");

            const Case = struct {
                query: []const u8,
                before_reply: []const u8,
                after_reply: []const u8,
            };
            const cases = [_]Case{
                .{ .query = "\x1b[?1004$p", .before_reply = "\x1b[?1004;1$y", .after_reply = "\x1b[?1004;2$y" },
                .{ .query = "\x1b[?1002$p", .before_reply = "\x1b[?1002;1$y", .after_reply = "\x1b[?1002;2$y" },
                .{ .query = "\x1b[?2004$p", .before_reply = "\x1b[?2004;1$y", .after_reply = "\x1b[?2004;2$y" },
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
