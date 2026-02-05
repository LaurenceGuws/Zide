const std = @import("std");
const builtin = @import("builtin");
const pty_mod = @import("../io/pty.zig"); // TODO(layering): consider routing PTY writes via core to avoid protocol->io coupling.
const palette_mod = @import("../core/palette.zig");
const osc_semantic = @import("../core/osc_semantic.zig");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");

const Pty = pty_mod.Pty;
const OscTerminator = parser_mod.OscTerminator;

pub fn parseOsc(self: anytype, payload: []const u8, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    if (log.enabled_file or log.enabled_console) {
        const max_len: usize = 160;
        const slice = if (payload.len > max_len) payload[0..max_len] else payload;
        log.logf("osc payload=\"{s}\"", .{slice});
    }
    var i: usize = 0;
    var code: usize = 0;
    var has_code = false;
    while (i < payload.len) : (i += 1) {
        const b = payload[i];
        if (b == ';') {
            has_code = true;
            i += 1;
            break;
        }
        if (b < '0' or b > '9') {
            return;
        }
        code = code * 10 + @as(usize, b - '0');
        has_code = true;
    }
    if (!has_code or i > payload.len) return;
    const text = payload[i..];
    switch (code) {
        0, 2 => {
            setTitle(self, text);
        },
        4 => palette_mod.handleOscPalette(self, text, terminator),
        10...19 => palette_mod.handleOscDynamicColor(self, @intCast(code), text, terminator),
        104 => palette_mod.handleOscPaletteReset(self, text),
        110...119 => palette_mod.handleOscDynamicReset(self, @intCast(code)),
        8 => {
            parseOscHyperlink(self, text);
        },
        7 => {
            parseOscCwd(self, text);
        },
        52 => {
            parseOscClipboard(self, text, terminator);
        },
        133 => {
            osc_semantic.parseSemanticPrompt(self, text);
        },
        1337 => {
            osc_semantic.parseUserVar(self, text);
        },
        else => {},
    }
}

fn setTitle(self: anytype, text: []const u8) void {
    self.title_buffer.clearRetainingCapacity();
    const max_len: usize = 256;
    const slice = if (text.len > max_len) text[0..max_len] else text;
    _ = self.title_buffer.appendSlice(self.allocator, slice) catch return;
    self.title = self.title_buffer.items;
}

fn parseOscHyperlink(self: anytype, text: []const u8) void {
    const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
    const uri = text[split + 1 ..];
    self.osc_hyperlink.clearRetainingCapacity();
    if (uri.len == 0) {
        self.osc_hyperlink_active = false;
        self.current_hyperlink_id = 0;
        return;
    }
    _ = self.osc_hyperlink.appendSlice(self.allocator, uri) catch return;
    self.osc_hyperlink_active = true;
    self.current_hyperlink_id = self.appendHyperlink(uri) orelse 0;
}

fn parseOscCwd(self: anytype, text: []const u8) void {
    const prefix = "file://";
    if (!std.mem.startsWith(u8, text, prefix)) return;
    const rest = text[prefix.len..];
    const slash = std.mem.indexOfScalar(u8, rest, '/') orelse return;
    const host = rest[0..slash];
    const raw_path = rest[slash..];
    if (raw_path.len == 0) return;
    if (!oscCwdHostOk(self, host)) return;

    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(self.allocator);
    if (!osc_semantic.decodeOscPercent(self.allocator, &decoded, raw_path)) return;

    normalizeCwd(self, decoded.items);
}

fn oscCwdHostOk(self: anytype, host: []const u8) bool {
    _ = self;
    if (host.len == 0) return true;
    if (std.mem.eql(u8, host, "localhost")) return true;
    if (builtin.target.os.tag == .windows) return false;

    if (builtin.target.os.tag == .windows) return false;

    var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const local = std.posix.gethostname(&buf) catch return false;
    if (std.mem.eql(u8, host, local)) return true;
    if (host.len > local.len and std.mem.startsWith(u8, host, local) and host[local.len] == '.') {
        return true;
    }
    return false;
}

