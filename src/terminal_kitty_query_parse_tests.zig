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

fn expectKittyQuerySuppressedForQ2(base_seq: []const u8) !void {
    var seq_buf: [512]u8 = undefined;
    const seq = try std.fmt.bufPrint(&seq_buf, "a=q,i=7,q=2,{s}", .{base_seq});
    try expectKittyQueryNoReply(seq);
}

fn decodeBase64Alloc(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoded_len = try std.base64.standard.Decoder.calcSizeForSlice(encoded);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    _ = try std.base64.standard.Decoder.decode(out, encoded);
    return out;
}

fn encodeBase64Alloc(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const encoded_len = std.base64.standard.Encoder.calcSize(data.len);
    const out = try allocator.alloc(u8, encoded_len);
    _ = std.base64.standard.Encoder.encode(out, data);
    return out;
}

fn writeTempFileAbsolute(
    allocator: std.mem.Allocator,
    pattern_prefix: []const u8,
    content: []const u8,
) ![]u8 {
    var rand_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&rand_bytes);
    const rand_id = std.mem.readInt(u64, &rand_bytes, .little);
    const path = try std.fmt.allocPrint(
        allocator,
        "/tmp/{s}-{x}.bin",
        .{ pattern_prefix, rand_id },
    );
    errdefer allocator.free(path);
    var file = try std.fs.createFileAbsolute(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(content);
    return path;
}

fn createSharedMemoryObject(
    allocator: std.mem.Allocator,
    name_prefix: []const u8,
    content: []const u8,
) ![]u8 {
    if (!builtin.link_libc) return error.SkipZigTest;
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    var rand_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&rand_bytes);
    const rand_id = std.mem.readInt(u64, &rand_bytes, .little);
    const name = try std.fmt.allocPrint(allocator, "/{s}-{x}", .{ name_prefix, rand_id });
    errdefer allocator.free(name);

    const name_z = try allocator.allocSentinel(u8, name.len, 0);
    defer allocator.free(name_z);
    @memcpy(name_z[0..name.len], name);

    const create_flags: c_int = @bitCast(std.c.O{
        .ACCMODE = .RDWR,
        .CREAT = true,
        .EXCL = true,
    });
    const fd = std.c.shm_open(name_z.ptr, create_flags, 0o600);
    if (fd < 0) return error.ShmOpenFailed;
    defer _ = std.c.close(fd);
    errdefer _ = std.c.shm_unlink(name_z.ptr);

    if (std.c.ftruncate(fd, @intCast(content.len)) != 0) return error.ShmTruncateFailed;
    var written: usize = 0;
    while (written < content.len) {
        const n = posix.write(fd, content[written..]) catch return error.ShmWriteFailed;
        if (n == 0) return error.ShmWriteFailed;
        written += n;
    }
    return name;
}

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

