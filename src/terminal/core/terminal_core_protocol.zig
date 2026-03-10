const std = @import("std");
const types = @import("../model/types.zig");
const hyperlink_table = @import("hyperlink_table.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const scrolling_mod = @import("scrolling.zig");

pub fn appendHyperlink(self: anytype, uri: []const u8, max_hyperlinks: usize) ?u32 {
    return hyperlink_table.appendHyperlink(self, uri, max_hyperlinks);
}

pub fn clearAllKittyImages(self: anytype) void {
    kitty_mod.clearAllKittyImages(self);
}

pub fn eraseDisplay(self: anytype, mode: i32) void {
    const screen = self.core.activeScreen();
    const blank_cell = screen.blankCell();
    screen.eraseDisplay(mode, blank_cell);
    if (mode == 2 or mode == 3) {
        self.clearSelectionLocked();
        _ = self.core.clear_generation.fetchAdd(1, .acq_rel);
    }
}

pub fn eraseLine(self: anytype, mode: i32) void {
    const screen = self.core.activeScreen();
    const blank_cell = screen.blankCell();
    screen.eraseLine(mode, blank_cell);
}

pub fn insertChars(self: anytype, count: usize) void {
    const screen = self.core.activeScreen();
    const blank_cell = screen.blankCell();
    screen.insertChars(count, blank_cell);
}

pub fn deleteChars(self: anytype, count: usize) void {
    const screen = self.core.activeScreen();
    const blank_cell = screen.blankCell();
    screen.deleteChars(count, blank_cell);
}

pub fn eraseChars(self: anytype, count: usize) void {
    const screen = self.core.activeScreen();
    const blank_cell = screen.blankCell();
    screen.eraseChars(count, blank_cell);
}

pub fn insertLines(self: anytype, count: usize) void {
    const screen = self.core.activeScreen();
    const blank_cell = screen.blankCell();
    screen.insertLines(count, blank_cell);
}

pub fn deleteLines(self: anytype, count: usize) void {
    const screen = self.core.activeScreen();
    const blank_cell = screen.blankCell();
    screen.deleteLines(count, blank_cell);
}

pub fn scrollRegionUp(self: anytype, count: usize) void {
    scrolling_mod.scrollRegionUp(self, count);
}

pub fn scrollRegionDown(self: anytype, count: usize) void {
    scrolling_mod.scrollRegionDown(self, count);
}

pub fn paletteColor(self: anytype, idx: u8) types.Color {
    return self.core.palette_current[idx];
}

pub fn getCell(self: anytype, row: usize, col: usize) types.Cell {
    const screen = self.core.activeScreenConst();
    return screen.cellAtOr(row, col, self.core.primary.defaultCell());
}

pub fn getCursorPos(self: anytype) types.CursorPos {
    return self.core.activeScreenConst().cursorPos();
}

pub fn setCursorStyle(self: anytype, mode: i32) void {
    self.core.activeScreen().setCursorStyle(mode);
}

pub fn setTabAtCursor(self: anytype) void {
    self.core.activeScreen().setTabAtCursor();
}

pub fn decrqssReplyInto(self: anytype, text: []const u8, buf: []u8) ?[]const u8 {
    const log = @import("../../app_logger.zig").logger("terminal.apc");
    if (std.mem.eql(u8, text, " q")) {
        const style = self.core.activeScreen().cursor_style;
        return switch (style.shape) {
            .block => if (style.blink) "1 q" else "2 q",
            .underline => if (style.blink) "3 q" else "4 q",
            .bar => if (style.blink) "5 q" else "6 q",
        };
    }
    if (std.mem.eql(u8, text, "m")) {
        return decrqssSgrReply(self, buf);
    }
    if (std.mem.eql(u8, text, "r")) {
        const screen = self.core.activeScreen();
        return std.fmt.bufPrint(buf, "{d};{d}r", .{
            screen.scroll_top + 1,
            screen.scroll_bottom + 1,
        }) catch |err| {
            log.logf(.warning, "decrqss r reply format failed err={s}", .{@errorName(err)});
            return null;
        };
    }
    if (std.mem.eql(u8, text, "s")) {
        const screen = self.core.activeScreen();
        return std.fmt.bufPrint(buf, "{d};{d}s", .{
            screen.left_margin + 1,
            screen.right_margin + 1,
        }) catch |err| {
            log.logf(.warning, "decrqss s reply format failed err={s}", .{@errorName(err)});
            return null;
        };
    }
    return null;
}

fn decrqssSgrReply(self: anytype, buf: []u8) ?[]const u8 {
    const screen = self.core.activeScreen();
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
        const code = decrqssPaletteSgrCode(self, attrs.fg, true) orelse return null;
        if (!appendParam(buf, &pos, code)) return null;
    }
    if (!colorEq(attrs.bg, defaults.bg)) {
        const code = decrqssPaletteSgrCode(self, attrs.bg, false) orelse return null;
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

fn decrqssPaletteSgrCode(self: anytype, color: types.Color, fg: bool) ?u8 {
    var idx: u8 = 0;
    while (idx < 16) : (idx += 1) {
        if (colorEq(color, paletteColor(self, idx))) {
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
    const log = @import("../../app_logger.zig").logger("terminal.csi");
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
