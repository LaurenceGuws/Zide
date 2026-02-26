const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const terminal = @import("terminal/core/terminal.zig");
const kitty = @import("terminal/kitty/graphics.zig");
const pty_mod = @import("terminal/io/pty.zig");

const tiny_png_1x1 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=";
const zlib_rgba_1x1 = "eJxjYGD4DwABAwEA";
const zlib_three_bytes = "eJxLTEoGAAJNASc=";
const zlib_png_1x1 = "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBAiS3yvAwASluTxfHkIo5yQkJQA4zA6M2p28LkMXg6ernss4poQkASQMLKg==";
const zlib_not_png = "eJzLyy8pyEsHAAkoApc=";

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

fn expectKittyQueryReply(seq: []const u8, expected_reply: []const u8) !void {
    try requireUnix();
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 6, 12);
    defer session.deinit();

    var capture = try PipeCapture.init();
    defer capture.deinit();

    session.pty = capture.pty;
    defer session.pty = null;

    kitty.parseKittyGraphics(session, seq);
    const reply = try capture.readReply(allocator);
    defer allocator.free(reply);
    try std.testing.expectEqualStrings(expected_reply, reply);
}

fn expectKittyQueryNoReply(seq: []const u8) !void {
    try requireUnix();
    const allocator = std.testing.allocator;
    var session = try terminal.TerminalSession.init(allocator, 6, 12);
    defer session.deinit();

    var capture = try PipeCapture.init();
    defer capture.deinit();

    session.pty = capture.pty;
    defer session.pty = null;

    kitty.parseKittyGraphics(session, seq);
    try capture.expectNoReply();
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

test "kitty parse query png payload emits OK reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,f=100;" ++ tiny_png_1x1);
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;OK\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses png success reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,f=100;" ++ tiny_png_1x1);
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query invalid format emits EINVAL reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,f=999;AAAA");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EINVAL\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses invalid format reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,f=999;AAAA");
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query rgba missing dimensions emits EINVAL reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,f=32;AAAA/w==");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EINVAL\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses missing-dimensions EINVAL reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,f=32;AAAA/w==");
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query malformed base64 emits EINVAL reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,f=32,s=1,v=1;!!!");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EINVAL\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses malformed base64 reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,f=32,s=1,v=1;!!!");
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query compressed rgba payload emits OK reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1);
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;OK\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query o=z with uncompressed rgba emits EINVAL" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,o=z,f=32,s=1,v=1;AAAA/w==");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EINVAL\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses compressed rgba success reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1);
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query quiet=1 does not suppress o=z decompression error" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=1,o=z,f=32,s=1,v=1;AAAA/w==");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EINVAL\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses o=z decompression error" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,o=z,f=32,s=1,v=1;AAAA/w==");
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query malformed zlib payload emits EINVAL" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,o=z,f=32,s=1,v=1;AQIDBA==");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EINVAL\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query post-inflate size mismatch emits ENODATA" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,o=z,f=32,s=1,v=1;" ++ zlib_three_bytes);
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings(
                "\x1b_Gi=7;ENODATA:Insufficient image data: 3 < 4\x1b\\",
                reply,
            );
        }
    }.run);
}

test "kitty parse query compressed png payload emits OK reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,o=z,f=100;" ++ zlib_png_1x1);
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;OK\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses compressed png success reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,o=z,f=100;" ++ zlib_png_1x1);
            try capture.expectNoReply();
        }
    }.run);
}

test "kitty parse query compressed invalid png emits EBADPNG reply" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,o=z,f=100;" ++ zlib_not_png);
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EBADPNG\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=1 does not suppress compressed png EBADPNG" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=1,o=z,f=100;" ++ zlib_not_png);
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=7;EBADPNG\x1b\\", reply);
        }
    }.run);
}

test "kitty parse query quiet=2 suppresses compressed png EBADPNG" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=q,i=7,q=2,o=z,f=100;" ++ zlib_not_png);
            try capture.expectNoReply();
        }
    }.run);
}