test "kitty parse placement with P without Q replies EINVAL (policy lock)" {
    try withSessionAndCapture(struct {
        fn run(session: *terminal.TerminalSession, capture: *PipeCapture) !void {
            kitty.parseKittyGraphics(session, "a=t,q=2,f=100,i=1;" ++ tiny_png_1x1);
            kitty.parseKittyGraphics(session, "a=p,i=1,p=31,P=1,c=1,r=1");
            const reply = try capture.readReply(std.testing.allocator);
            defer std.testing.allocator.free(reply);
            try std.testing.expectEqualStrings("\x1b_Gi=1,p=31;EINVAL\x1b\\", reply);
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

test "kitty parse delete success replies are suppressed for q=0/q=1/q=2" {
    const cases = [_]struct {
        name: []const u8,
        seq: []const u8,
    }{
        .{ .name = "q0 delete success suppressed", .seq = "a=d,d=a" },
        .{ .name = "q1 delete success suppressed", .seq = "a=d,q=1,d=a" },
        .{ .name = "q2 delete success suppressed", .seq = "a=d,q=2,d=a" },
    };
    inline for (cases) |case_| {
        _ = case_.name;
        try expectKittyQueryNoReply(case_.seq);
    }
}

test "kitty parse delete invalid control still replies EINVAL for q=1" {
    try expectKittyQueryReply(
        "a=d,q=1,i=1,I=2,d=a",
        "\x1b_Gi=1,I=2;EINVAL\x1b\\",
    );
}

test "kitty parse delete invalid control reply is suppressed for q=2" {
    try expectKittyQueryNoReply("a=d,q=2,i=1,I=2,d=a");
}

test "kitty parse delete unknown selector replies EINVAL for q=0 and q=1" {
    const cases = [_]struct {
        seq: []const u8,
        expected: []const u8,
    }{
        .{ .seq = "a=d,i=1,d=v", .expected = "\x1b_Gi=1;EINVAL\x1b\\" },
        .{ .seq = "a=d,q=1,i=1,d=v", .expected = "\x1b_Gi=1;EINVAL\x1b\\" },
    };
    inline for (cases) |case_| {
        try expectKittyQueryReply(case_.seq, case_.expected);
    }
}

test "kitty parse delete unknown selector reply is suppressed for q=2" {
    try expectKittyQueryNoReply("a=d,q=2,i=1,d=v");
}

test "kitty parse delete deferred selectors q/Q/f/F reply EINVAL for q=0 and q=1" {
    const selectors = [_]u8{ 'q', 'Q', 'f', 'F' };
    inline for (selectors) |selector| {
        const seq_q0 = try std.fmt.allocPrint(std.testing.allocator, "a=d,i=1,d={c}", .{selector});
        defer std.testing.allocator.free(seq_q0);
        try expectKittyQueryReply(seq_q0, "\x1b_Gi=1;EINVAL\x1b\\");

        const seq_q1 = try std.fmt.allocPrint(std.testing.allocator, "a=d,q=1,i=1,d={c}", .{selector});
        defer std.testing.allocator.free(seq_q1);
        try expectKittyQueryReply(seq_q1, "\x1b_Gi=1;EINVAL\x1b\\");
    }
}

test "kitty parse delete deferred selectors q/Q/f/F reply is suppressed for q=2" {
    const selectors = [_]u8{ 'q', 'Q', 'f', 'F' };
    inline for (selectors) |selector| {
        const seq_q2 = try std.fmt.allocPrint(std.testing.allocator, "a=d,q=2,i=1,d={c}", .{selector});
        defer std.testing.allocator.free(seq_q2);
        try expectKittyQueryNoReply(seq_q2);
    }
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
    const no_reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
    }{
        .{ .name = "baseline invalid compression", .seq = "a=q,o=1,f=32,s=1,v=1;AAAA/w==" },
        .{ .name = "baseline invalid format", .seq = "a=q,f=999;AA==" },
        .{ .name = "baseline malformed payload", .seq = "a=q,f=32,s=1,v=1;%%%%" },
        .{ .name = "baseline chunked zlib preflight", .seq = "a=q,m=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1 },
        .{ .name = "baseline offset zlib preflight", .seq = "a=q,O=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1 },
        .{ .name = "baseline invalid offset plus invalid format plus malformed", .seq = "a=q,O=1,f=999;%%%%" },
        .{ .name = "q1 invalid compression", .seq = "a=q,q=1,o=1,f=32,s=1,v=1;AAAA/w==" },
        .{ .name = "q1 malformed payload", .seq = "a=q,q=1,f=32,s=1,v=1;%%%%" },
        .{ .name = "q1 chunked zlib preflight", .seq = "a=q,q=1,m=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1 },
        .{ .name = "q1 invalid compression plus invalid format", .seq = "a=q,q=1,o=1,f=999;AA==" },
        .{ .name = "q1 invalid offset plus invalid format", .seq = "a=q,q=1,O=1,f=999;AA==" },
        .{ .name = "q1 invalid offset plus malformed payload", .seq = "a=q,q=1,O=1,f=32,s=1,v=1;%%%%" },
        .{ .name = "q1 invalid offset plus invalid format plus malformed", .seq = "a=q,q=1,O=1,f=999;%%%%" },
        .{ .name = "q1 chunked zlib plus invalid format", .seq = "a=q,q=1,m=1,o=z,f=999;" ++ zlib_rgba_1x1 },
        .{ .name = "q1 chunked zlib plus invalid format plus malformed", .seq = "a=q,q=1,m=1,o=z,f=999;%%%%" },
        .{ .name = "q1 invalid compression plus invalid format plus malformed", .seq = "a=q,q=1,o=1,f=999;%%%%" },
        .{ .name = "q1 invalid offset plus invalid compression plus invalid format plus malformed", .seq = "a=q,q=1,O=1,o=1,f=999;%%%%" },
        .{ .name = "q1 chunked zlib plus invalid compression plus invalid format plus malformed", .seq = "a=q,q=1,m=1,o=1,f=999;%%%%" },
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

test "kitty parse query medium/path load-failure precedence matrix" {
    const reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
        expected: []const u8,
    }{
        .{ .name = "q1 medium=f malformed path base64 replies EINVAL", .seq = "a=q,i=7,q=1,t=f,f=999;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 medium=f missing file path replies EINVAL", .seq = "a=q,i=7,q=1,t=f,f=100;L3RtcC96aWRlLW1pc3Npbmcta2l0dHktcXVlcnkucG5n", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 medium=t disallowed temp path replies EINVAL", .seq = "a=q,i=7,q=1,t=t,f=100;L2hvbWUveA==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 medium=t missing protocol marker path replies EINVAL", .seq = "a=q,i=7,q=1,t=t,f=100;L3RtcC96aWRlLXBhdGgucG5n", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
    };
    inline for (reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryReply(case_.seq, case_.expected);
    }

    const q2_no_reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
    }{
        .{ .name = "q2 medium=f malformed path base64 suppressed", .seq = "t=f,f=999;%%%%" },
        .{ .name = "q2 medium=f missing file path suppressed", .seq = "t=f,f=100;L3RtcC96aWRlLW1pc3Npbmcta2l0dHktcXVlcnkucG5n" },
        .{ .name = "q2 medium=t disallowed temp path suppressed", .seq = "t=t,f=100;L2hvbWUveA==" },
        .{ .name = "q2 medium=t missing protocol marker path suppressed", .seq = "t=t,f=100;L3RtcC96aWRlLXBhdGgucG5n" },
    };
    inline for (q2_no_reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQuerySuppressedForQ2(case_.seq);
    }
}

test "kitty parse query medium file/temp success matrix" {
    const allocator = std.testing.allocator;
    const png_bytes = try decodeBase64Alloc(allocator, tiny_png_1x1);
    defer allocator.free(png_bytes);

    // medium=f: absolute file path, should load and decode PNG successfully.
    const file_path = try writeTempFileAbsolute(allocator, "zide-kitty-query-file", png_bytes);
    defer {
        std.fs.deleteFileAbsolute(file_path) catch {};
        allocator.free(file_path);
    }
    const file_path_b64 = try encodeBase64Alloc(allocator, file_path);
    defer allocator.free(file_path_b64);

    const seq_file_ok = try std.fmt.allocPrint(allocator, "a=q,i=7,t=f,f=100;{s}", .{file_path_b64});
    defer allocator.free(seq_file_ok);
    try expectKittyQueryReply(seq_file_ok, "\x1b_Gi=7;OK\x1b\\");

    const seq_file_q1 = try std.fmt.allocPrint(allocator, "a=q,i=7,q=1,t=f,f=100;{s}", .{file_path_b64});
    defer allocator.free(seq_file_q1);
    try expectKittyQueryNoReply(seq_file_q1);

    const seq_file_q2 = try std.fmt.allocPrint(allocator, "a=q,i=7,q=2,t=f,f=100;{s}", .{file_path_b64});
    defer allocator.free(seq_file_q2);
    try expectKittyQueryNoReply(seq_file_q2);

    // medium=t: temp-file path under /tmp with tty-graphics-protocol marker.
    const temp_path = try writeTempFileAbsolute(allocator, "zide-tty-graphics-protocol-query-temp", png_bytes);
    defer allocator.free(temp_path);
    const temp_path_b64 = try encodeBase64Alloc(allocator, temp_path);
    defer allocator.free(temp_path_b64);

    const seq_temp_ok = try std.fmt.allocPrint(allocator, "a=q,i=7,t=t,f=100;{s}", .{temp_path_b64});
    defer allocator.free(seq_temp_ok);
    try expectKittyQueryReply(seq_temp_ok, "\x1b_Gi=7;OK\x1b\\");

    // medium=t read path should remove temporary file after read.
    try std.testing.expectError(error.FileNotFound, std.fs.accessAbsolute(temp_path, .{}));

    const temp_path_q1 = try writeTempFileAbsolute(allocator, "zide-tty-graphics-protocol-query-temp-q1", png_bytes);
    defer allocator.free(temp_path_q1);
    const temp_path_q1_b64 = try encodeBase64Alloc(allocator, temp_path_q1);
    defer allocator.free(temp_path_q1_b64);
    const seq_temp_q1 = try std.fmt.allocPrint(allocator, "a=q,i=7,q=1,t=t,f=100;{s}", .{temp_path_q1_b64});
    defer allocator.free(seq_temp_q1);
    try expectKittyQueryNoReply(seq_temp_q1);
    try std.testing.expectError(error.FileNotFound, std.fs.accessAbsolute(temp_path_q1, .{}));

    const temp_path_q2 = try writeTempFileAbsolute(allocator, "zide-tty-graphics-protocol-query-temp-q2", png_bytes);
    defer allocator.free(temp_path_q2);
    const temp_path_q2_b64 = try encodeBase64Alloc(allocator, temp_path_q2);
    defer allocator.free(temp_path_q2_b64);
    const seq_temp_q2 = try std.fmt.allocPrint(allocator, "a=q,i=7,q=2,t=t,f=100;{s}", .{temp_path_q2_b64});
    defer allocator.free(seq_temp_q2);
    try expectKittyQueryNoReply(seq_temp_q2);
    try std.testing.expectError(error.FileNotFound, std.fs.accessAbsolute(temp_path_q2, .{}));
}

test "kitty parse query non-missing-id mixed chunk+offset precedence matrix" {
    const reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
        expected: []const u8,
    }{
        .{ .name = "q1 mixed m+O without compression", .seq = "a=q,i=7,q=1,m=1,O=1,f=32,s=1,v=1;AAAA/w==", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 mixed m+O with zlib", .seq = "a=q,i=7,q=1,m=1,O=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1, .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 mixed m+O beats invalid format + malformed", .seq = "a=q,i=7,q=1,m=1,O=1,f=999;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
        .{ .name = "q1 mixed m+O+z beats invalid format + malformed", .seq = "a=q,i=7,q=1,m=1,O=1,o=z,f=999;%%%%", .expected = "\x1b_Gi=7;EINVAL\x1b\\" },
    };
    inline for (reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryReply(case_.seq, case_.expected);
    }

    const no_reply_cases = [_]struct {
        name: []const u8,
        seq: []const u8,
    }{
        .{ .name = "q2 mixed m+O without compression", .seq = "a=q,i=7,q=2,m=1,O=1,f=32,s=1,v=1;AAAA/w==" },
        .{ .name = "q2 mixed m+O with zlib", .seq = "a=q,i=7,q=2,m=1,O=1,o=z,f=32,s=1,v=1;" ++ zlib_rgba_1x1 },
        .{ .name = "q2 mixed m+O beats invalid format + malformed", .seq = "a=q,i=7,q=2,m=1,O=1,f=999;%%%%" },
        .{ .name = "q2 mixed m+O+z beats invalid format + malformed", .seq = "a=q,i=7,q=2,m=1,O=1,o=z,f=999;%%%%" },
    };
    inline for (no_reply_cases) |case_| {
        _ = case_.name;
        try expectKittyQueryNoReply(case_.seq);
    }
}

test "kitty parse query medium shared-memory success matrix" {
    try requireUnix();
    if (!builtin.link_libc) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const png_bytes = try decodeBase64Alloc(allocator, tiny_png_1x1);
    defer allocator.free(png_bytes);

    // medium=s: shared-memory name with PNG bytes.
    const shm_name = try createSharedMemoryObject(allocator, "zide-kitty-query-shm", png_bytes);
    defer allocator.free(shm_name);
    const shm_name_b64 = try encodeBase64Alloc(allocator, shm_name);
    defer allocator.free(shm_name_b64);

    const seq_ok = try std.fmt.allocPrint(allocator, "a=q,i=7,t=s,f=100;{s}", .{shm_name_b64});
    defer allocator.free(seq_ok);
    try expectKittyQueryReply(seq_ok, "\x1b_Gi=7;OK\x1b\\");

    const shm_name_q1 = try createSharedMemoryObject(allocator, "zide-kitty-query-shm-q1", png_bytes);
    defer allocator.free(shm_name_q1);
    const shm_name_q1_b64 = try encodeBase64Alloc(allocator, shm_name_q1);
    defer allocator.free(shm_name_q1_b64);
    const seq_q1 = try std.fmt.allocPrint(allocator, "a=q,i=7,q=1,t=s,f=100;{s}", .{shm_name_q1_b64});
    defer allocator.free(seq_q1);
    try expectKittyQueryNoReply(seq_q1);

    const shm_name_q2 = try createSharedMemoryObject(allocator, "zide-kitty-query-shm-q2", png_bytes);
    defer allocator.free(shm_name_q2);
    const shm_name_q2_b64 = try encodeBase64Alloc(allocator, shm_name_q2);
    defer allocator.free(shm_name_q2_b64);
    const seq_q2 = try std.fmt.allocPrint(allocator, "a=q,i=7,q=2,t=s,f=100;{s}", .{shm_name_q2_b64});
    defer allocator.free(seq_q2);
    try expectKittyQueryNoReply(seq_q2);
}
