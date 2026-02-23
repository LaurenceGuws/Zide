const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const terminal = @import("terminal/core/terminal.zig");
const pty_mod = @import("terminal/io/pty.zig");

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