// Query precedence matrix coverage (current scope):
// - non-missing-id invalid compression (`o=1`)
// - missing-id preflight
// - non-missing-id zlib preflight (`m/O + o=z`)
test "kitty parse query invalid-compression precedence matrix" {
    const reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
        expected: []const u8,
    }{
        .{ .name = "baseline invalid compression emits EINVAL", .seq = "a=q,i=7,o=1,f=32,s=1,v=1;AAAA/w==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "invalid compression beats png decode", .seq = "a=q,i=7,o=1,f=100;AA==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "invalid compression beats rgba size check", .seq = "a=q,i=7,o=1,f=32,s=2,v=2;AAAA", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "invalid compression beats rgba missing dimensions", .seq = "a=q,i=7,o=1,f=32;AAAA/w==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "invalid compression beats invalid format", .seq = "a=q,i=7,o=1,f=999;AA==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "invalid compression beats malformed payload decode", .seq = "a=q,i=7,o=1,f=32,s=1,v=1;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 invalid compression still replies", .seq = "a=q,i=7,q=1,o=1,f=32,s=1,v=1;AAAA/w==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 invalid compression beats invalid format and malformed", .seq = "a=q,i=7,q=1,o=1,f=999;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 invalid compression beats png decode", .seq = "a=q,i=7,q=1,o=1,f=100;AA==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 invalid compression beats rgba size", .seq = "a=q,i=7,q=1,o=1,f=32,s=2,v=2;AAAA", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 invalid compression beats rgba missing dimensions", .seq = "a=q,i=7,q=1,o=1,f=32;AAAA/w==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
    };
    inline for (reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryReply(case_.seq, case_.expected);
    }

    const no_reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
    }{
        .{ .name = "q2 invalid compression", .seq = "a=q,i=7,q=2,o=1,f=32,s=1,v=1;AAAA/w==" },
        .{ .name = "q2 invalid compression beats invalid format", .seq = "a=q,i=7,q=2,o=1,f=999;AA==" },
        .{ .name = "q2 invalid compression beats malformed payload", .seq = "a=q,i=7,q=2,o=1,f=32,s=1,v=1;%%%%" },
        .{ .name = "q2 invalid compression beats invalid format and malformed", .seq = "a=q,i=7,q=2,o=1,f=999;%%%%" },
        .{ .name = "q2 invalid compression beats png decode", .seq = "a=q,i=7,q=2,o=1,f=100;AA==" },
        .{ .name = "q2 invalid compression beats rgba size", .seq = "a=q,i=7,q=2,o=1,f=32,s=2,v=2;AAAA" },
        .{ .name = "q2 invalid compression beats rgba missing dimensions", .seq = "a=q,i=7,q=2,o=1,f=32;AAAA/w==" },
    };
    inline for (no_reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryNoReply(case_.seq);
    }
}

test "kitty parse query missing-id precedence matrix" {
    const reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
        expected: []const u8,
    }{
        .{ .name = "baseline invalid compression", .seq = "a=q,o=1,f=32,s=1,v=1;AAAA/w==", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "baseline invalid format", .seq = "a=q,f=999;AA==", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "baseline malformed payload", .seq = "a=q,f=32,s=1,v=1;%%%%", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "baseline chunked zlib preflight", .seq = "a=q,m=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1, .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "baseline offset zlib preflight", .seq = "a=q,O=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1, .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "baseline invalid offset plus invalid format plus malformed", .seq = "a=q,O=1,f=999;%%%%", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 invalid compression", .seq = "a=q,q=1,o=1,f=32,s=1,v=1;AAAA/w==", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 malformed payload", .seq = "a=q,q=1,f=32,s=1,v=1;%%%%", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 chunked zlib preflight", .seq = "a=q,q=1,m=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1, .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 invalid compression plus invalid format", .seq = "a=q,q=1,o=1,f=999;AA==", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 invalid offset plus invalid format", .seq = "a=q,q=1,O=1,f=999;AA==", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 invalid offset plus malformed payload", .seq = "a=q,q=1,O=1,f=32,s=1,v=1;%%%%", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 invalid offset plus invalid format plus malformed", .seq = "a=q,q=1,O=1,f=999;%%%%", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 chunked zlib plus invalid format", .seq = "a=q,q=1,m=1,o=z,f=999;" ++ zlib_rgba_1x1, .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 chunked zlib plus invalid format plus malformed", .seq = "a=q,q=1,m=1,o=z,f=999;%%%%", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 invalid compression plus invalid format plus malformed", .seq = "a=q,q=1,o=1,f=999;%%%%", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 invalid offset plus invalid compression plus invalid format plus malformed", .seq = "a=q,q=1,O=1,o=1,f=999;%%%%", .expected = "\x1b_G;EINVAL\x1b\\" },
        .{ .name = "q1 chunked zlib plus invalid compression plus invalid format plus malformed", .seq = "a=q,q=1,m=1,o=1,f=999;%%%%", .expected = "\x1b_G;EINVAL\x1b\\" },
    };
    inline for (reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryReply(case_.seq, case_.expected);
    }

    const no_reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
    }{
        .{ .name = "q2 invalid format", .seq = "a=q,q=2,f=999;AA==" },
        .{ .name = "q2 malformed payload", .seq = "a=q,q=2,f=999;%%%%" },
        .{ .name = "q2 invalid compression plus invalid format", .seq = "a=q,q=2,o=1,f=999;AA==" },
        .{ .name = "q2 invalid compression plus malformed payload", .seq = "a=q,q=2,o=1,f=32,s=1,v=1;%%%%" },
        .{ .name = "q2 invalid compression plus invalid format plus malformed", .seq = "a=q,q=2,o=1,f=999;%%%%" },
        .{ .name = "q2 offset zlib preflight", .seq = "a=q,q=2,O=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1 },
        .{ .name = "q2 invalid offset plus invalid format", .seq = "a=q,q=2,O=1,f=999;AA==" },
        .{ .name = "q2 invalid offset plus malformed payload", .seq = "a=q,q=2,O=1,f=32,s=1,v=1;%%%%" },
        .{ .name = "q2 invalid offset plus invalid format plus malformed", .seq = "a=q,q=2,O=1,f=999;%%%%" },
        .{ .name = "q2 chunked zlib plus invalid format plus malformed", .seq = "a=q,q=2,m=1,o=z,f=999;%%%%" },
        .{ .name = "q2 invalid offset plus invalid compression plus invalid format plus malformed", .seq = "a=q,q=2,O=1,o=1,f=999;%%%%" },
        .{ .name = "q2 chunked plus invalid compression plus invalid format plus malformed", .seq = "a=q,q=2,m=1,o=1,f=999;%%%%" },
    };
    inline for (no_reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryNoReply(case_.seq);
    }
}

