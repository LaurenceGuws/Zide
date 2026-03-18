fn wrappedIndex(len: usize, current: usize, next: bool) usize {
    if (len <= 1) return 0;
    if (next) return (current + 1) % len;
    return if (current == 0) len - 1 else current - 1;
}

pub fn cycle(state: anytype, next: bool) !bool {
    if (state.tab_bar.tabs.items.len <= 1) return false;

    const target_index = wrappedIndex(state.tab_bar.tabs.items.len, state.tab_bar.active_index, next);
    if (target_index == state.tab_bar.active_index) return false;

    state.tab_bar.active_index = target_index;
    state.active_tab = target_index;
    state.active_kind = switch (state.tab_bar.tabs.items[target_index].kind) {
        .editor => .editor,
        .terminal => .terminal,
    };

    const app_mode_adapter_sync_runtime = @import("../mode_adapter_sync_runtime.zig");
    try app_mode_adapter_sync_runtime.sync(state);
    return true;
}

test "wrappedIndex cycles forward and backward with wraparound" {
    const std = @import("std");

    try std.testing.expectEqual(@as(usize, 1), wrappedIndex(3, 0, true));
    try std.testing.expectEqual(@as(usize, 2), wrappedIndex(3, 0, false));
    try std.testing.expectEqual(@as(usize, 0), wrappedIndex(3, 2, true));
    try std.testing.expectEqual(@as(usize, 1), wrappedIndex(3, 2, false));
    try std.testing.expectEqual(@as(usize, 0), wrappedIndex(1, 0, true));
}
