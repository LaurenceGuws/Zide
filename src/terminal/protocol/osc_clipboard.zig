const std = @import("std");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");
const OscTerminator = parser_mod.OscTerminator;

pub fn parseClipboard(self: anytype, text: []const u8, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
    const selection = text[0..split];
    const payload = text[split + 1 ..];
    if (payload.len == 0) return;
    if (!std.mem.containsAtLeast(u8, selection, 1, "c") and !std.mem.containsAtLeast(u8, selection, 1, "0")) {
        return;
    }
    if (std.mem.eql(u8, payload, "?")) {
        writeClipboardReply(self, selection, terminator);
        return;
    }

    const max_bytes: usize = 1024 * 1024;
    if (payload.len > max_bytes * 2) return;

    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(self.allocator);

    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(payload) catch |err| {
        log.logf(.warning, "osc52 calc decoded length failed: {s}", .{@errorName(err)});
        return;
    };
    if (decoded_len > max_bytes) return;
    decoded.resize(self.allocator, decoded_len) catch |err| {
        log.logf(.warning, "osc52 decoded buffer resize failed: {s}", .{@errorName(err)});
        return;
    };
    _ = std.base64.standard.Decoder.decode(decoded.items, payload) catch |err| {
        log.logf(.warning, "osc52 base64 decode failed: {s}", .{@errorName(err)});
        return;
    };

    self.osc_clipboard.clearRetainingCapacity();
    _ = self.osc_clipboard.appendSlice(self.allocator, decoded.items) catch |err| {
        log.logf(.warning, "osc52 clipboard append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = self.osc_clipboard.append(self.allocator, 0) catch |err| {
        log.logf(.warning, "osc52 clipboard nul append failed: {s}", .{@errorName(err)});
        return;
    };
    self.osc_clipboard_pending = true;
}

fn writeClipboardReply(self: anytype, selection: []const u8, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    const end = if (terminator == .bel) "\x07" else "\x1b\\";
    var data = self.osc_clipboard.items;
    if (data.len > 0 and data[data.len - 1] == 0) {
        data = data[0 .. data.len - 1];
    }
    const encoded_len = std.base64.standard.Encoder.calcSize(data.len);
    var encoded = std.ArrayList(u8).empty;
    defer encoded.deinit(self.allocator);
    encoded.resize(self.allocator, encoded_len) catch |err| {
        log.logf(.warning, "osc52 reply encoded buffer resize failed: {s}", .{@errorName(err)});
        return;
    };
    _ = std.base64.standard.Encoder.encode(encoded.items, data);

    const seq_len = 4 + selection.len + 1 + encoded.items.len + end.len;
    var seq = std.ArrayList(u8).empty;
    defer seq.deinit(self.allocator);
    seq.ensureTotalCapacity(self.allocator, seq_len) catch |err| {
        log.logf(.warning, "osc52 reply sequence capacity failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(self.allocator, "\x1b]52;") catch |err| {
        log.logf(.warning, "osc52 reply prefix append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(self.allocator, selection) catch |err| {
        log.logf(.warning, "osc52 reply selection append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.append(self.allocator, ';') catch |err| {
        log.logf(.warning, "osc52 reply separator append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(self.allocator, encoded.items) catch |err| {
        log.logf(.warning, "osc52 reply payload append failed: {s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(self.allocator, end) catch |err| {
        log.logf(.warning, "osc52 reply terminator append failed: {s}", .{@errorName(err)});
        return;
    };

            log.logf(.debug, "osc reply=\"{s}\"", .{seq.items});
    self.writePtyBytes(seq.items) catch |err| {
        log.logf(.warning, "osc52 reply write failed len={d} err={s}", .{ seq.items.len, @errorName(err) });
    };
}
