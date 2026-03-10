const std = @import("std");
const csi_mod = @import("../parser/csi.zig");
const parser_mod = @import("../parser/parser.zig");
const parser_hooks = @import("parser_hooks.zig");
const control_handlers = @import("control_handlers.zig");
const hyperlink_table = @import("hyperlink_table.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const state_reset = @import("state_reset.zig");
const scrolling_mod = @import("scrolling.zig");
const input_modes = @import("input_modes.zig");
const types = @import("../model/types.zig");

pub fn handleControl(self: anytype, byte: u8) void {
    control_handlers.handleControl(self, byte);
}

pub fn parseDcs(self: anytype, payload: []const u8) void {
    parser_hooks.parseDcs(parser_hooks.SessionFacade.from(self), payload);
}

pub fn parseApc(self: anytype, payload: []const u8) void {
    parser_hooks.parseApc(parser_hooks.SessionFacade.from(self), payload);
}

pub fn parseOsc(self: anytype, payload: []const u8, terminator: parser_mod.OscTerminator) void {
    parser_hooks.parseOsc(parser_hooks.SessionFacade.from(self), payload, terminator);
}

pub fn appendHyperlink(self: anytype, uri: []const u8, max_hyperlinks: usize) ?u32 {
    return hyperlink_table.appendHyperlink(self, uri, max_hyperlinks);
}

pub fn clearAllKittyImages(self: anytype) void {
    kitty_mod.clearAllKittyImages(self);
}

pub fn handleCsi(self: anytype, action: csi_mod.CsiAction) void {
    parser_hooks.handleCsi(parser_hooks.SessionFacade.from(self), action);
}

pub fn feedOutputBytes(self: anytype, bytes: []const u8) void {
    if (bytes.len == 0) return;
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    self.parser.handleSlice(parser_mod.Parser.SessionFacade.from(self), bytes);
    _ = self.output_generation.fetchAdd(1, .acq_rel);
    @import("view_cache.zig").updateViewCacheNoLock(self, self.output_generation.load(.acquire), self.history.scrollOffset());
}

pub fn resetState(self: anytype) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    state_reset.resetStateLocked(self);
}

pub fn resetStateLocked(self: anytype) void {
    state_reset.resetStateLocked(self);
}

pub fn reverseIndex(self: anytype) void {
    control_handlers.reverseIndex(self);
}

pub fn eraseDisplay(self: anytype, mode: i32) void {
    const screen = self.activeScreen();
    const blank_cell = screen.blankCell();
    screen.eraseDisplay(mode, blank_cell);
    if (mode == 2 or mode == 3) {
        self.clearSelectionLocked();
        _ = self.clear_generation.fetchAdd(1, .acq_rel);
    }
}

pub fn eraseLine(self: anytype, mode: i32) void {
    const screen = self.activeScreen();
    const blank_cell = screen.blankCell();
    screen.eraseLine(mode, blank_cell);
}

pub fn insertChars(self: anytype, count: usize) void {
    const screen = self.activeScreen();
    const blank_cell = screen.blankCell();
    screen.insertChars(count, blank_cell);
}

pub fn deleteChars(self: anytype, count: usize) void {
    const screen = self.activeScreen();
    const blank_cell = screen.blankCell();
    screen.deleteChars(count, blank_cell);
}

pub fn eraseChars(self: anytype, count: usize) void {
    const screen = self.activeScreen();
    const blank_cell = screen.blankCell();
    screen.eraseChars(count, blank_cell);
}

pub fn insertLines(self: anytype, count: usize) void {
    const screen = self.activeScreen();
    const blank_cell = screen.blankCell();
    screen.insertLines(count, blank_cell);
}

pub fn deleteLines(self: anytype, count: usize) void {
    const screen = self.activeScreen();
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
    return self.palette_current[idx];
}

pub fn handleCodepoint(self: anytype, codepoint: u32) void {
    parser_hooks.handleCodepoint(parser_hooks.SessionFacade.from(self), codepoint);
}

pub fn handleAsciiSlice(self: anytype, bytes: []const u8) void {
    parser_hooks.handleAsciiSlice(parser_hooks.SessionFacade.from(self), bytes);
}

pub fn newline(self: anytype) void {
    control_handlers.newline(self);
}

pub fn wrapNewline(self: anytype) void {
    control_handlers.wrapNewline(self);
}

pub fn getCell(self: anytype, row: usize, col: usize) types.Cell {
    const screen = self.activeScreenConst();
    return screen.cellAtOr(row, col, self.primary.defaultCell());
}

pub fn getCursorPos(self: anytype) types.CursorPos {
    return self.activeScreenConst().cursorPos();
}

pub fn setCursorStyle(self: anytype, mode: i32) void {
    self.activeScreen().setCursorStyle(mode);
}

pub fn decrqssReplyInto(self: anytype, text: []const u8, buf: []u8) ?[]const u8 {
    const log = @import("../../app_logger.zig").logger("terminal.apc");
    if (std.mem.eql(u8, text, " q")) {
        const style = self.activeScreen().cursor_style;
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
        const screen = self.activeScreen();
        return std.fmt.bufPrint(buf, "{d};{d}r", .{
            screen.scroll_top + 1,
            screen.scroll_bottom + 1,
        }) catch |err| {
            log.logf(.warning, "decrqss r reply format failed err={s}", .{@errorName(err)});
            return null;
        };
    }
    if (std.mem.eql(u8, text, "s")) {
        const screen = self.activeScreen();
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

pub fn saveCursor(self: anytype) void {
    state_reset.saveCursor(self);
}

pub fn restoreCursor(self: anytype) void {
    state_reset.restoreCursor(self);
}

pub fn setTabAtCursor(self: anytype) void {
    self.activeScreen().setTabAtCursor();
}

pub fn enterAltScreen(self: anytype, clear: bool, save_cursor: bool) void {
    if (self.active == .alt) return;
    if (save_cursor) {
        saveCursor(self);
    }
    self.history.saveScrollOffset();
    self.clearSelectionLocked();
    self.active = .alt;
    input_modes.publishSnapshot(self);
    kitty_mod.clearKittyImages(self);
    if (clear) {
        self.activeScreen().clear();
        self.activeScreen().setCursor(0, 0);
    }
    self.activeScreen().markDirtyAllWithReason(.alt_enter, @src());
}

pub fn exitAltScreen(self: anytype, restore_cursor: bool) void {
    if (self.active != .alt) return;
    kitty_mod.clearKittyImages(self);
    self.active = .primary;
    input_modes.publishSnapshot(self);
    self.alt_exit_pending.store(true, .release);
    self.alt_exit_time_ms.store(std.time.milliTimestamp(), .release);
    self.history.restoreScrollOffset(self.primary.grid.rows);
    self.clearSelectionLocked();
    if (restore_cursor) {
        restoreCursor(self);
    }
    self.activeScreen().markDirtyAllWithReason(.alt_exit, @src());
}

fn decrqssSgrReply(self: anytype, buf: []u8) ?[]const u8 {
    const screen = self.activeScreen();
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
