const std = @import("std");
const scrollback_view = @import("../scrollback_view.zig");

pub fn setScrollOffset(self: anytype, offset: usize) void {
    scrollback_view.setScrollOffset(self, offset);
}

pub fn setScrollOffsetLocked(self: anytype, offset: usize) void {
    scrollback_view.setScrollOffsetLocked(self, offset);
}

pub fn resetToLiveBottomLocked(self: anytype) bool {
    return scrollback_view.resetToLiveBottomLocked(self);
}

pub fn resetToLiveBottomForInputLocked(self: anytype, saw_non_modifier_key_press: bool, saw_text_input: bool) bool {
    return scrollback_view.resetToLiveBottomForInputLocked(self, saw_non_modifier_key_press, saw_text_input);
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
