const std = @import("std");
const types = @import("../model/types.zig");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");
const OscTerminator = parser_mod.OscTerminator;

const dynamic_color_base: u8 = 10;

pub fn buildDefaultPalette() [256]types.Color {
    var palette: [256]types.Color = undefined;
    var idx: usize = 0;
    while (idx < palette.len) : (idx += 1) {
        palette[idx] = types.indexToRgb(@intCast(idx));
    }
    return palette;
}

pub fn handleOscPalette(self: anytype, text: []const u8, terminator: OscTerminator) void {
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

pub fn handleOscPaletteReset(self: anytype, text: []const u8) void {
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

pub fn handleOscDynamicColor(self: anytype, code: u8, text: []const u8, terminator: OscTerminator) void {
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

pub fn handleOscDynamicReset(self: anytype, code: u8) void {
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

pub fn dynamicColorValue(self: anytype, code: u8) types.Color {
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

fn parseOscIndex(text: []const u8) ?usize {
    if (text.len == 0) return null;
    var value: usize = 0;
    for (text) |c| {
        if (c < '0' or c > '9') return null;
        value = value * 10 + @as(usize, c - '0');
    }
    return value;
}

fn writeOscColorReply(self: anytype, pty: anytype, code: u8, color: types.Color, terminator: OscTerminator) void {
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

fn writeOscPaletteReply(self: anytype, pty: anytype, idx: u8, color: types.Color, terminator: OscTerminator) void {
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
