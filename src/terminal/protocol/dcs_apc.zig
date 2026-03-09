const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const kitty_mod = @import("../kitty/graphics.zig");

pub const SessionFacade = struct {
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
    write_pty_bytes_fn: *const fn (ctx: *anyopaque, bytes: []const u8) anyerror!void,
    parse_kitty_graphics_fn: *const fn (ctx: *anyopaque, payload: []const u8) void,
    decrqss_reply_into_fn: *const fn (ctx: *anyopaque, text: []const u8, buf: []u8) ?[]const u8,
    set_sync_updates_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .allocator = session.allocator,
            .write_pty_bytes_fn = struct {
                fn call(ctx: *anyopaque, bytes: []const u8) anyerror!void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    try s.writePtyBytes(bytes);
                }
            }.call,
            .parse_kitty_graphics_fn = struct {
                fn call(ctx: *anyopaque, payload: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    kitty_mod.parseKittyGraphics(s, payload);
                }
            }.call,
            .decrqss_reply_into_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8, buf: []u8) ?[]const u8 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.decrqssReplyInto(text, buf);
                }
            }.call,
            .set_sync_updates_locked_fn = struct {
                fn call(ctx: *anyopaque, enabled: bool) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setSyncUpdatesLocked(enabled);
                }
            }.call,
        };
    }

    pub fn writePtyBytes(self: *const SessionFacade, bytes: []const u8) !void {
        try self.write_pty_bytes_fn(self.ctx, bytes);
    }

    pub fn parseKittyGraphics(self: *const SessionFacade, payload: []const u8) void {
        self.parse_kitty_graphics_fn(self.ctx, payload);
    }

    pub fn decrqssReplyInto(self: *const SessionFacade, text: []const u8, buf: []u8) ?[]const u8 {
        return self.decrqss_reply_into_fn(self.ctx, text, buf);
    }

    pub fn setSyncUpdatesLocked(self: *const SessionFacade, enabled: bool) void {
        self.set_sync_updates_locked_fn(self.ctx, enabled);
    }
};

pub fn parseDcs(session: SessionFacade, payload: []const u8) void {
    if (payload.len < 2) return;
    if (payload[0] == '+' and payload[1] == 'q') {
        handleXtgettcap(&session, payload[2..]);
        return;
    }
    if (payload[0] == '$' and payload[1] == 'q') {
        handleDecrqss(&session, payload[2..]);
        return;
    }
    _ = handleLegacySyncUpdates(&session, payload);
}

pub fn parseApc(session: SessionFacade, payload: []const u8) void {
    const log = app_logger.logger("terminal.apc");
    const max_len: usize = 160;
    const slice = if (payload.len > max_len) payload[0..max_len] else payload;
    log.logf(.debug, "apc payload len={d} prefix=\"{s}\"", .{ payload.len, slice });
    if (payload.len == 0) return;
    if (payload[0] != 'G') return;
    session.parseKittyGraphics(payload[1..]);
}

fn handleXtgettcap(session: *const SessionFacade, text: []const u8) void {
    if (text.len == 0) {
        writeXtgettcapReply(session, false, "", null);
        return;
    }
    var it = std.mem.splitScalar(u8, text, ';');
    while (it.next()) |cap_hex| {
        if (cap_hex.len == 0) continue;
        replyXtgettcap(session, cap_hex);
    }
}

fn handleDecrqss(session: *const SessionFacade, text: []const u8) void {
    var buf: [128]u8 = undefined;
    const ok_reply = session.decrqssReplyInto(text, &buf);
    writeDecrqssReply(session, ok_reply != null, ok_reply);
}

fn replyXtgettcap(session: *const SessionFacade, cap_hex: []const u8) void {
    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(session.allocator);
    if (!decodeHex(session.allocator, &decoded, cap_hex)) {
        writeXtgettcapReply(session, false, cap_hex, null);
        return;
    }

    const value = xtgettcapValue(decoded.items);
    if (value) |val| {
        writeXtgettcapReply(session, true, cap_hex, val);
    } else {
        writeXtgettcapReply(session, false, cap_hex, null);
    }
}

