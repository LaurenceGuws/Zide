const input_events = @import("../../platform/input_events.zig");
const std = @import("std");

pub const KeyPress = input_events.KeyPress;

pub fn pop(queue: *std.ArrayList(KeyPress), head: *usize) ?KeyPress {
    if (head.* >= queue.items.len) return null;
    const value = queue.items[head.*];
    head.* += 1;
    return value;
}
