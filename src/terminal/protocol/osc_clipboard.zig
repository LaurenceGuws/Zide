const std = @import("std");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");
const OscTerminator = parser_mod.OscTerminator;

pub const SessionFacade = struct {
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
    osc_clipboard: *std.ArrayList(u8),
    osc_clipboard_pending: *bool,
    write_pty_bytes_fn: *const fn (ctx: *anyopaque, bytes: []const u8) anyerror!void,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .allocator = session.allocator,
            .osc_clipboard = &session.osc_clipboard,
            .osc_clipboard_pending = &session.osc_clipboard_pending,
            .write_pty_bytes_fn = struct {
                fn call(ctx: *anyopaque, bytes: []const u8) anyerror!void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    try s.writePtyBytes(bytes);
                }
            }.call,
        };
    }

    pub fn clearOscClipboard(self: *const SessionFacade) void {
        self.osc_clipboard.clearRetainingCapacity();
    }

    pub fn appendOscClipboardSlice(self: *const SessionFacade, text: []const u8) !void {
        _ = try self.osc_clipboard.appendSlice(self.allocator, text);
    }

    pub fn appendOscClipboardByte(self: *const SessionFacade, b: u8) !void {
        try self.osc_clipboard.append(self.allocator, b);
    }

    pub fn setOscClipboardPending(self: *const SessionFacade, pending: bool) void {
        self.osc_clipboard_pending.* = pending;
    }

    pub fn oscClipboardSlice(self: *const SessionFacade) []const u8 {
        return self.osc_clipboard.items;
    }

    pub fn writePtyBytes(self: *const SessionFacade, bytes: []const u8) !void {
        try self.write_pty_bytes_fn(self.ctx, bytes);
    }
};

pub fn parseClipboard(session: SessionFacade, text: []const u8, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
    const selection = text[0..split];
    const payload = text[split + 1 ..];
    if (payload.len == 0) return;
    if (!std.mem.containsAtLeast(u8, selection, 1, "c") and !std.mem.containsAtLeast(u8, selection, 1, "0")) {
        return;
    }
    if (std.mem.eql(u8, payload, "?")) {
        writeClipboardReply(session, selection, terminator);
        return;
    }

    const max_bytes: usize = 1024 * 1024;
    if (payload.len > max_bytes * 2) return;

    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(session.allocator);

    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(payload) catch |err| {
        log.logf(.warning, "osc52 calc decoded length failed: {s}", .{@errorName(err)});
        return;
    };
    if (decoded_len > max_bytes) return;
    decoded.resize(session.allocator, decoded_len) catch |err| {
        log.logf(.warning, "osc52 decoded buffer resize failed: {s}", .{@errorName(err)});
        return;
    };
    _ = std.base64.standard.Decoder.decode(decoded.items, payload) catch |err| {
        log.logf(.warning, "osc52 base64 decode failed: {s}", .{@errorName(err)});
        return;
    };

    session.clearOscClipboard();
    session.appendOscClipboardSlice(decoded.items) catch |err| {
        log.logf(.warning, "osc52 clipboard append failed: {s}", .{@errorName(err)});
        return;
    };
    session.appendOscClipboardByte(0) catch |err| {
        log.logf(.warning, "osc52 clipboard nul append failed: {s}", .{@errorName(err)});
        return;
    };
    session.setOscClipboardPending(true);
}

fn writeClipboardReply(session: SessionFacade, selection: []const u8, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    const end = if (terminator == .bel) "\x07" else "\x1b\\";
    var data = session.oscClipboardSlice();
    if (data.len > 0 and data[data.len - 1] == 0) {
        data = data[0 .. data.len - 1];
    }
    const encoded_len = std.base64.standard.Encoder.calcSize(data.len);
    var encoded = std.ArrayList(u8).empty;
    defer encoded.deinit(session.allocator);
    encoded.resize(session.allocator, encoded_len) catch |err| {
        log.logf(.warning, "osc52 reply encoded buffer resize failed: {s}", .{@errorName(err)});
        return;
    };
    _ = std.base64.standard.Encoder.encode(encoded.items, data);

    const seq_len = 4 + selection.len + 1 + encoded.items.len + end.len;
    var seq = std.ArrayList(u8).empty;
    defer seq.deinit(session.allocator);
    seq.ensureTotalCapacity(session.allocator, seq_len) catch |err| {
        log.logf(.warning, "osc52 reply sequence capacity failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(session.allocator, "\x1b]52;") catch |err| {
        log.logf(.warning, "osc52 reply prefix append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(session.allocator, selection) catch |err| {
        log.logf(.warning, "osc52 reply selection append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.append(session.allocator, ';') catch |err| {
        log.logf(.warning, "osc52 reply separator append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(session.allocator, encoded.items) catch |err| {
        log.logf(.warning, "osc52 reply payload append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(session.allocator, end) catch |err| {
        log.logf(.warning, "osc52 reply terminator append failed: {s}", .{@errorName(err)});
        return;
    };

            log.logf(.debug, "osc reply=\"{s}\"", .{seq.items});
    session.writePtyBytes(seq.items) catch |err| {
        log.logf(.warning, "osc52 reply write failed len={d} err={s}", .{ seq.items.len, @errorName(err) });
    };
}
