const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub fn parseDcs(self: anytype, payload: []const u8) void {
    if (payload.len < 2) return;
    if (payload[0] == '+' and payload[1] == 'q') {
        handleXtgettcap(self, payload[2..]);
        return;
    }
    if (payload[0] == '$' and payload[1] == 'q') {
        handleDecrqss(self, payload[2..]);
        return;
    }
    _ = handleLegacySyncUpdates(self, payload);
}

pub fn parseApc(self: anytype, payload: []const u8) void {
    const log = app_logger.logger("terminal.apc");
    if (log.enabled_file or log.enabled_console) {
        const max_len: usize = 160;
        const slice = if (payload.len > max_len) payload[0..max_len] else payload;
        log.logf(.info, "apc payload len={d} prefix=\"{s}\"", .{ payload.len, slice });
    }
    if (payload.len == 0) return;
    if (payload[0] != 'G') return;
    self.parseKittyGraphics(payload[1..]);
}

fn handleXtgettcap(self: anytype, text: []const u8) void {
    if (self.pty == null) return;
    if (text.len == 0) {
        writeXtgettcapReply(self, false, "", null);
        return;
    }
    var it = std.mem.splitScalar(u8, text, ';');
    while (it.next()) |cap_hex| {
        if (cap_hex.len == 0) continue;
        replyXtgettcap(self, cap_hex);
    }
}

fn handleDecrqss(self: anytype, text: []const u8) void {
    if (self.pty == null) return;
    var buf: [128]u8 = undefined;
    const ok_reply = if (@hasDecl(@TypeOf(self.*), "decrqssReplyInto"))
        self.decrqssReplyInto(text, &buf)
    else if (@hasDecl(@TypeOf(self.*), "decrqssReply"))
        self.decrqssReply(text)
    else
        null;
    writeDecrqssReply(self, ok_reply != null, ok_reply);
}

fn replyXtgettcap(self: anytype, cap_hex: []const u8) void {
    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(self.allocator);
    if (!decodeHex(self.allocator, &decoded, cap_hex)) {
        writeXtgettcapReply(self, false, cap_hex, null);
        return;
    }

    const value = xtgettcapValue(decoded.items);
    if (value) |val| {
        writeXtgettcapReply(self, true, cap_hex, val);
    } else {
        writeXtgettcapReply(self, false, cap_hex, null);
    }
}

fn writeXtgettcapReply(self: anytype, ok: bool, cap_hex: []const u8, value: ?[]const u8) void {
    var reply = std.ArrayList(u8).empty;
    defer reply.deinit(self.allocator);

    const prefix = if (ok) "\x1bP1+r" else "\x1bP0+r";
    _ = reply.appendSlice(self.allocator, prefix) catch return;
    _ = reply.appendSlice(self.allocator, cap_hex) catch return;
    if (ok and value != null) {
        _ = reply.append(self.allocator, '=') catch return;
        if (!encodeHex(self.allocator, &reply, value.?)) return;
    }
    _ = reply.appendSlice(self.allocator, "\x1b\\") catch return;
    if (self.pty) |*pty_writer| {
        _ = pty_writer.write(reply.items) catch |err| blk: {
            app_logger.logger("terminal.apc").logf(.warning, "xtgettcap reply write failed len={d} err={s}", .{ reply.items.len, @errorName(err) });
            break :blk 0;
        };
    }
}

fn writeDecrqssReply(self: anytype, ok: bool, value: ?[]const u8) void {
    var reply = std.ArrayList(u8).empty;
    defer reply.deinit(self.allocator);

    _ = reply.appendSlice(self.allocator, if (ok) "\x1bP1$r" else "\x1bP0$r") catch return;
    if (ok) {
        if (value) |val| {
            _ = reply.appendSlice(self.allocator, val) catch return;
        }
    }
    _ = reply.appendSlice(self.allocator, "\x1b\\") catch return;
    if (self.pty) |*pty_writer| {
        _ = pty_writer.write(reply.items) catch |err| blk: {
            app_logger.logger("terminal.apc").logf(.warning, "decrqss reply write failed len={d} err={s}", .{ reply.items.len, @errorName(err) });
            break :blk 0;
        };
    }
}

fn xtgettcapValue(name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, name, "TN")) return "zide";
    if (std.mem.eql(u8, name, "Co") or std.mem.eql(u8, name, "colors")) return "256";
    if (std.mem.eql(u8, name, "RGB")) return "8";
    return null;
}

fn decodeHex(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) bool {
    out.clearRetainingCapacity();
    if (text.len % 2 != 0) return false;
    var i: usize = 0;
    while (i + 1 < text.len) : (i += 2) {
        const hi = hexNibble(text[i]) orelse return false;
        const lo = hexNibble(text[i + 1]) orelse return false;
        const value: u8 = @as(u8, (hi << 4) | lo);
        _ = out.append(allocator, value) catch return false;
    }
    return true;
}

fn encodeHex(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) bool {
    const hex = "0123456789ABCDEF";
    for (text) |b| {
        _ = out.append(allocator, hex[b >> 4]) catch return false;
        _ = out.append(allocator, hex[b & 0x0f]) catch return false;
    }
    return true;
}

fn hexNibble(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}

fn handleLegacySyncUpdates(self: anytype, payload: []const u8) bool {
    // Legacy synchronized update control:
    // DCS = 1 s ST -> enable
    // DCS = 2 s ST -> disable
    if (payload.len < 3) return false;
    if (payload[0] != '=' or payload[payload.len - 1] != 's') return false;
    const raw = std.mem.trim(u8, payload[1 .. payload.len - 1], " ;");
    if (raw.len == 0) return false;
    const mode = std.fmt.parseInt(u8, raw, 10) catch return false;
    switch (mode) {
        1 => self.setSyncUpdates(true),
        2 => self.setSyncUpdates(false),
        else => return false,
    }
    return true;
}
