const std = @import("std");
const types = @import("../../model/types.zig");
const session_content = @import("session_content.zig");

pub fn API(comptime PtyTerminalRuntime: type, comptime Cell: type, comptime ScrollbackInfo: type, comptime ScrollbackRange: type) type {
    return struct {
        pub fn scrollbackInfo(self: *PtyTerminalRuntime) ScrollbackInfo {
            return session_content.scrollbackInfo(self);
        }

        pub fn copyScrollbackRange(
            self: *PtyTerminalRuntime,
            allocator: std.mem.Allocator,
            start_row: usize,
            max_rows: usize,
            out: *std.ArrayList(Cell),
        ) !ScrollbackRange {
            return session_content.copyScrollbackRange(self, allocator, start_row, max_rows, out);
        }

        pub fn selectionPlainTextAlloc(self: *PtyTerminalRuntime, allocator: std.mem.Allocator) !?[]u8 {
            return session_content.selectionPlainTextAlloc(self, allocator);
        }

        pub fn scrollbackPlainTextAlloc(self: *PtyTerminalRuntime, allocator: std.mem.Allocator) ![]u8 {
            return session_content.scrollbackPlainTextAlloc(self, allocator);
        }

        pub fn scrollbackAnsiTextAlloc(self: *PtyTerminalRuntime, allocator: std.mem.Allocator) ![]u8 {
            return session_content.scrollbackAnsiTextAlloc(self, allocator);
        }

        pub fn setScrollOffset(self: *PtyTerminalRuntime, offset: usize) void {
            session_content.setScrollOffset(self, offset);
        }

        pub fn setScrollOffsetLocked(self: *PtyTerminalRuntime, offset: usize) void {
            session_content.setScrollOffsetLocked(self, offset);
        }

        pub fn resetToLiveBottomLocked(self: *PtyTerminalRuntime) bool {
            return session_content.resetToLiveBottomLocked(self);
        }

        pub fn resetToLiveBottomForInputLocked(
            self: *PtyTerminalRuntime,
            saw_non_modifier_key_press: bool,
            saw_text_input: bool,
        ) bool {
            return session_content.resetToLiveBottomForInputLocked(self, saw_non_modifier_key_press, saw_text_input);
        }

        pub fn setScrollOffsetFromNormalizedTrackLocked(self: *PtyTerminalRuntime, track_ratio: f32) ?usize {
            return session_content.setScrollOffsetFromNormalizedTrackLocked(self, track_ratio);
        }

        pub fn scrollSelectionDragLocked(self: *PtyTerminalRuntime, toward_top: bool) bool {
            return session_content.scrollSelectionDragLocked(self, toward_top);
        }

        pub fn scrollBy(self: *PtyTerminalRuntime, delta: isize) void {
            session_content.scrollBy(self, delta);
        }

        pub fn scrollByLocked(self: *PtyTerminalRuntime, delta: isize) void {
            session_content.scrollByLocked(self, delta);
        }

        pub fn scrollWheelLocked(self: *PtyTerminalRuntime, wheel_steps: i32) bool {
            return session_content.scrollWheelLocked(self, wheel_steps);
        }
    };
}
