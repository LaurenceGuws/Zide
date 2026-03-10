const std = @import("std");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");

const OscTerminator = parser_mod.OscTerminator;

const max_clipboard_bytes: usize = 1024 * 1024;
const data_chunk_max: usize = 4096;

const WriterFacade = struct {
    ctx: *anyopaque,
    write_fn: *const fn (ctx: *anyopaque, bytes: []const u8) anyerror!usize,

    pub fn from(writer: anytype) WriterFacade {
        const WriterPtr = @TypeOf(writer);
        return .{
            .ctx = @ptrCast(writer),
            .write_fn = struct {
                fn call(ctx: *anyopaque, bytes: []const u8) anyerror!usize {
                    const typed: WriterPtr = @ptrCast(@alignCast(ctx));
                    return try typed.write(bytes);
                }
            }.call,
        };
    }

    pub fn write(self: WriterFacade, bytes: []const u8) anyerror!usize {
        return try self.write_fn(self.ctx, bytes);
    }
};

pub const SessionFacade = struct {
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
    parse_osc_5522_fn: *const fn (ctx: *anyopaque, text: []const u8, terminator: OscTerminator) void,
    send_paste_event_mimes_fn: *const fn (ctx: *anyopaque, writer: WriterFacade, terminator: OscTerminator) void,
    clipboard_text_fn: *const fn (ctx: *anyopaque) []const u8,
    clipboard_html_fn: *const fn (ctx: *anyopaque) []const u8,
    clipboard_uri_list_fn: *const fn (ctx: *anyopaque) []const u8,
    clipboard_png_fn: *const fn (ctx: *anyopaque) []const u8,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .allocator = session.allocator,
            .parse_osc_5522_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8, terminator: OscTerminator) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    parseOsc5522OnSession(s, text, terminator);
                }
            }.call,
            .send_paste_event_mimes_fn = struct {
                fn call(ctx: *anyopaque, writer: WriterFacade, terminator: OscTerminator) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    sendPasteEventMimesOnSession(s, writer, terminator);
                }
            }.call,
            .clipboard_text_fn = struct {
                fn call(ctx: *anyopaque) []const u8 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.core.kitty_osc5522_clipboard_text.items;
                }
            }.call,
            .clipboard_html_fn = struct {
                fn call(ctx: *anyopaque) []const u8 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.core.kitty_osc5522_clipboard_html.items;
                }
            }.call,
            .clipboard_uri_list_fn = struct {
                fn call(ctx: *anyopaque) []const u8 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.core.kitty_osc5522_clipboard_uri_list.items;
                }
            }.call,
            .clipboard_png_fn = struct {
                fn call(ctx: *anyopaque) []const u8 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.core.kitty_osc5522_clipboard_png.items;
                }
            }.call,
        };
    }

    pub fn parseOsc5522(self: *const SessionFacade, text: []const u8, terminator: OscTerminator) void {
        self.parse_osc_5522_fn(self.ctx, text, terminator);
    }

    pub fn sendPasteEventMimes(self: *const SessionFacade, pty: anytype, terminator: OscTerminator) void {
        self.send_paste_event_mimes_fn(self.ctx, WriterFacade.from(pty), terminator);
    }

    pub fn clipboardText(self: *const SessionFacade) []const u8 {
        return self.clipboard_text_fn(self.ctx);
    }

    pub fn clipboardHtml(self: *const SessionFacade) []const u8 {
        return self.clipboard_html_fn(self.ctx);
    }

    pub fn clipboardUriList(self: *const SessionFacade) []const u8 {
        return self.clipboard_uri_list_fn(self.ctx);
    }

    pub fn clipboardPng(self: *const SessionFacade) []const u8 {
        return self.clipboard_png_fn(self.ctx);
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
    const session = SessionFacade.from(self);
    const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
    const metadata = text[0..split];
    const payload_b64 = text[split + 1 ..];

    var req = parseReadRequest(session, metadata, payload_b64) catch |err| {
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
            const facade = WriterFacade.from(&writer);
            switch (err) {
                error.UnsupportedPacketType => {},
                error.UnsupportedPrimarySelection => writeReadStatus(session, facade, terminator, "", "ENOSYS"),
                else => writeReadStatus(session, facade, terminator, "", "EINVAL"),
            }
        }
        return;
    };

    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        replyReadRequest(session, WriterFacade.from(&writer), &req, terminator);
    }
}

pub fn sendPasteEventMimes(session: SessionFacade, pty: anytype, terminator: OscTerminator) void {
    session.sendPasteEventMimes(pty, terminator);
}

