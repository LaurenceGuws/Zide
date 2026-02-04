const std = @import("std");
const builtin = @import("builtin");
const types = @import("../model/types.zig");
const pty_mod = @import("../io/pty.zig"); // TODO(layering): consider routing PTY writes via core to avoid protocol->io coupling.
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");

const Pty = pty_mod.Pty;
const OscTerminator = parser_mod.OscTerminator;

const dynamic_color_base: u8 = 10;

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
        4 => handleOscPalette(self, text, terminator),
        10...19 => handleOscDynamicColor(self, @intCast(code), text, terminator),
        104 => handleOscPaletteReset(self, text),
        110...119 => handleOscDynamicReset(self, @intCast(code)),
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
            parseOscSemanticPrompt(self, text);
        },
        1337 => {
            parseOscUserVar(self, text);
        },
        else => {},
    }
}

fn parseOscColor(text: []const u8) ?types.Color {
    if (text.len == 0) return null;
    if (std.mem.eql(u8, text, "?")) return null;
    if (text[0] == '#') {
        if (text.len < 7) return null;
        return parseHexColor(text[1..7]);
    }
    if (std.mem.startsWith(u8, text, "rgb:")) {
        const rest = text[4..];
        var it = std.mem.splitScalar(u8, rest, '/');
        const r = it.next() orelse return null;
        const g = it.next() orelse return null;
        const b = it.next() orelse return null;
        const rc = parseHexComponent(r) orelse return null;
        const gc = parseHexComponent(g) orelse return null;
        const bc = parseHexComponent(b) orelse return null;
        return .{ .r = rc, .g = gc, .b = bc };
    }
    return null;
}

fn parseHexColor(text: []const u8) ?types.Color {
    if (text.len < 6) return null;
    const r = parseHexComponent(text[0..2]) orelse return null;
    const g = parseHexComponent(text[2..4]) orelse return null;
    const b = parseHexComponent(text[4..6]) orelse return null;
    return .{ .r = r, .g = g, .b = b };
}

fn parseHexComponent(text: []const u8) ?u8 {
    if (text.len == 0) return null;
    // Accept 1-4 hex digits; scale to 8-bit.
    var value: u32 = 0;
    for (text) |c| {
        const digit: u8 = switch (c) {
            '0'...'9' => c - '0',
            'a'...'f' => c - 'a' + 10,
            'A'...'F' => c - 'A' + 10,
            else => return null,
        };
        value = (value << 4) | digit;
    }
    const bits: u8 = @intCast(text.len * 4);
    if (bits == 8) return @intCast(value);
    if (bits < 8) {
        const shift: u5 = @intCast(8 - bits);
        const scaled: u32 = value << shift;
        return @intCast(scaled);
    }
    const shift: u5 = @intCast(bits - 8);
    const scaled: u32 = value >> shift;
    return @intCast(scaled);
}

fn writeOscColorReply(self: anytype, pty: *Pty, code: u8, color: types.Color, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    _ = self;
    var buf: [80]u8 = undefined;
    const end = if (terminator == .bel) "\x07" else "\x1b\\";
    const r16: u16 = @as(u16, color.r) * 257;
    const g16: u16 = @as(u16, color.g) * 257;
    const b16: u16 = @as(u16, color.b) * 257;
    const seq = std.fmt.bufPrint(
        &buf,
        "\x1b]{d};rgb:{x:0>4}/{x:0>4}/{x:0>4}{s}",
        .{ code, r16, g16, b16, end },
    ) catch return;
    if (log.enabled_file or log.enabled_console) {
        log.logf("osc reply=\"{s}\"", .{seq});
        logOscReplyHex(log, seq);
    }
    _ = pty.write(seq) catch {};
}

fn writeOscPaletteReply(self: anytype, pty: *Pty, idx: u8, color: types.Color, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    _ = self;
    var buf: [88]u8 = undefined;
    const end = if (terminator == .bel) "\x07" else "\x1b\\";
    const r16: u16 = @as(u16, color.r) * 257;
    const g16: u16 = @as(u16, color.g) * 257;
    const b16: u16 = @as(u16, color.b) * 257;
    const seq = std.fmt.bufPrint(
        &buf,
        "\x1b]4;{d};rgb:{x:0>4}/{x:0>4}/{x:0>4}{s}",
        .{ idx, r16, g16, b16, end },
    ) catch return;
    if (log.enabled_file or log.enabled_console) {
        log.logf("osc reply=\"{s}\"", .{seq});
        logOscReplyHex(log, seq);
    }
    _ = pty.write(seq) catch {};
}

