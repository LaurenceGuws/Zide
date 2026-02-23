const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const terminal = @import("terminal/core/terminal.zig");
const kitty = @import("terminal/kitty/graphics.zig");
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
            .pty = .{
                .master_fd = fds[1],
                .child_pid = null,
            },
        };
    }

    fn deinit(self: *PipeCapture) void {
        posix.close(self.read_fd);
        self.pty.deinit();
    }

    fn readReply(self: *PipeCapture, allocator: std.mem.Allocator) ![]u8 {
        var fds = [_]posix.pollfd{.{
            .fd = self.read_fd,
            .events = posix.POLL.IN,
            .revents = 0,
        }};
        const ready = try posix.poll(&fds, 50);
        if (ready <= 0 or (fds[0].revents & posix.POLL.IN) == 0) return error.NoReplyData;

        var buf: [256]u8 = undefined;
        const n = try posix.read(self.read_fd, &buf);
        return allocator.dupe(u8, buf[0..n]);
    }

    fn expectNoReply(self: *PipeCapture) !void {
        try std.testing.expectError(error.NoReplyData, self.readReply(std.testing.allocator));
    }
};

fn withSessionAndCapture(
    test_fn: fn (*terminal.TerminalSession, *PipeCapture) anyerror!void,
) !void {
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

test "kitty parse query metadata-only emits OK reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;OK\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query invalid png emits EBADPNG reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,f=100;AA==");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EBADPNG\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query rgba payload emits OK reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,f=32,s=1,v=1;AAAA/w==");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;OK\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query rgba short payload emits ENODATA reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,f=32,s=2,v=2;AAAA");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings(
                "\x1b_Gi=7;ENODATA:Insufficient image data: 3 < 16\x1b\\",
                reply,
            );
        }
    }.run);
}

test "kitty parse query quiet=1 suppresses success reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=1");
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query quiet=1 does not suppress error reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=1,f=100;AA==");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EBADPNG\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses error reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,f=100;AA==");
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query chunked form emits EINVAL" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,m=1;AAAA");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EINVAL\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query offset form emits EINVAL" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,O=1;AAAA");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EINVAL\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses success reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,f=32,s=1,v=1;AAAA/w==");
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query quiet=1 does not suppress ENODATA reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=1,f=32,s=2,v=2;AAAA");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings(
                "\x1b_Gi=7;ENODATA:Insufficient image data: 3 < 16\x1b\\",
                reply,
            );
        }
    }.run);
}

test "kitty parse query quiet=1 does not suppress EINVAL preflight reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=1,m=1;AAAA");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EINVAL\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses ENODATA reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,f=32,s=2,v=2;AAAA");
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses EINVAL preflight reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,m=1;AAAA");
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query rgb payload emits OK reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,f=24,s=1,v=1;AAAA");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;OK\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query rgb short payload emits ENODATA reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,f=24,s=2,v=1;AAAA");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings(
                "\x1b_Gi=7;ENODATA:Insufficient image data: 3 < 6\x1b\\",
                reply,
            );
        }
    }.run);
}
