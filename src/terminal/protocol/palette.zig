const std = @import("std");
const types = @import("../model/types.zig");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");
const OscTerminator = parser_mod.OscTerminator;

const dynamic_color_base: u8 = 10;

pub const SessionFacade = struct {
    ctx: *anyopaque,
    write_pty_bytes_fn: *const fn (ctx: *anyopaque, bytes: []const u8) anyerror!void,
    set_palette_color_locked_fn: *const fn (ctx: *anyopaque, idx: usize, color: types.Color) void,
    reset_palette_color_locked_fn: *const fn (ctx: *anyopaque, idx: usize) void,
    reset_all_palette_colors_locked_fn: *const fn (ctx: *anyopaque) void,
    set_dynamic_color_code_locked_fn: *const fn (ctx: *anyopaque, code: u8, color: ?types.Color) void,
    palette_len_fn: *const fn (ctx: *anyopaque) usize,
    palette_color_at_fn: *const fn (ctx: *anyopaque, idx: usize) types.Color,
    default_fg_fn: *const fn (ctx: *anyopaque) types.Color,
    default_bg_fn: *const fn (ctx: *anyopaque) types.Color,
    dynamic_color_at_fn: *const fn (ctx: *anyopaque, idx: usize) ?types.Color,
    dynamic_color_len_fn: *const fn (ctx: *anyopaque) usize,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .write_pty_bytes_fn = struct {
                fn call(ctx: *anyopaque, bytes: []const u8) anyerror!void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    try s.writePtyBytes(bytes);
                }
            }.call,
            .set_palette_color_locked_fn = struct {
                fn call(ctx: *anyopaque, idx: usize, color: types.Color) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setPaletteColorLocked(idx, color);
                }
            }.call,
            .reset_palette_color_locked_fn = struct {
                fn call(ctx: *anyopaque, idx: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.resetPaletteColorLocked(idx);
                }
            }.call,
            .reset_all_palette_colors_locked_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.resetAllPaletteColorsLocked();
                }
            }.call,
            .set_dynamic_color_code_locked_fn = struct {
                fn call(ctx: *anyopaque, code: u8, color: ?types.Color) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setDynamicColorCodeLocked(code, color);
                }
            }.call,
            .palette_len_fn = struct {
                fn call(ctx: *anyopaque) usize {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.palette_current.len;
                }
            }.call,
            .palette_color_at_fn = struct {
                fn call(ctx: *anyopaque, idx: usize) types.Color {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.palette_current[idx];
                }
            }.call,
            .default_fg_fn = struct {
                fn call(ctx: *anyopaque) types.Color {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.primary.default_attrs.fg;
                }
            }.call,
            .default_bg_fn = struct {
                fn call(ctx: *anyopaque) types.Color {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.primary.default_attrs.bg;
                }
            }.call,
            .dynamic_color_at_fn = struct {
                fn call(ctx: *anyopaque, idx: usize) ?types.Color {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.dynamic_colors[idx];
                }
            }.call,
            .dynamic_color_len_fn = struct {
                fn call(ctx: *anyopaque) usize {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.dynamic_colors.len;
                }
            }.call,
        };
    }

    pub fn writePtyBytes(self: *const SessionFacade, bytes: []const u8) !void {
        try self.write_pty_bytes_fn(self.ctx, bytes);
    }

    pub fn setPaletteColorLocked(self: *const SessionFacade, idx: usize, color: types.Color) void {
        self.set_palette_color_locked_fn(self.ctx, idx, color);
    }

    pub fn resetPaletteColorLocked(self: *const SessionFacade, idx: usize) void {
        self.reset_palette_color_locked_fn(self.ctx, idx);
    }

    pub fn resetAllPaletteColorsLocked(self: *const SessionFacade) void {
        self.reset_all_palette_colors_locked_fn(self.ctx);
    }

    pub fn setDynamicColorCodeLocked(self: *const SessionFacade, code: u8, color: ?types.Color) void {
        self.set_dynamic_color_code_locked_fn(self.ctx, code, color);
    }

    pub fn paletteLen(self: *const SessionFacade) usize {
        return self.palette_len_fn(self.ctx);
    }

    pub fn paletteColorAt(self: *const SessionFacade, idx: usize) types.Color {
        return self.palette_color_at_fn(self.ctx, idx);
    }

    pub fn defaultFg(self: *const SessionFacade) types.Color {
        return self.default_fg_fn(self.ctx);
    }

    pub fn defaultBg(self: *const SessionFacade) types.Color {
        return self.default_bg_fn(self.ctx);
    }

    pub fn dynamicColorAt(self: *const SessionFacade, idx: usize) ?types.Color {
        return self.dynamic_color_at_fn(self.ctx, idx);
    }

    pub fn dynamicColorLen(self: *const SessionFacade) usize {
        return self.dynamic_color_len_fn(self.ctx);
    }
};