fn handleOscPalette(self: anytype, text: []const u8, terminator: OscTerminator) void {
    if (text.len == 0) return;
    var it = std.mem.splitScalar(u8, text, ';');
    while (true) {
        const idx_text = it.next() orelse break;
        const color_text = it.next() orelse break;
        const idx = parseOscIndex(idx_text) orelse continue;
        if (idx >= self.palette_current.len) continue;
        if (color_text.len == 1 and color_text[0] == '?') {
            if (self.pty) |*pty| {
                writeOscPaletteReply(self, pty, @intCast(idx), self.palette_current[idx], terminator);
            }
            continue;
        }
        if (parseOscColor(color_text)) |color| {
            self.palette_current[idx] = color;
        }
    }
}

fn handleOscPaletteReset(self: anytype, text: []const u8) void {
    if (text.len == 0) {
        self.palette_current = self.palette_default;
        return;
    }
    var it = std.mem.splitScalar(u8, text, ';');
    while (it.next()) |idx_text| {
        const idx = parseOscIndex(idx_text) orelse continue;
        if (idx >= self.palette_current.len) continue;
        self.palette_current[idx] = self.palette_default[idx];
    }
}

fn handleOscDynamicColor(self: anytype, code: u8, text: []const u8, terminator: OscTerminator) void {
    if (self.pty) |*pty| {
        if (text.len == 1 and text[0] == '?') {
            const color = dynamicColorValue(self, code);
            writeOscColorReply(self, pty, code, color, terminator);
            return;
        }
    }
    if (parseOscColor(text)) |color| {
        switch (code) {
            10 => {
                const default_attrs = self.primary.default_attrs;
                self.setDefaultColors(color, default_attrs.bg);
            },
            11 => {
                const default_attrs = self.primary.default_attrs;
                self.setDefaultColors(default_attrs.fg, color);
            },
            else => {
                const idx = @as(usize, code - dynamic_color_base);
                if (idx < self.dynamic_colors.len) {
                    self.dynamic_colors[idx] = color;
                }
            },
        }
    }
}

fn handleOscDynamicReset(self: anytype, code: u8) void {
    const target = code - 100;
    switch (target) {
        10 => {
            const default_attrs = self.primary.default_attrs;
            self.setDefaultColors(self.base_default_attrs.fg, default_attrs.bg);
        },
        11 => {
            const default_attrs = self.primary.default_attrs;
            self.setDefaultColors(default_attrs.fg, self.base_default_attrs.bg);
        },
        else => {
            const idx = @as(usize, target - dynamic_color_base);
            if (idx < self.dynamic_colors.len) {
                self.dynamic_colors[idx] = null;
            }
        },
    }
}

fn dynamicColorValue(self: anytype, code: u8) types.Color {
    if (code == 10) return self.primary.default_attrs.fg;
    if (code == 11) return self.primary.default_attrs.bg;
    const idx = @as(usize, code - dynamic_color_base);
    if (idx < self.dynamic_colors.len) {
        if (self.dynamic_colors[idx]) |color| return color;
    }
    return switch (code) {
        12 => self.primary.default_attrs.fg,
        17, 19 => self.primary.default_attrs.bg,
        else => self.primary.default_attrs.fg,
    };
}

fn parseOscIndex(text: []const u8) ?usize {
    if (text.len == 0) return null;
    var value: usize = 0;
    for (text) |c| {
        if (c < '0' or c > '9') return null;
        value = value * 10 + @as(usize, c - '0');
    }
    return value;
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
    if (!decodeOscPercent(self.allocator, &decoded, raw_path)) return;

    normalizeCwd(self, decoded.items);
}