fn normalizeCwd(self: anytype, raw_path: []const u8) void {
    self.cwd_buffer.clearRetainingCapacity();
    _ = self.cwd_buffer.append(self.allocator, '/') catch return;

    var stack = std.ArrayList(usize).empty;
    defer stack.deinit(self.allocator);

    var it = std.mem.splitScalar(u8, raw_path, '/');
    while (it.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".")) continue;
        if (std.mem.eql(u8, segment, "..")) {
            if (stack.pop()) |new_len| {
                self.cwd_buffer.items.len = new_len;
            } else if (self.cwd_buffer.items.len > 1) {
                self.cwd_buffer.items.len = 1;
            }
            continue;
        }
        if (self.cwd_buffer.items.len > 1 and self.cwd_buffer.items[self.cwd_buffer.items.len - 1] != '/') {
            _ = self.cwd_buffer.append(self.allocator, '/') catch return;
        }
        const segment_start = self.cwd_buffer.items.len;
        _ = self.cwd_buffer.appendSlice(self.allocator, segment) catch return;
        _ = stack.append(self.allocator, segment_start) catch return;
    }

    if (self.cwd_buffer.items.len == 0) {
        _ = self.cwd_buffer.append(self.allocator, '/') catch return;
    }
    self.cwd = self.cwd_buffer.items;
}

fn parseOscClipboard(self: anytype, text: []const u8, terminator: OscTerminator) void {
    const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
    const selection = text[0..split];
    const payload = text[split + 1 ..];
    if (payload.len == 0) return;
    if (!std.mem.containsAtLeast(u8, selection, 1, "c") and !std.mem.containsAtLeast(u8, selection, 1, "0")) {
        return;
    }
    if (std.mem.eql(u8, payload, "?")) {
        if (self.pty) |*pty| {
            writeOscClipboardReply(self, pty, selection, terminator);
        }
        return;
    }

    const max_bytes: usize = 1024 * 1024;
    if (payload.len > max_bytes * 2) return;

    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(self.allocator);

    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(payload) catch return;
    if (decoded_len > max_bytes) return;
    decoded.resize(self.allocator, decoded_len) catch return;
    _ = std.base64.standard.Decoder.decode(decoded.items, payload) catch return;

    self.osc_clipboard.clearRetainingCapacity();
    _ = self.osc_clipboard.appendSlice(self.allocator, decoded.items) catch return;
    _ = self.osc_clipboard.append(self.allocator, 0) catch return;
    self.osc_clipboard_pending = true;
}

fn writeOscClipboardReply(self: anytype, pty: *Pty, selection: []const u8, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    const end = if (terminator == .bel) "\x07" else "\x1b\\";
    var data = self.osc_clipboard.items;
    if (data.len > 0 and data[data.len - 1] == 0) {
        data = data[0 .. data.len - 1];
    }
    const encoded_len = std.base64.standard.Encoder.calcSize(data.len);
    var encoded = std.ArrayList(u8).empty;
    defer encoded.deinit(self.allocator);
    encoded.resize(self.allocator, encoded_len) catch return;
    _ = std.base64.standard.Encoder.encode(encoded.items, data);

    const seq_len = 4 + selection.len + 1 + encoded.items.len + end.len;
    var seq = std.ArrayList(u8).empty;
    defer seq.deinit(self.allocator);
    seq.ensureTotalCapacity(self.allocator, seq_len) catch return;
    _ = seq.appendSlice(self.allocator, "\x1b]52;") catch return;
    _ = seq.appendSlice(self.allocator, selection) catch return;
    _ = seq.append(self.allocator, ';') catch return;
    _ = seq.appendSlice(self.allocator, encoded.items) catch return;
    _ = seq.appendSlice(self.allocator, end) catch return;

    if (log.enabled_file or log.enabled_console) {
        log.logf("osc reply=\"{s}\"", .{seq.items});
    }
    _ = pty.write(seq.items) catch {};
}