pub fn buildDefaultPalette() [256]types.Color {
    var palette: [256]types.Color = undefined;
    var idx: usize = 0;
    while (idx < palette.len) : (idx += 1) {
        palette[idx] = types.indexToRgb(@intCast(idx));
    }
    return palette;
}

pub fn handleOscPalette(session: SessionFacade, text: []const u8, terminator: OscTerminator) void {
    if (text.len == 0) return;
    var it = std.mem.splitScalar(u8, text, ';');
    while (true) {
        const idx_text = it.next() orelse break;
        const color_text = it.next() orelse break;
        const idx = parseOscIndex(idx_text) orelse continue;
        if (idx >= session.paletteLen()) continue;
        if (color_text.len == 1 and color_text[0] == '?') {
            writeOscPaletteReply(session, @intCast(idx), session.paletteColorAt(idx), terminator);
            continue;
        }
        if (parseOscColor(color_text)) |color| {
            session.setPaletteColorLocked(idx, color);
        }
    }
}

pub fn handleOscPaletteReset(session: SessionFacade, text: []const u8) void {
    if (text.len == 0) {
        session.resetAllPaletteColorsLocked();
        return;
    }
    var it = std.mem.splitScalar(u8, text, ';');
    while (it.next()) |idx_text| {
        const idx = parseOscIndex(idx_text) orelse continue;
        session.resetPaletteColorLocked(idx);
    }
}

pub fn handleOscDynamicColor(session: SessionFacade, code: u8, text: []const u8, terminator: OscTerminator) void {
    if (text.len == 1 and text[0] == '?') {
        const color = dynamicColorValue(session, code);
        writeOscColorReply(session, code, color, terminator);
        return;
    }
    if (parseOscColor(text)) |color| {
        session.setDynamicColorCodeLocked(code, color);
    }
}

pub fn handleOscDynamicReset(session: SessionFacade, code: u8) void {
    session.setDynamicColorCodeLocked(code - 100, null);
}

pub fn dynamicColorValue(session: SessionFacade, code: u8) types.Color {
    if (code == 10) return session.defaultFg();
    if (code == 11) return session.defaultBg();
    const idx = @as(usize, code - dynamic_color_base);
    if (idx < session.dynamicColorLen()) {
        if (session.dynamicColorAt(idx)) |color| return color;
    }
    return switch (code) {
        12 => session.defaultFg(),
        17, 19 => session.defaultBg(),
        else => session.defaultFg(),
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

fn writeOscColorReply(session: SessionFacade, code: u8, color: types.Color, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    var buf: [80]u8 = undefined;
    const end = if (terminator == .bel) "\x07" else "\x1b\\";
    const r16: u16 = @as(u16, color.r) * 257;
    const g16: u16 = @as(u16, color.g) * 257;
    const b16: u16 = @as(u16, color.b) * 257;
    const seq = std.fmt.bufPrint(
        &buf,
        "\x1b]{d};rgb:{x:0>4}/{x:0>4}/{x:0>4}{s}",
        .{ code, r16, g16, b16, end },
    ) catch |err| {
        log.logf(.warning, "osc color reply format failed code={d} err={s}", .{ code, @errorName(err) });
        return;
    };
    log.logf(.debug, "osc reply=\"{s}\"", .{seq});
    logOscReplyHex(log, seq);
    session.writePtyBytes(seq) catch |err| {
        log.logf(.warning, "osc reply write failed code={d} err={s}", .{ code, @errorName(err) });
    };
}

fn writeOscPaletteReply(session: SessionFacade, idx: u8, color: types.Color, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    var buf: [88]u8 = undefined;
    const end = if (terminator == .bel) "\x07" else "\x1b\\";
    const r16: u16 = @as(u16, color.r) * 257;
    const g16: u16 = @as(u16, color.g) * 257;
    const b16: u16 = @as(u16, color.b) * 257;
    const seq = std.fmt.bufPrint(
        &buf,
        "\x1b]4;{d};rgb:{x:0>4}/{x:0>4}/{x:0>4}{s}",
        .{ idx, r16, g16, b16, end },
    ) catch |err| {
        log.logf(.warning, "osc palette reply format failed idx={d} err={s}", .{ idx, @errorName(err) });
        return;
    };
            log.logf(.debug, "osc reply=\"{s}\"", .{seq});
        logOscReplyHex(log, seq);
    session.writePtyBytes(seq) catch |err| {
        log.logf(.warning, "osc palette reply write failed idx={d} err={s}", .{ idx, @errorName(err) });
    };
}

fn logOscReplyHex(log: app_logger.Logger, seq: []const u8) void {
    var buf: [512]u8 = undefined;
    var out: []u8 = buf[0..0];
    for (seq) |b| {
        if (out.len + 3 > buf.len) break;
        const start = out.len;
        _ = std.fmt.bufPrint(buf[start..], "{x:0>2} ", .{b}) catch break;
        out = buf[0 .. start + 3];
    }
    log.logf(.debug, "osc reply bytes len={d} hex={s}", .{ seq.len, out });
}
