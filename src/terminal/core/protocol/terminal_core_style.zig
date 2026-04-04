const std = @import("std");
const types = @import("../../model/types.zig");
const terminal_core_mod = @import("../terminal_core.zig");
const app_logger = @import("../../../app_logger.zig");

const TerminalCore = terminal_core_mod.TerminalCore;
const Color = types.Color;

pub fn applySgrLocked(self: *TerminalCore, params: []const i32) void {
    const screen = self.activeScreen();
    const current_attrs = &screen.current_attrs;
    const default_attrs = &screen.default_attrs;

    var i: usize = 0;
    while (i < params.len) {
        const p = params[i];
        if (p == 38 or p == 48 or p == 58) {
            if (i + 1 < params.len) {
                const mode = params[i + 1];
                if (mode == 5 and i + 2 < params.len) {
                    const idx = types.clampColorIndex(params[i + 2]);
                    const color = self.palette_current[idx];
                    switch (p) {
                        38 => current_attrs.fg = color,
                        48 => current_attrs.bg = color,
                        58 => current_attrs.underline_color = color,
                        else => {},
                    }
                    i += 3;
                    continue;
                }
                if (mode == 2) {
                    const base: usize = i + 2;
                    if (base + 2 < params.len) {
                        const r = types.clampColorIndex(params[base]);
                        const g = types.clampColorIndex(params[base + 1]);
                        const b = types.clampColorIndex(params[base + 2]);
                        const color = Color{ .r = r, .g = g, .b = b, .a = 255 };
                        switch (p) {
                            38 => current_attrs.fg = color,
                            48 => current_attrs.bg = color,
                            58 => current_attrs.underline_color = color,
                            else => {},
                        }
                        i = base + 3;
                        continue;
                    }
                }
                if (mode == 6) {
                    const base: usize = i + 2;
                    if (base + 3 < params.len) {
                        const r = types.clampColorIndex(params[base]);
                        const g = types.clampColorIndex(params[base + 1]);
                        const b = types.clampColorIndex(params[base + 2]);
                        const a = types.clampColorIndex(params[base + 3]);
                        const color = Color{ .r = r, .g = g, .b = b, .a = a };
                        switch (p) {
                            38 => current_attrs.fg = color,
                            48 => current_attrs.bg = color,
                            58 => current_attrs.underline_color = color,
                            else => {},
                        }
                        i = base + 4;
                        continue;
                    }
                }
            }
            i += 1;
            continue;
        }
        switch (p) {
            0 => current_attrs.* = default_attrs.*,
            1 => current_attrs.bold = true,
            5 => {
                current_attrs.blink = true;
                current_attrs.blink_fast = false;
            },
            6 => {
                current_attrs.blink = true;
                current_attrs.blink_fast = true;
            },
            22 => current_attrs.bold = false,
            25 => {
                current_attrs.blink = false;
                current_attrs.blink_fast = false;
            },
            4 => current_attrs.underline = true,
            24 => current_attrs.underline = false,
            7 => current_attrs.reverse = true,
            27 => current_attrs.reverse = false,
            39 => current_attrs.fg = default_attrs.fg,
            49 => current_attrs.bg = default_attrs.bg,
            59 => current_attrs.underline_color = default_attrs.underline_color,
            30...37 => current_attrs.fg = self.palette_current[@intCast(p - 30)],
            40...47 => current_attrs.bg = self.palette_current[@intCast(p - 40)],
            90...97 => current_attrs.fg = self.palette_current[@intCast(8 + (p - 90))],
            100...107 => current_attrs.bg = self.palette_current[@intCast(8 + (p - 100))],
            else => {},
        }
        i += 1;
    }
}

pub fn decrqssCursorStyleReplyText(self: *const TerminalCore) []const u8 {
    const style = self.activeScreenConst().cursor_style;
    return switch (style.shape) {
        .block => if (style.blink) "1 q" else "2 q",
        .underline => if (style.blink) "3 q" else "4 q",
        .bar => if (style.blink) "5 q" else "6 q",
    };
}

pub fn sgrReplyInto(self: *const TerminalCore, buf: []u8) ?[]const u8 {
    const screen = self.activeScreenConst();
    const attrs = screen.current_attrs;
    const defaults = screen.default_attrs;
    var pos: usize = 0;

    if (attrs.bold) if (!appendParam(buf, &pos, 1)) return null;
    if (attrs.blink and !attrs.blink_fast) {
        if (!appendParam(buf, &pos, 5)) return null;
    }
    if (attrs.blink and attrs.blink_fast) {
        if (!appendParam(buf, &pos, 6)) return null;
    }
    if (attrs.reverse) {
        if (!appendParam(buf, &pos, 7)) return null;
    }
    if (attrs.underline) {
        if (!appendParam(buf, &pos, 4)) return null;
    }

    if (!colorEq(attrs.fg, defaults.fg)) {
        const code = paletteSgrCode(self, attrs.fg, true) orelse return null;
        if (!appendParam(buf, &pos, code)) return null;
    }
    if (!colorEq(attrs.bg, defaults.bg)) {
        const code = paletteSgrCode(self, attrs.bg, false) orelse return null;
        if (!appendParam(buf, &pos, code)) return null;
    }

    if (pos == 0) {
        if (buf.len < 1) return null;
        buf[0] = 'm';
        return buf[0..1];
    }
    if (pos + 1 > buf.len) return null;
    buf[pos] = 'm';
    return buf[0 .. pos + 1];
}

pub fn dynamicColorValue(self: *const TerminalCore, code: u8) types.Color {
    if (code == 10) return self.primary.default_attrs.fg;
    if (code == 11) return self.primary.default_attrs.bg;
    const idx = @as(usize, code - 10);
    if (idx < self.dynamic_colors.len) {
        if (self.dynamic_colors[idx]) |color| return color;
    }
    return switch (code) {
        12 => self.primary.default_attrs.fg,
        17, 19 => self.primary.default_attrs.bg,
        else => self.primary.default_attrs.fg,
    };
}

fn paletteSgrCode(self: *const TerminalCore, color: types.Color, fg: bool) ?u8 {
    var idx: u8 = 0;
    while (idx < 16) : (idx += 1) {
        if (colorEq(color, self.palette_current[idx])) {
            if (idx < 8) return (if (fg) @as(u8, 30) else @as(u8, 40)) + idx;
            return (if (fg) @as(u8, 90) else @as(u8, 100)) + (idx - 8);
        }
    }
    return null;
}

fn colorEq(a: types.Color, b: types.Color) bool {
    return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
}

fn appendParam(buf: []u8, pos: *usize, param: u8) bool {
    const log = app_logger.logger("terminal.csi");
    var tmp: [4]u8 = undefined;
    const text = std.fmt.bufPrint(&tmp, "{d}", .{param}) catch |err| {
        log.logf(.warning, "appendParam format failed param={d}: {s}", .{ param, @errorName(err) });
        return false;
    };
    var needed = text.len;
    if (pos.* > 0) needed += 1;
    if (pos.* + needed > buf.len) return false;
    if (pos.* > 0) {
        buf[pos.*] = ';';
        pos.* += 1;
    }
    @memcpy(buf[pos.* .. pos.* + text.len], text);
    pos.* += text.len;
    return true;
}
