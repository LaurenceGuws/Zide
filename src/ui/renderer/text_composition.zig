const std = @import("std");

pub const TextComposition = struct {
    text: []const u8,
    cursor: i32,
    selection_len: i32,
    active: bool,
};

pub fn snapshot(text: []const u8, cursor: i32, selection_len: i32, active: bool) TextComposition {
    return .{
        .text = text,
        .cursor = cursor,
        .selection_len = selection_len,
        .active = active,
    };
}

pub fn reset(
    composing_text: *std.ArrayList(u8),
    composing_cursor: *i32,
    composing_selection_len: *i32,
    composing_active: *bool,
) void {
    if (!composing_active.*) return;
    composing_active.* = false;
    composing_text.clearRetainingCapacity();
    composing_cursor.* = 0;
    composing_selection_len.* = 0;
}