fn oscCwdHostOk(self: anytype, host: []const u8) bool {
    _ = self;
    if (host.len == 0) return true;
    if (std.mem.eql(u8, host, "localhost")) return true;
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

fn parseOscSemanticPrompt(self: anytype, text: []const u8) void {
    if (text.len == 0) return;
    const log = app_logger.logger("terminal.osc");
    const kind = text[0];
    const rest = if (text.len > 1 and text[1] == ';') text[2..] else if (text.len == 1) "" else text[1..];

    switch (kind) {
        'A' => {
            self.semantic_prompt.prompt_active = true;
            self.semantic_prompt.input_active = false;
            self.semantic_prompt.output_active = false;
            self.semantic_prompt.kind = .primary;
            self.semantic_prompt.redraw = true;
            self.semantic_prompt.special_key = false;
            self.semantic_prompt.click_events = false;
            self.semantic_prompt.exit_code = null;
            self.semantic_prompt_aid.clearRetainingCapacity();
            self.semantic_cmdline_valid = false;
            applySemanticPromptOptions(self, rest, true);
        },
        'B' => {
            self.semantic_prompt.prompt_active = false;
            self.semantic_prompt.input_active = true;
            self.semantic_prompt.output_active = false;
            applySemanticPromptOptions(self, rest, false);
        },
        'C' => {
            self.semantic_prompt.prompt_active = false;
            self.semantic_prompt.input_active = false;
            self.semantic_prompt.output_active = true;
            applySemanticPromptEndInput(self, rest);
        },
        'D' => {
            self.semantic_prompt.prompt_active = false;
            self.semantic_prompt.input_active = false;
            self.semantic_prompt.output_active = false;
            applySemanticPromptEndCommand(self, rest);
        },
        else => {
            if (log.enabled_file or log.enabled_console) {
                log.logf("osc 133: unknown kind={c}", .{kind});
            }
        },
    }
}

fn applySemanticPromptOptions(self: anytype, text: []const u8, allow_aid: bool) void {
    if (text.len == 0) return;
    var it = std.mem.splitScalar(u8, text, ';');
    while (it.next()) |kv| {
        if (kv.len == 0) continue;
        const eq = std.mem.indexOfScalar(u8, kv, '=');
        const key = if (eq) |idx| kv[0..idx] else kv;
        const value = if (eq) |idx| kv[idx + 1 ..] else "";
        if (allow_aid and std.mem.eql(u8, key, "aid")) {
            self.semantic_prompt_aid.clearRetainingCapacity();
            _ = self.semantic_prompt_aid.appendSlice(self.allocator, value) catch {};
            continue;
        }
        if (std.mem.eql(u8, key, "k")) {
            if (value.len == 1) {
                self.semantic_prompt.kind = switch (value[0]) {
                    'c' => .continuation,
                    's' => .secondary,
                    'r' => .right,
                    else => .primary,
                };
            }
            continue;
        }
        if (std.mem.eql(u8, key, "redraw")) {
            self.semantic_prompt.redraw = parseBoolFlag(value, self.semantic_prompt.redraw);
            continue;
        }
        if (std.mem.eql(u8, key, "special_key")) {
            self.semantic_prompt.special_key = parseBoolFlag(value, self.semantic_prompt.special_key);
            continue;
        }
        if (std.mem.eql(u8, key, "click_events")) {
            self.semantic_prompt.click_events = parseBoolFlag(value, self.semantic_prompt.click_events);
            continue;
        }
    }
}

fn applySemanticPromptEndInput(self: anytype, text: []const u8) void {
    if (text.len == 0) return;
    var it = std.mem.splitScalar(u8, text, ';');
    while (it.next()) |kv| {
        if (kv.len == 0) continue;
        const eq = std.mem.indexOfScalar(u8, kv, '=');
        const key = if (eq) |idx| kv[0..idx] else kv;
        const value = if (eq) |idx| kv[idx + 1 ..] else "";
        if (std.mem.eql(u8, key, "cmdline_url")) {
            setSemanticCmdlineUrl(self, value);
            continue;
        }
        if (std.mem.eql(u8, key, "cmdline")) {
            setSemanticCmdline(self, value);
            continue;
        }
    }
}

fn applySemanticPromptEndCommand(self: anytype, text: []const u8) void {
    if (text.len == 0) {
        self.semantic_prompt.exit_code = null;
        return;
    }
    if (text.len >= 2 and text[0] == ';') {
        const value = text[1..];
        self.semantic_prompt.exit_code = std.fmt.parseUnsigned(u8, value, 10) catch null;
        return;
    }
    self.semantic_prompt.exit_code = std.fmt.parseUnsigned(u8, text, 10) catch null;
}

fn setSemanticCmdline(self: anytype, value: []const u8) void {
    self.semantic_cmdline.clearRetainingCapacity();
    if (value.len == 0) {
        self.semantic_cmdline_valid = false;
        return;
    }
    _ = self.semantic_cmdline.appendSlice(self.allocator, value) catch return;
    self.semantic_cmdline_valid = true;
}

fn setSemanticCmdlineUrl(self: anytype, value: []const u8) void {
    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(self.allocator);
    if (!decodeOscPercent(self.allocator, &decoded, value)) {
        self.semantic_cmdline_valid = false;
        return;
    }
    self.semantic_cmdline.clearRetainingCapacity();
    _ = self.semantic_cmdline.appendSlice(self.allocator, decoded.items) catch return;
    self.semantic_cmdline_valid = true;
}

fn parseBoolFlag(value: []const u8, default_value: bool) bool {
    if (value.len != 1) return default_value;
    return switch (value[0]) {
        '0' => false,
        '1' => true,
        else => default_value,
    };
}

fn parseOscUserVar(self: anytype, text: []const u8) void {
    const prefix = "SetUserVar=";
    if (!std.mem.startsWith(u8, text, prefix)) return;
    const rest = text[prefix.len..];
    const split = std.mem.indexOfScalar(u8, rest, '=') orelse return;
    const name = rest[0..split];
    const encoded = rest[split + 1 ..];
    if (name.len == 0) return;

    const max_bytes: usize = 1024 * 1024;
    if (encoded.len > max_bytes * 2) return;

    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(self.allocator);
    if (encoded.len > 0) {
        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return;
        if (decoded_len > max_bytes) return;
        decoded.resize(self.allocator, decoded_len) catch return;
        _ = std.base64.standard.Decoder.decode(decoded.items, encoded) catch return;
    }

    setUserVar(self, name, decoded.items);
}

fn setUserVar(self: anytype, name: []const u8, value: []const u8) void {
    const name_owned = self.allocator.dupe(u8, name) catch return;
    const value_owned = self.allocator.dupe(u8, value) catch {
        self.allocator.free(name_owned);
        return;
    };
    const entry = self.user_vars.getOrPut(name_owned) catch {
        self.allocator.free(name_owned);
        self.allocator.free(value_owned);
        return;
    };
    if (entry.found_existing) {
        self.allocator.free(name_owned);
        self.allocator.free(entry.value_ptr.*);
        entry.value_ptr.* = value_owned;
    } else {
        entry.value_ptr.* = value_owned;
    }
}

fn decodeOscPercent(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) bool {
    out.clearRetainingCapacity();
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const b = text[i];
        if (b != '%') {
            _ = out.append(allocator, b) catch return false;
            continue;
        }
        if (i + 2 >= text.len) return false;
        const hi = hexNibble(text[i + 1]) orelse return false;
        const lo = hexNibble(text[i + 2]) orelse return false;
        const value: u8 = @as(u8, (hi << 4) | lo);
        _ = out.append(allocator, value) catch return false;
        i += 2;
    }
    return true;
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

fn logOscReplyHex(log: app_logger.Logger, seq: []const u8) void {
    if (!(log.enabled_file or log.enabled_console)) return;
    var buf: [512]u8 = undefined;
    var out: []u8 = buf[0..0];
    for (seq) |b| {
        if (out.len + 3 > buf.len) break;
        const start = out.len;
        _ = std.fmt.bufPrint(buf[start..], "{x:0>2} ", .{b}) catch break;
        out = buf[0 .. start + 3];
    }
    log.logf("osc reply bytes len={d} hex={s}", .{ seq.len, out });
}

fn hexNibble(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}
