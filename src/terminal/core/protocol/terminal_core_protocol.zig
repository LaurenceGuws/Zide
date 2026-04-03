const std = @import("std");
const terminal_core_mod = @import("../terminal_core.zig");
const types = @import("../../model/types.zig");
const hyperlink_table = @import("../hyperlink_table.zig");
const kitty_mod = @import("../../kitty/graphics.zig");
const scrolling_mod = @import("../scrolling.zig");
const terminal_core_decrqss = @import("terminal_core_decrqss.zig");

pub fn appendHyperlink(self: anytype, uri: []const u8, max_hyperlinks: usize) ?u32 {
    return hyperlink_table.appendHyperlink(self, uri, max_hyperlinks);
}

pub fn appendHyperlink2048(self: anytype, uri: []const u8) ?u32 {
    return appendHyperlink(self, uri, 2048);
}

pub fn clearAllKittyImages(self: anytype) void {
    kitty_mod.clearAllKittyImages(self);
}

pub fn eraseDisplay(self: anytype, mode: i32) void {
    self.core.eraseDisplayLocked(self, mode);
}

pub fn eraseLine(self: anytype, mode: i32) void {
    self.core.eraseLineLocked(mode);
}

pub fn insertChars(self: anytype, count: usize) void {
    self.core.insertCharsLocked(count);
}

pub fn newline(self: anytype) void {
    scrolling_mod.consumeScrollAction(self, self.core.newlineLocked());
}

pub fn wrapNewline(self: anytype) void {
    scrolling_mod.consumeScrollAction(self, self.core.wrapNewlineLocked());
}

pub fn reverseIndex(self: anytype) void {
    scrolling_mod.consumeScrollAction(self, self.core.reverseIndexLocked());
}

pub fn deleteChars(self: anytype, count: usize) void {
    self.core.deleteCharsLocked(count);
}

pub fn eraseChars(self: anytype, count: usize) void {
    self.core.eraseCharsLocked(count);
}

pub fn insertLines(self: anytype, count: usize) void {
    self.core.insertLinesLocked(count);
}

pub fn deleteLines(self: anytype, count: usize) void {
    self.core.deleteLinesLocked(count);
}

pub fn scrollRegionUp(self: anytype, count: usize) void {
    scrolling_mod.scrollRegionUp(self, count);
}

pub fn scrollRegionUpWithOrigin(self: anytype, count: usize, origin: ?[]const u8) void {
    scrolling_mod.scrollRegionUpWithOrigin(self, count, origin);
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
    return terminal_core_decrqss.replyInto(self, text, buf);
}
