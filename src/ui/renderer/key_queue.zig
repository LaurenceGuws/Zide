const input_events = @import("../../platform/input_events.zig");
const std = @import("std");

pub const KeyPress = input_events.KeyPress;

pub fn pop(queue: *std.ArrayList(KeyPress)) ?KeyPress {
    if (queue.items.len == 0) return null;
    return queue.orderedRemove(0);
}
