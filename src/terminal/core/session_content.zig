const std = @import("std");
const scrollback_view = @import("scrollback_view.zig");
const text_export = @import("text_export.zig");
const types = @import("../model/types.zig");

pub const ScrollbackInfo = scrollback_view.ScrollbackInfo;
pub const ScrollbackRange = scrollback_view.ScrollbackRange;

pub fn scrollbackInfo(self: anytype) ScrollbackInfo {
    return scrollback_view.scrollbackInfo(self);
}

pub fn copyScrollbackRange(
    self: anytype,
    allocator: std.mem.Allocator,
    start_row: usize,
    max_rows: usize,
    out: *std.ArrayList(types.Cell),
) !ScrollbackRange {
    return scrollback_view.copyScrollbackRange(self, allocator, start_row, max_rows, out);
}

pub fn selectionPlainTextAlloc(self: anytype, allocator: std.mem.Allocator) !?[]u8 {
    return text_export.selectionPlainTextAlloc(self, allocator);
}

pub fn scrollbackPlainTextAlloc(self: anytype, allocator: std.mem.Allocator) ![]u8 {
    return text_export.scrollbackPlainTextAlloc(self, allocator);
}

pub fn scrollbackAnsiTextAlloc(self: anytype, allocator: std.mem.Allocator) ![]u8 {
    return text_export.scrollbackAnsiTextAlloc(self, allocator);
}

pub fn setScrollOffset(self: anytype, offset: usize) void {
    scrollback_view.setScrollOffset(self, offset);
}

pub fn setScrollOffsetLocked(self: anytype, offset: usize) void {
    scrollback_view.setScrollOffsetLocked(self, offset);
}

pub fn resetToLiveBottomLocked(self: anytype) bool {
    return scrollback_view.resetToLiveBottomLocked(self);
}

pub fn setScrollOffsetFromNormalizedTrackLocked(self: anytype, track_ratio: f32) ?usize {
    return scrollback_view.setScrollOffsetFromNormalizedTrackLocked(self, track_ratio);
}

pub fn scrollSelectionDragLocked(self: anytype, toward_top: bool) bool {
    return scrollback_view.scrollSelectionDragLocked(self, toward_top);
}

pub fn scrollBy(self: anytype, delta: isize) void {
    scrollback_view.scrollBy(self, delta);
}

pub fn scrollByLocked(self: anytype, delta: isize) void {
    scrollback_view.scrollByLocked(self, delta);
}

pub fn scrollWheelLocked(self: anytype, wheel_steps: i32) bool {
    return scrollback_view.scrollWheelLocked(self, wheel_steps);
}
