const std = @import("std");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");

const OscTerminator = parser_mod.OscTerminator;

const max_clipboard_bytes: usize = 1024 * 1024;
const data_chunk_max: usize = 4096;

pub const SessionFacade = struct {
    ctx: *anyopaque,
    parse_osc_5522_fn: *const fn (ctx: *anyopaque, text: []const u8, terminator: OscTerminator) void,
    send_paste_event_mimes_fn: *const fn (ctx: *anyopaque, pty: *anyopaque, write_fn: *const fn (pty: *anyopaque, bytes: []const u8) anyerror!usize, terminator: OscTerminator) void,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .parse_osc_5522_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8, terminator: OscTerminator) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    parseOsc5522OnSession(s, text, terminator);
                }
            }.call,
            .send_paste_event_mimes_fn = struct {
                fn call(ctx: *anyopaque, pty: *anyopaque, write_fn: *const fn (pty: *anyopaque, bytes: []const u8) anyerror!usize, terminator: OscTerminator) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    const WriterProxy = struct {
                        pty: *anyopaque,
                        write_fn: *const fn (pty: *anyopaque, bytes: []const u8) anyerror!usize,
                        pub fn write(self: *@This(), bytes: []const u8) anyerror!usize {
                            return try self.write_fn(self.pty, bytes);
                        }
                    };
                    var proxy = WriterProxy{ .pty = pty, .write_fn = write_fn };
                    sendPasteEventMimesOnSession(s, &proxy, terminator);
                }
            }.call,
        };
    }

    pub fn parseOsc5522(self: *const SessionFacade, text: []const u8, terminator: OscTerminator) void {
        self.parse_osc_5522_fn(self.ctx, text, terminator);
    }

    pub fn sendPasteEventMimes(self: *const SessionFacade, pty: anytype, terminator: OscTerminator) void {
        const PtyPtr = @TypeOf(pty);
        const write_fn = struct {
            fn call(ptr: *anyopaque, bytes: []const u8) anyerror!usize {
                const typed: PtyPtr = @ptrCast(@alignCast(ptr));
                return try typed.write(bytes);
            }
        }.call;
        self.send_paste_event_mimes_fn(self.ctx, @ptrCast(pty), write_fn, terminator);
    }
};

const ReadReq = struct {
    id: []const u8 = "",
    is_primary: bool = false,
    wants_targets: bool = false,
    wants_text_plain: bool = false,
    wants_text_html: bool = false,
    wants_text_uri_list: bool = false,
    wants_image_png: bool = false,
};

pub fn parseOsc5522(session: SessionFacade, text: []const u8, terminator: OscTerminator) void {
    session.parseOsc5522(text, terminator);
}

fn parseOsc5522OnSession(self: anytype, text: []const u8, terminator: OscTerminator) void {
    const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
    const metadata = text[0..split];
    const payload_b64 = text[split + 1 ..];

    var req = parseReadRequest(self, metadata, payload_b64) catch |err| {
        if (self.pty) |*pty| {
            switch (err) {
                error.UnsupportedPacketType => {},
                error.UnsupportedPrimarySelection => writeReadStatus(self, pty, terminator, "", "ENOSYS"),
                else => writeReadStatus(self, pty, terminator, "", "EINVAL"),
            }
        }
        return;
    };

    if (self.pty) |*pty| {
        replyReadRequest(self, pty, &req, terminator);
    }
}

pub fn sendPasteEventMimes(session: SessionFacade, pty: anytype, terminator: OscTerminator) void {
    session.sendPasteEventMimes(pty, terminator);
}

fn sendPasteEventMimesOnSession(self: anytype, pty: anytype, terminator: OscTerminator) void {
    var req = ReadReq{ .wants_targets = true };
    replyReadRequest(self, pty, &req, terminator);
}

fn parseReadRequest(self: anytype, metadata: []const u8, payload_b64: []const u8) !ReadReq {
    if (payload_b64.len == 0) return error.InvalidPayload;

    var req = ReadReq{};
    var packet_type: []const u8 = "";
    var parts = std.mem.splitScalar(u8, metadata, ':');
    while (parts.next()) |part| {
        if (part.len == 0) continue;
        const eq = std.mem.indexOfScalar(u8, part, '=') orelse return error.InvalidMetadata;
        const key = part[0..eq];
        const value = part[eq + 1 ..];
        if (std.mem.eql(u8, key, "type")) {
            packet_type = value;
        } else if (std.mem.eql(u8, key, "loc")) {
            if (std.mem.eql(u8, value, "primary")) req.is_primary = true;
        } else if (std.mem.eql(u8, key, "id")) {
            req.id = value;
        } else {
            // Ignore unsupported metadata keys (`pw`, `name`, etc.) for the minimal slice.
        }
    }
    if (!std.mem.eql(u8, packet_type, "read")) return error.UnsupportedPacketType;
    if (req.is_primary) return error.UnsupportedPrimarySelection;

    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(payload_b64) catch return error.InvalidPayload;
    if (decoded_len > max_clipboard_bytes) return error.InvalidPayload;
    const payload = try self.allocator.alloc(u8, decoded_len);
    defer self.allocator.free(payload);
    _ = std.base64.standard.Decoder.decode(payload, payload_b64) catch return error.InvalidPayload;
    if (payload.len == 1 and payload[0] == '.') {
        req.wants_targets = true;
        return req;
    }
    var saw_any = false;
    var it = std.mem.tokenizeScalar(u8, payload, ' ');
    while (it.next()) |mime| {
        saw_any = true;
        if (std.mem.eql(u8, mime, "text/plain")) {
            req.wants_text_plain = true;
        } else if (std.mem.eql(u8, mime, "text/html")) {
            req.wants_text_html = true;
        } else if (std.mem.eql(u8, mime, "text/uri-list")) {
            req.wants_text_uri_list = true;
        } else if (std.mem.eql(u8, mime, "image/png")) {
            req.wants_image_png = true;
        }
    }
    if (!saw_any) return error.InvalidPayload;
    return req;
}

