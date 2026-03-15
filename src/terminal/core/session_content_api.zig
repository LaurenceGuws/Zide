const std = @import("std");
const types = @import("../model/types.zig");
const session_content = @import("session_content.zig");

pub fn API(comptime TerminalSession: type, comptime Cell: type, comptime ScrollbackInfo: type, comptime ScrollbackRange: type) type {
    return struct {
        pub fn scrollbackInfo(self: *TerminalSession) ScrollbackInfo {
            return session_content.scrollbackInfo(self);
        }

        pub fn copyScrollbackRange(
            self: *TerminalSession,
            allocator: std.mem.Allocator,
            start_row: usize,
            max_rows: usize,
            out: *std.ArrayList(Cell),
        ) !ScrollbackRange {
            return session_content.copyScrollbackRange(self, allocator, start_row, max_rows, out);
        }

        pub fn selectionPlainTextAlloc(self: *TerminalSession, allocator: std.mem.Allocator) !?[]u8 {
            return session_content.selectionPlainTextAlloc(self, allocator);
        }

        pub fn scrollbackPlainTextAlloc(self: *TerminalSession, allocator: std.mem.Allocator) ![]u8 {
            return session_content.scrollbackPlainTextAlloc(self, allocator);
        }

        pub fn scrollbackAnsiTextAlloc(self: *TerminalSession, allocator: std.mem.Allocator) ![]u8 {
            return session_content.scrollbackAnsiTextAlloc(self, allocator);
        }

        pub fn setScrollOffset(self: *TerminalSession, offset: usize) void {
            session_content.setScrollOffset(self, offset);
        }

        pub fn setScrollOffsetLocked(self: *TerminalSession, offset: usize) void {
            session_content.setScrollOffsetLocked(self, offset);
        }

        pub fn resetToLiveBottomLocked(self: *TerminalSession) bool {
            return session_content.resetToLiveBottomLocked(self);
        }

        pub fn resetToLiveBottomForInputLocked(
            self: *TerminalSession,
            saw_non_modifier_key_press: bool,
            saw_text_input: bool,
        ) bool {
            return session_content.resetToLiveBottomForInputLocked(self, saw_non_modifier_key_press, saw_text_input);
        }

        pub fn setScrollOffsetFromNormalizedTrackLocked(self: *TerminalSession, track_ratio: f32) ?usize {
            return session_content.setScrollOffsetFromNormalizedTrackLocked(self, track_ratio);
        }

        pub fn scrollSelectionDragLocked(self: *TerminalSession, toward_top: bool) bool {
            return session_content.scrollSelectionDragLocked(self, toward_top);
        }

        pub fn scrollBy(self: *TerminalSession, delta: isize) void {
            session_content.scrollBy(self, delta);
        }

        pub fn scrollByLocked(self: *TerminalSession, delta: isize) void {
            session_content.scrollByLocked(self, delta);
        }

        pub fn scrollWheelLocked(self: *TerminalSession, wheel_steps: i32) bool {
            return session_content.scrollWheelLocked(self, wheel_steps);
        }
    };
}
