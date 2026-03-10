const std = @import("std");
const parser_mod = @import("../parser/parser.zig");
const hyperlink_table = @import("hyperlink_table.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const state_reset = @import("state_reset.zig");
const scrolling_mod = @import("scrolling.zig");
const core_protocol = @import("terminal_core_protocol.zig");
const core_dispatch = @import("terminal_core_dispatch.zig");
const core_feed = @import("terminal_core_feed.zig");
const input_modes = @import("input_modes.zig");
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
    return hyperlink_table.appendHyperlink(self, uri, max_hyperlinks);
}

pub fn clearAllKittyImages(self: anytype) void {
    kitty_mod.clearAllKittyImages(self);
}

pub fn handleCsi(self: anytype, action: @import("../parser/csi.zig").CsiAction) void {
    core_dispatch.handleCsi(self, action);
}

pub fn feedOutputBytes(self: anytype, bytes: []const u8) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    const result = core_feed.feedOutputBytesLocked(self, bytes);
    if (!result.parsed) return;
    publishCoreFeedLocked(self);
}

fn publishCoreFeedLocked(self: anytype) void {
    _ = self.output_generation.fetchAdd(1, .acq_rel);
    @import("view_cache.zig").updateViewCacheNoLock(self, self.output_generation.load(.acquire), self.core.history.scrollOffset());
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
    core_dispatch.handleControl(self, 0x8D);
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
    scrolling_mod.scrollRegionUp(self, count);
}

pub fn scrollRegionDown(self: anytype, count: usize) void {
    scrolling_mod.scrollRegionDown(self, count);
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
    state_reset.saveCursor(self);
}

pub fn restoreCursor(self: anytype) void {
    state_reset.restoreCursor(self);
}

pub fn setTabAtCursor(self: anytype) void {
    core_protocol.setTabAtCursor(self);
}

pub fn enterAltScreen(self: anytype, clear: bool, save_cursor: bool) void {
    if (self.core.active == .alt) return;
    if (save_cursor) {
        saveCursor(self);
    }
    self.core.history.saveScrollOffset();
    self.clearSelectionLocked();
    self.core.active = .alt;
    input_modes.publishSnapshot(self);
    kitty_mod.clearKittyImages(self);
    if (clear) {
        self.core.activeScreen().clear();
        self.core.activeScreen().setCursor(0, 0);
    }
    self.core.activeScreen().markDirtyAllWithReason(.alt_enter, @src());
}

pub fn exitAltScreen(self: anytype, restore_cursor: bool) void {
    if (self.core.active != .alt) return;
    kitty_mod.clearKittyImages(self);
    self.core.active = .primary;
    input_modes.publishSnapshot(self);
    self.alt_exit_pending.store(true, .release);
    self.alt_exit_time_ms.store(std.time.milliTimestamp(), .release);
    self.core.history.restoreScrollOffset(self.core.primary.grid.rows);
    self.clearSelectionLocked();
    if (restore_cursor) {
        restoreCursor(self);
    }
    self.core.activeScreen().markDirtyAllWithReason(.alt_exit, @src());
}