fn replyReadRequest(self: anytype, pty: anytype, req: *const ReadReq, terminator: OscTerminator) void {
    const id = sanitizeId(self, req.id);
    defer if (id.owned) self.allocator.free(id.value);

    if (req.wants_targets) {
        writeReadStatusWithId(self, pty, terminator, id.value, "OK");
        if (self.kitty_osc5522_clipboard_text.items.len > 0) {
            writeReadData(self, pty, terminator, id.value, ".", "text/plain\n");
        }
        if (self.kitty_osc5522_clipboard_html.items.len > 0) {
            writeReadData(self, pty, terminator, id.value, ".", "text/html\n");
        }
        if (self.kitty_osc5522_clipboard_uri_list.items.len > 0) {
            writeReadData(self, pty, terminator, id.value, ".", "text/uri-list\n");
        }
        if (self.kitty_osc5522_clipboard_png.items.len > 0) {
            writeReadData(self, pty, terminator, id.value, ".", "image/png\n");
        }
        writeReadStatusWithId(self, pty, terminator, id.value, "DONE");
        return;
    }

    if (req.wants_text_plain) {
        const clip = self.kitty_osc5522_clipboard_text.items;
        if (clip.len == 0) {
            writeReadStatusWithId(self, pty, terminator, id.value, "ENOSYS");
            return;
        }
        writeReadStatusWithId(self, pty, terminator, id.value, "OK");
        var offset: usize = 0;
        while (offset < clip.len) {
            const end = @min(offset + data_chunk_max, clip.len);
            writeReadData(self, pty, terminator, id.value, "text/plain", clip[offset..end]);
            offset = end;
        }
        writeReadStatusWithId(self, pty, terminator, id.value, "DONE");
        return;
    }

    if (req.wants_text_html) {
        const clip = self.kitty_osc5522_clipboard_html.items;
        if (clip.len == 0) {
            writeReadStatusWithId(self, pty, terminator, id.value, "ENOSYS");
            return;
        }
        writeReadStatusWithId(self, pty, terminator, id.value, "OK");
        var offset: usize = 0;
        while (offset < clip.len) {
            const end = @min(offset + data_chunk_max, clip.len);
            writeReadData(self, pty, terminator, id.value, "text/html", clip[offset..end]);
            offset = end;
        }
        writeReadStatusWithId(self, pty, terminator, id.value, "DONE");
        return;
    }

    if (req.wants_text_uri_list) {
        const clip = self.kitty_osc5522_clipboard_uri_list.items;
        if (clip.len == 0) {
            writeReadStatusWithId(self, pty, terminator, id.value, "ENOSYS");
            return;
        }
        writeReadStatusWithId(self, pty, terminator, id.value, "OK");
        var offset: usize = 0;
        while (offset < clip.len) {
            const end = @min(offset + data_chunk_max, clip.len);
            writeReadData(self, pty, terminator, id.value, "text/uri-list", clip[offset..end]);
            offset = end;
        }
        writeReadStatusWithId(self, pty, terminator, id.value, "DONE");
        return;
    }

    if (req.wants_image_png) {
        const clip = self.kitty_osc5522_clipboard_png.items;
        if (clip.len == 0) {
            writeReadStatusWithId(self, pty, terminator, id.value, "ENOSYS");
            return;
        }
        writeReadStatusWithId(self, pty, terminator, id.value, "OK");
        var offset: usize = 0;
        while (offset < clip.len) {
            const end = @min(offset + data_chunk_max, clip.len);
            writeReadData(self, pty, terminator, id.value, "image/png", clip[offset..end]);
            offset = end;
        }
        writeReadStatusWithId(self, pty, terminator, id.value, "DONE");
        return;
    }

    writeReadStatusWithId(self, pty, terminator, id.value, "ENOSYS");
}

fn writeReadStatus(self: anytype, pty: anytype, terminator: OscTerminator, id: []const u8, status: []const u8) void {
    writeReadStatusWithId(self, pty, terminator, id, status);
}