test "kitty parse query non-missing-id zlib preflight precedence matrix" {
    const reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
        expected: []const u8,
    }{
        .{ .name = "chunked zlib preflight", .seq = "a=q,i=7,m=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1, .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "offset zlib preflight", .seq = "a=q,i=7,O=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1, .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "chunked zlib beats invalid format", .seq = "a=q,i=7,m=1,o=z,f=999;" ++ zlib_rgba_1x1, .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "offset zlib beats invalid format", .seq = "a=q,i=7,O=1,o=z,f=999;" ++ zlib_rgba_1x1, .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "chunked zlib beats malformed payload", .seq = "a=q,i=7,m=1,o=z,f=32,s=1,v=1;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "offset zlib beats malformed payload", .seq = "a=q,i=7,O=1,o=z,f=32,s=1,v=1;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 chunked zlib preflight", .seq = "a=q,i=7,q=1,m=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1, .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 offset zlib preflight", .seq = "a=q,i=7,q=1,O=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1, .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 chunked zlib plus invalid format and malformed", .seq = "a=q,i=7,q=1,m=1,o=z,f=999;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 offset zlib plus invalid format and malformed", .seq = "a=q,i=7,q=1,O=1,o=z,f=999;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
    };
    inline for (reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryReply(case_.seq, case_.expected);
    }

    const no_reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
    }{
        .{ .name = "q2 chunked zlib preflight", .seq = "a=q,i=7,q=2,m=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1 },
        .{ .name = "q2 offset zlib preflight", .seq = "a=q,i=7,q=2,O=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1 },
        .{ .name = "q2 chunked zlib plus invalid format and malformed", .seq = "a=q,i=7,q=2,m=1,o=z,f=999;%%%%" },
        .{ .name = "q2 offset zlib plus invalid format and malformed", .seq = "a=q,i=7,q=2,O=1,o=z,f=999;%%%%" },
    };
    inline for (no_reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryNoReply(case_.seq);
    }
}

test "kitty parse query non-missing-id invalid-offset precedence matrix" {
    const reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
        expected: []const u8,
    }{
        .{ .name = "offset baseline emits EINVAL", .seq = "a=q,i=7,O=1,f=32,s=1,v=1;AAAA/w==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "offset beats invalid format", .seq = "a=q,i=7,O=1,f=999;AA==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "offset beats malformed payload", .seq = "a=q,i=7,O=1,f=32,s=1,v=1;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "offset beats invalid format plus malformed payload", .seq = "a=q,i=7,O=1,f=999;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 offset baseline emits EINVAL", .seq = "a=q,i=7,q=1,O=1,f=32,s=1,v=1;AAAA/w==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 offset beats invalid format and malformed payload", .seq = "a=q,i=7,q=1,O=1,f=999;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 offset+zlib preflight beats invalid format and malformed payload", .seq = "a=q,i=7,q=1,O=1,o=z,f=999;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
    };
    inline for (reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryReply(case_.seq, case_.expected);
    }

    const no_reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
    }{
        .{ .name = "q2 offset baseline", .seq = "a=q,i=7,q=2,O=1,f=32,s=1,v=1;AAAA/w==" },
        .{ .name = "q2 offset beats invalid format", .seq = "a=q,i=7,q=2,O=1,f=999;AA==" },
        .{ .name = "q2 offset beats malformed payload", .seq = "a=q,i=7,q=2,O=1,f=32,s=1,v=1;%%%%" },
        .{ .name = "q2 offset beats invalid format plus malformed payload", .seq = "a=q,i=7,q=2,O=1,f=999;%%%%" },
        .{ .name = "q2 offset+zlib preflight beats invalid format plus malformed payload", .seq = "a=q,i=7,q=2,O=1,o=z,f=999;%%%%" },
    };
    inline for (no_reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryNoReply(case_.seq);
    }
}