fn writeXtgettcapReply(session: *const SessionFacade, ok: bool, cap_hex: []const u8, value: ?[]const u8) void {
    const log = app_logger.logger("terminal.apc");
    var reply = std.ArrayList(u8).empty;
    defer reply.deinit(session.allocator);

    const prefix = if (ok) "\x1bP1+r" else "\x1bP0+r";
    _ = reply.appendSlice(session.allocator, prefix) catch |err| {
        log.logf(.warning, "xtgettcap reply prefix append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = reply.appendSlice(session.allocator, cap_hex) catch |err| {
        log.logf(.warning, "xtgettcap reply cap append failed: {s}", .{@errorName(err)});
        return;
    };
    if (ok and value != null) {
        _ = reply.append(session.allocator, '=') catch |err| {
            log.logf(.warning, "xtgettcap reply separator append failed: {s}", .{@errorName(err)});
            return;
        };
        if (!encodeHex(session.allocator, &reply, value.?)) return;
    }
    _ = reply.appendSlice(session.allocator, "\x1b\\") catch |err| {
        log.logf(.warning, "xtgettcap reply terminator append failed: {s}", .{@errorName(err)});
        return;
    };
    session.writePtyBytes(reply.items) catch |err| {
        log.logf(.warning, "xtgettcap reply write failed len={d} err={s}", .{ reply.items.len, @errorName(err) });
        return;
    };
}

fn writeDecrqssReply(session: *const SessionFacade, ok: bool, value: ?[]const u8) void {
    const log = app_logger.logger("terminal.apc");
    var reply = std.ArrayList(u8).empty;
    defer reply.deinit(session.allocator);

    _ = reply.appendSlice(session.allocator, if (ok) "\x1bP1$r" else "\x1bP0$r") catch |err| {
        log.logf(.warning, "decrqss reply prefix append failed: {s}", .{@errorName(err)});
        return;
    };
    if (ok) {
        if (value) |val| {
            _ = reply.appendSlice(session.allocator, val) catch |err| {
                log.logf(.warning, "decrqss reply value append failed: {s}", .{@errorName(err)});
                return;
            };
        }
    }
    _ = reply.appendSlice(session.allocator, "\x1b\\") catch |err| {
        log.logf(.warning, "decrqss reply terminator append failed: {s}", .{@errorName(err)});
        return;
    };
    session.writePtyBytes(reply.items) catch |err| {
        log.logf(.warning, "decrqss reply write failed len={d} err={s}", .{ reply.items.len, @errorName(err) });
        return;
    };
}

fn xtgettcapValue(name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, name, "TN")) return "zide";
    if (std.mem.eql(u8, name, "Co") or std.mem.eql(u8, name, "colors")) return "256";
    if (std.mem.eql(u8, name, "RGB")) return "8";
    return null;
}

fn decodeHex(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) bool {
    const log = app_logger.logger("terminal.apc");
    out.clearRetainingCapacity();
    if (text.len % 2 != 0) return false;
    var i: usize = 0;
    while (i + 1 < text.len) : (i += 2) {
        const hi = hexNibble(text[i]) orelse return false;
        const lo = hexNibble(text[i + 1]) orelse return false;
        const value: u8 = @as(u8, (hi << 4) | lo);
        _ = out.append(allocator, value) catch |err| {
            log.logf(.warning, "dcs decodeHex append failed: {s}", .{@errorName(err)});
            return false;
        };
    }
    return true;
}

fn encodeHex(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) bool {
    const log = app_logger.logger("terminal.apc");
    const hex = "0123456789ABCDEF";
    for (text) |b| {
        _ = out.append(allocator, hex[b >> 4]) catch |err| {
            log.logf(.warning, "dcs encodeHex append hi failed: {s}", .{@errorName(err)});
            return false;
        };
        _ = out.append(allocator, hex[b & 0x0f]) catch |err| {
            log.logf(.warning, "dcs encodeHex append lo failed: {s}", .{@errorName(err)});
            return false;
        };
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

fn handleLegacySyncUpdates(session: *const SessionFacade, payload: []const u8) bool {
    const log = app_logger.logger("terminal.apc");
    // Legacy synchronized update control:
    // DCS = 1 s ST -> enable
    // DCS = 2 s ST -> disable
    if (payload.len < 3) return false;
    if (payload[0] != '=' or payload[payload.len - 1] != 's') return false;
    const raw = std.mem.trim(u8, payload[1 .. payload.len - 1], " ;");
    if (raw.len == 0) return false;
    const mode = std.fmt.parseInt(u8, raw, 10) catch {
        log.logf(.debug, "legacy sync updates parse failed raw={s}", .{raw});
        return false;
    };
    switch (mode) {
        1 => session.setSyncUpdatesLocked(true),
        2 => session.setSyncUpdatesLocked(false),
        else => return false,
    }
    return true;
}