fn writeReadStatusWithId(self: anytype, pty: anytype, terminator: OscTerminator, id: []const u8, status: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    var seq = std.ArrayList(u8).empty;
    defer seq.deinit(self.allocator);
    _ = seq.appendSlice(self.allocator, "\x1b]5522;type=read:status=") catch |err| {
        log.logf(.warning, "osc5522 status prefix append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(self.allocator, status) catch |err| {
        log.logf(.warning, "osc5522 status text append failed: {s}", .{@errorName(err)});
        return;
    };
    if (id.len > 0) {
        _ = seq.appendSlice(self.allocator, ":id=") catch |err| {
            log.logf(.warning, "osc5522 status id prefix append failed: {s}", .{@errorName(err)});
            return;
        };
        _ = seq.appendSlice(self.allocator, id) catch |err| {
            log.logf(.warning, "osc5522 status id append failed: {s}", .{@errorName(err)});
            return;
        };
    }
    appendOscTerminator(self, &seq, terminator);
    writeSeq(pty, seq.items);
}

fn writeReadData(self: anytype, pty: anytype, terminator: OscTerminator, id: []const u8, mime: []const u8, payload: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    const mime_b64_len = std.base64.standard.Encoder.calcSize(mime.len);
    const payload_b64_len = std.base64.standard.Encoder.calcSize(payload.len);
    var mime_b64 = std.ArrayList(u8).empty;
    defer mime_b64.deinit(self.allocator);
    var payload_b64 = std.ArrayList(u8).empty;
    defer payload_b64.deinit(self.allocator);
    mime_b64.resize(self.allocator, mime_b64_len) catch |err| {
        log.logf(.warning, "osc5522 data mime buffer resize failed: {s}", .{@errorName(err)});
        return;
    };
    payload_b64.resize(self.allocator, payload_b64_len) catch |err| {
        log.logf(.warning, "osc5522 data payload buffer resize failed: {s}", .{@errorName(err)});
        return;
    };
    _ = std.base64.standard.Encoder.encode(mime_b64.items, mime);
    _ = std.base64.standard.Encoder.encode(payload_b64.items, payload);

    var seq = std.ArrayList(u8).empty;
    defer seq.deinit(self.allocator);
    _ = seq.appendSlice(self.allocator, "\x1b]5522;type=read:status=DATA:mime=") catch |err| {
        log.logf(.warning, "osc5522 data prefix append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(self.allocator, mime_b64.items) catch |err| {
        log.logf(.warning, "osc5522 data mime append failed: {s}", .{@errorName(err)});
        return;
    };
    if (id.len > 0) {
        _ = seq.appendSlice(self.allocator, ":id=") catch |err| {
            log.logf(.warning, "osc5522 data id prefix append failed: {s}", .{@errorName(err)});
            return;
        };
        _ = seq.appendSlice(self.allocator, id) catch |err| {
            log.logf(.warning, "osc5522 data id append failed: {s}", .{@errorName(err)});
            return;
        };
    }
    _ = seq.append(self.allocator, ';') catch |err| {
        log.logf(.warning, "osc5522 data separator append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(self.allocator, payload_b64.items) catch |err| {
        log.logf(.warning, "osc5522 data payload append failed: {s}", .{@errorName(err)});
        return;
    };
    appendOscTerminator(self, &seq, terminator);
    writeSeq(pty, seq.items);
}

fn appendOscTerminator(self: anytype, seq: *std.ArrayList(u8), terminator: OscTerminator) void {
    seq.appendSlice(self.allocator, if (terminator == .bel) "\x07" else "\x1b\\") catch |err| {
        app_logger.logger("terminal.osc").logf(.warning, "osc5522 terminator append failed err={s}", .{@errorName(err)});
    };
}

fn writeSeq(pty: anytype, seq: []const u8) void {
    const log = app_logger.logger("terminal.osc");
            log.logf(.debug, "osc5522 reply=\"{s}\"", .{seq});
    _ = pty.write(seq) catch |err| blk: {
        log.logf(.warning, "osc5522 reply write failed len={d} err={s}", .{ seq.len, @errorName(err) });
        break :blk 0;
    };
}

fn sanitizeId(self: anytype, id: []const u8) struct { value: []const u8, owned: bool } {
    if (id.len == 0) return .{ .value = "", .owned = false };
    var out = std.ArrayList(u8).empty;
    for (id) |ch| {
        if ((ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '-' or ch == '_' or ch == '+' or ch == '.') {
            out.append(self.allocator, ch) catch |err| {
                app_logger.logger("terminal.osc").logf(.warning, "osc5522 id sanitize append failed err={s}", .{@errorName(err)});
                out.deinit(self.allocator);
                return .{ .value = "", .owned = false };
            };
        }
    }
    if (out.items.len == 0) {
        out.deinit(self.allocator);
        return .{ .value = "", .owned = false };
    }
    const owned = out.toOwnedSlice(self.allocator) catch |err| {
        app_logger.logger("terminal.osc").logf(.warning, "osc5522 id sanitize materialize failed err={s}", .{@errorName(err)});
        out.deinit(self.allocator);
        return .{ .value = "", .owned = false };
    };
    return .{ .value = owned, .owned = true };
}
