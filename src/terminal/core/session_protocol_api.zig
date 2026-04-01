const csi_mod = @import("../parser/csi.zig");
const parser_mod = @import("../parser/parser.zig");
const session_protocol = @import("session_protocol.zig");
const types = @import("../model/types.zig");

pub fn handleControl(self: anytype, byte: u8) void {
    session_protocol.handleControl(self, byte);
}

pub fn parseDcs(self: anytype, payload: []const u8) void {
    session_protocol.parseDcs(self, payload);
}

pub fn parseApc(self: anytype, payload: []const u8) void {
    session_protocol.parseApc(self, payload);
}

pub fn parseOsc(self: anytype, payload: []const u8, terminator: parser_mod.OscTerminator) void {
    session_protocol.parseOsc(self, payload, terminator);
}

pub fn appendHyperlink(self: anytype, uri: []const u8) ?u32 {
    return session_protocol.appendHyperlink(self, uri, 2048);
}

pub fn clearAllKittyImages(self: anytype) void {
    session_protocol.clearAllKittyImages(self);
}

pub fn handleCsi(self: anytype, action: csi_mod.CsiAction) void {
    session_protocol.handleCsi(self, action);
}

pub fn feedOutputBytes(self: anytype, bytes: []const u8) void {
    session_protocol.feedOutputBytes(self, bytes);
}

pub fn resetState(self: anytype) void {
    session_protocol.resetState(self);
}

pub fn resetStateLocked(self: anytype) void {
    session_protocol.resetStateLocked(self);
}

pub fn reverseIndex(self: anytype) void {
    session_protocol.reverseIndex(self);
}

pub fn eraseDisplay(self: anytype, mode: i32) void {
    session_protocol.eraseDisplay(self, mode);
}

pub fn eraseLine(self: anytype, mode: i32) void {
    session_protocol.eraseLine(self, mode);
}

pub fn insertChars(self: anytype, count: usize) void {
    session_protocol.insertChars(self, count);
}

pub fn deleteChars(self: anytype, count: usize) void {
    session_protocol.deleteChars(self, count);
}

pub fn eraseChars(self: anytype, count: usize) void {
    session_protocol.eraseChars(self, count);
}

pub fn insertLines(self: anytype, count: usize) void {
    session_protocol.insertLines(self, count);
}

pub fn deleteLines(self: anytype, count: usize) void {
    session_protocol.deleteLines(self, count);
}

pub fn scrollRegionUp(self: anytype, count: usize) void {
    session_protocol.scrollRegionUp(self, count);
}

pub fn scrollRegionUpWithOrigin(self: anytype, count: usize, origin: ?[]const u8) void {
    session_protocol.scrollRegionUpWithOrigin(self, count, origin);
}

pub fn scrollRegionDown(self: anytype, count: usize) void {
    session_protocol.scrollRegionDown(self, count);
}

pub fn paletteColor(self: anytype, idx: u8) types.Color {
    return session_protocol.paletteColor(self, idx);
}

pub fn handleCodepoint(self: anytype, codepoint: u32) void {
    session_protocol.handleCodepoint(self, codepoint);
}

pub fn handleAsciiSlice(self: anytype, bytes: []const u8) void {
    session_protocol.handleAsciiSlice(self, bytes);
}

pub fn newline(self: anytype) void {
    session_protocol.newline(self);
}

pub fn wrapNewline(self: anytype) void {
    session_protocol.wrapNewline(self);
}

pub fn getCell(self: anytype, row: usize, col: usize) types.Cell {
    return session_protocol.getCell(self, row, col);
}

pub fn getCursorPos(self: anytype) types.CursorPos {
    return session_protocol.getCursorPos(self);
}

pub fn setCursorStyle(self: anytype, mode: i32) void {
    session_protocol.setCursorStyle(self, mode);
}

pub fn decrqssReplyInto(self: anytype, text: []const u8, buf: []u8) ?[]const u8 {
    return session_protocol.decrqssReplyInto(self, text, buf);
}

pub fn saveCursor(self: anytype) void {
    session_protocol.saveCursor(self);
}

pub fn restoreCursor(self: anytype) void {
    session_protocol.restoreCursor(self);
}

pub fn setTabAtCursor(self: anytype) void {
    session_protocol.setTabAtCursor(self);
}

pub fn enterAltScreen(self: anytype, clear: bool, save_cursor: bool) void {
    session_protocol.enterAltScreen(self, clear, save_cursor);
}

pub fn exitAltScreen(self: anytype, restore_cursor: bool) void {
    session_protocol.exitAltScreen(self, restore_cursor);
}