fn sendPasteEventMimesOnSession(self: anytype, writer: WriterFacade, terminator: OscTerminator) void {
    const session = SessionFacade.from(self);
    var req = ReadReq{ .wants_targets = true };
    replyReadRequest(session, writer, &req, terminator);
}

fn parseReadRequest(session: SessionFacade, metadata: []const u8, payload_b64: []const u8) !ReadReq {
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
    const payload = try session.allocator.alloc(u8, decoded_len);
    defer session.allocator.free(payload);
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

fn replyReadRequest(session: SessionFacade, writer: WriterFacade, req: *const ReadReq, terminator: OscTerminator) void {
    const id = sanitizeId(session, req.id);
    defer if (id.owned) session.allocator.free(id.value);

    if (req.wants_targets) {
        writeReadStatusWithId(session, writer, terminator, id.value, "OK");
        if (session.clipboardText().len > 0) {
            writeReadData(session, writer, terminator, id.value, ".", "text/plain\n");
        }
        if (session.clipboardHtml().len > 0) {
            writeReadData(session, writer, terminator, id.value, ".", "text/html\n");
        }
        if (session.clipboardUriList().len > 0) {
            writeReadData(session, writer, terminator, id.value, ".", "text/uri-list\n");
        }
        if (session.clipboardPng().len > 0) {
            writeReadData(session, writer, terminator, id.value, ".", "image/png\n");
        }
        writeReadStatusWithId(session, writer, terminator, id.value, "DONE");
        return;
    }

    if (req.wants_text_plain) {
        const clip = session.clipboardText();
        if (clip.len == 0) {
            writeReadStatusWithId(session, writer, terminator, id.value, "ENOSYS");
            return;
        }
        writeReadStatusWithId(session, writer, terminator, id.value, "OK");
        var offset: usize = 0;
        while (offset < clip.len) {
            const end = @min(offset + data_chunk_max, clip.len);
            writeReadData(session, writer, terminator, id.value, "text/plain", clip[offset..end]);
            offset = end;
        }
        writeReadStatusWithId(session, writer, terminator, id.value, "DONE");
        return;
    }

    if (req.wants_text_html) {
        const clip = session.clipboardHtml();
        if (clip.len == 0) {
            writeReadStatusWithId(session, writer, terminator, id.value, "ENOSYS");
            return;
        }
        writeReadStatusWithId(session, writer, terminator, id.value, "OK");
        var offset: usize = 0;
        while (offset < clip.len) {
            const end = @min(offset + data_chunk_max, clip.len);
            writeReadData(session, writer, terminator, id.value, "text/html", clip[offset..end]);
            offset = end;
        }
        writeReadStatusWithId(session, writer, terminator, id.value, "DONE");
        return;
    }

    if (req.wants_text_uri_list) {
        const clip = session.clipboardUriList();
        if (clip.len == 0) {
            writeReadStatusWithId(session, writer, terminator, id.value, "ENOSYS");
            return;
        }
        writeReadStatusWithId(session, writer, terminator, id.value, "OK");
        var offset: usize = 0;
        while (offset < clip.len) {
            const end = @min(offset + data_chunk_max, clip.len);
            writeReadData(session, writer, terminator, id.value, "text/uri-list", clip[offset..end]);
            offset = end;
        }
        writeReadStatusWithId(session, writer, terminator, id.value, "DONE");
        return;
    }

    if (req.wants_image_png) {
        const clip = session.clipboardPng();
        if (clip.len == 0) {
            writeReadStatusWithId(session, writer, terminator, id.value, "ENOSYS");
            return;
        }
        writeReadStatusWithId(session, writer, terminator, id.value, "OK");
        var offset: usize = 0;
        while (offset < clip.len) {
            const end = @min(offset + data_chunk_max, clip.len);
            writeReadData(session, writer, terminator, id.value, "image/png", clip[offset..end]);
            offset = end;
        }
        writeReadStatusWithId(session, writer, terminator, id.value, "DONE");
        return;
    }

    writeReadStatusWithId(session, writer, terminator, id.value, "ENOSYS");
}

fn writeReadStatus(session: SessionFacade, writer: WriterFacade, terminator: OscTerminator, id: []const u8, status: []const u8) void {
    writeReadStatusWithId(session, writer, terminator, id, status);
}

fn writeReadStatusWithId(session: SessionFacade, writer: WriterFacade, terminator: OscTerminator, id: []const u8, status: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    var seq = std.ArrayList(u8).empty;
    defer seq.deinit(session.allocator);
    _ = seq.appendSlice(session.allocator, "\x1b]5522;type=read:status=") catch |err| {
        log.logf(.warning, "osc5522 status prefix append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(session.allocator, status) catch |err| {
        log.logf(.warning, "osc5522 status text append failed: {s}", .{@errorName(err)});
        return;
    };
    if (id.len > 0) {
        _ = seq.appendSlice(session.allocator, ":id=") catch |err| {
            log.logf(.warning, "osc5522 status id prefix append failed: {s}", .{@errorName(err)});
            return;
        };
        _ = seq.appendSlice(session.allocator, id) catch |err| {
            log.logf(.warning, "osc5522 status id append failed: {s}", .{@errorName(err)});
            return;
        };
    }
    appendOscTerminator(session.allocator, &seq, terminator);
    writeSeq(writer, seq.items);
}

fn writeReadData(session: SessionFacade, writer: WriterFacade, terminator: OscTerminator, id: []const u8, mime: []const u8, payload: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    const mime_b64_len = std.base64.standard.Encoder.calcSize(mime.len);
    const payload_b64_len = std.base64.standard.Encoder.calcSize(payload.len);
    var mime_b64 = std.ArrayList(u8).empty;
    defer mime_b64.deinit(session.allocator);
    var payload_b64 = std.ArrayList(u8).empty;
    defer payload_b64.deinit(session.allocator);
    mime_b64.resize(session.allocator, mime_b64_len) catch |err| {
        log.logf(.warning, "osc5522 data mime buffer resize failed: {s}", .{@errorName(err)});
        return;
    };
    payload_b64.resize(session.allocator, payload_b64_len) catch |err| {
        log.logf(.warning, "osc5522 data payload buffer resize failed: {s}", .{@errorName(err)});
        return;
    };
    _ = std.base64.standard.Encoder.encode(mime_b64.items, mime);
    _ = std.base64.standard.Encoder.encode(payload_b64.items, payload);

    var seq = std.ArrayList(u8).empty;
    defer seq.deinit(session.allocator);
    _ = seq.appendSlice(session.allocator, "\x1b]5522;type=read:status=DATA:mime=") catch |err| {
        log.logf(.warning, "osc5522 data prefix append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(session.allocator, mime_b64.items) catch |err| {
        log.logf(.warning, "osc5522 data mime append failed: {s}", .{@errorName(err)});
        return;
    };
    if (id.len > 0) {
        _ = seq.appendSlice(session.allocator, ":id=") catch |err| {
            log.logf(.warning, "osc5522 data id prefix append failed: {s}", .{@errorName(err)});
            return;
        };
        _ = seq.appendSlice(session.allocator, id) catch |err| {
            log.logf(.warning, "osc5522 data id append failed: {s}", .{@errorName(err)});
            return;
        };
    }
    _ = seq.append(session.allocator, ';') catch |err| {
        log.logf(.warning, "osc5522 data separator append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(session.allocator, payload_b64.items) catch |err| {
        log.logf(.warning, "osc5522 data payload append failed: {s}", .{@errorName(err)});
        return;
    };
    appendOscTerminator(session.allocator, &seq, terminator);
    writeSeq(writer, seq.items);
}

fn appendOscTerminator(allocator: std.mem.Allocator, seq: *std.ArrayList(u8), terminator: OscTerminator) void {
    seq.appendSlice(allocator, if (terminator == .bel) "\x07" else "\x1b\\") catch |err| {
        app_logger.logger("terminal.osc").logf(.warning, "osc5522 terminator append failed err={s}", .{@errorName(err)});
    };
}

fn writeSeq(writer: WriterFacade, seq: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    log.logf(.debug, "osc5522 reply=\"{s}\"", .{seq});
    _ = writer.write(seq) catch |err| blk: {
        log.logf(.warning, "osc5522 reply write failed len={d} err={s}", .{ seq.len, @errorName(err) });
        break :blk 0;
    };
}

fn sanitizeId(session: SessionFacade, id: []const u8) struct { value: []const u8, owned: bool } {
    if (id.len == 0) return .{ .value = "", .owned = false };
    var out = std.ArrayList(u8).empty;
    for (id) |ch| {
        if ((ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '-' or ch == '_' or ch == '+' or ch == '.') {
            out.append(session.allocator, ch) catch |err| {
                app_logger.logger("terminal.osc").logf(.warning, "osc5522 id sanitize append failed err={s}", .{@errorName(err)});
                out.deinit(session.allocator);
                return .{ .value = "", .owned = false };
            };
        }
    }
    if (out.items.len == 0) {
        out.deinit(session.allocator);
        return .{ .value = "", .owned = false };
    }
    const owned = out.toOwnedSlice(session.allocator) catch |err| {
        app_logger.logger("terminal.osc").logf(.warning, "osc5522 id sanitize materialize failed err={s}", .{@errorName(err)});
        out.deinit(session.allocator);
        return .{ .value = "", .owned = false };
    };
    return .{ .value = owned, .owned = true };
}
