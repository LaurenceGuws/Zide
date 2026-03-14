const parser_mod = @import("../parser/parser.zig");
const core_protocol = @import("terminal_core_protocol.zig");
const core_dispatch = @import("terminal_core_dispatch.zig");
const core_feed = @import("terminal_core_feed.zig");
const session_mode_effects = @import("session_mode_effects.zig");
const session_rendering = @import("session_rendering.zig");
const types = @import("../model/types.zig");

pub fn handleControl(self: anytype, byte: u8) void {
    core_dispatch.handleControl(self, byte);
}

pub fn parseDcs(self: anytype, payload: []const u8) void {
    core_dispatch.parseDcs(self, payload);
}

pub fn parseApc(self: anytype, payload: []const u8) void {
    core_dispatch.parseApc(self, payload);
}

pub fn parseOsc(self: anytype, payload: []const u8, terminator: parser_mod.OscTerminator) void {
    core_dispatch.parseOsc(self, payload, terminator);
}

pub fn appendHyperlink(self: anytype, uri: []const u8, max_hyperlinks: usize) ?u32 {
    return core_protocol.appendHyperlink(self, uri, max_hyperlinks);
}

pub fn clearAllKittyImages(self: anytype) void {
    core_protocol.clearAllKittyImages(self);
}

pub fn handleCsi(self: anytype, action: @import("../parser/csi.zig").CsiAction) void {
    core_dispatch.handleCsi(self, action);
}

pub fn feedOutputBytes(self: anytype, bytes: []const u8) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    const result = core_feed.feedOutputBytesLocked(self, bytes);
    session_rendering.publishFeedResultLocked(self, result);
}

pub fn resetState(self: anytype) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    resetStateLocked(self);
}

pub fn resetStateLocked(self: anytype) void {
    session_mode_effects.resetStateLocked(self);
}

pub fn reverseIndex(self: anytype) void {
    core_dispatch.reverseIndex(self);
}

pub fn eraseDisplay(self: anytype, mode: i32) void {
    core_protocol.eraseDisplay(self, mode);
}

pub fn eraseLine(self: anytype, mode: i32) void {
    core_protocol.eraseLine(self, mode);
}

pub fn insertChars(self: anytype, count: usize) void {
    core_protocol.insertChars(self, count);
}

pub fn deleteChars(self: anytype, count: usize) void {
    core_protocol.deleteChars(self, count);
}

pub fn eraseChars(self: anytype, count: usize) void {
    core_protocol.eraseChars(self, count);
}

pub fn insertLines(self: anytype, count: usize) void {
    core_protocol.insertLines(self, count);
}

pub fn deleteLines(self: anytype, count: usize) void {
    core_protocol.deleteLines(self, count);
}

pub fn scrollRegionUp(self: anytype, count: usize) void {
    core_protocol.scrollRegionUp(self, count);
}

pub fn scrollRegionUpWithOrigin(self: anytype, count: usize, origin: ?[]const u8) void {
    core_protocol.scrollRegionUpWithOrigin(self, count, origin);
}

pub fn scrollRegionDown(self: anytype, count: usize) void {
    core_protocol.scrollRegionDown(self, count);
}

pub fn paletteColor(self: anytype, idx: u8) types.Color {
    return core_protocol.paletteColor(self, idx);
}

pub fn handleCodepoint(self: anytype, codepoint: u32) void {
    core_dispatch.handleCodepoint(self, codepoint);
}

pub fn handleAsciiSlice(self: anytype, bytes: []const u8) void {
    core_dispatch.handleAsciiSlice(self, bytes);
}

pub fn newline(self: anytype) void {
    core_dispatch.newline(self);
}

pub fn wrapNewline(self: anytype) void {
    core_dispatch.wrapNewline(self);
}

pub fn getCell(self: anytype, row: usize, col: usize) types.Cell {
    return core_protocol.getCell(self, row, col);
}

pub fn getCursorPos(self: anytype) types.CursorPos {
    return core_protocol.getCursorPos(self);
}

pub fn setCursorStyle(self: anytype, mode: i32) void {
    core_protocol.setCursorStyle(self, mode);
}

pub fn decrqssReplyInto(self: anytype, text: []const u8, buf: []u8) ?[]const u8 {
    return core_protocol.decrqssReplyInto(self, text, buf);
}

pub fn saveCursor(self: anytype) void {
    @import("terminal_core_modes.zig").saveCursor(self);
}

pub fn restoreCursor(self: anytype) void {
    @import("terminal_core_modes.zig").restoreCursor(self);
}

pub fn setTabAtCursor(self: anytype) void {
    core_protocol.setTabAtCursor(self);
}

pub fn enterAltScreen(self: anytype, clear: bool, save_cursor: bool) void {
    session_mode_effects.enterAltScreen(self, clear, save_cursor);
}

pub fn exitAltScreen(self: anytype, restore_cursor: bool) void {
    session_mode_effects.exitAltScreen(self, restore_cursor);
}
