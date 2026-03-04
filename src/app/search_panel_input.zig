const std = @import("std");
const shared_types = @import("../types/mod.zig");

pub const SearchPanelCommand = enum {
    none,
    close,
    next,
    prev,
    backspace,
};

pub fn searchPanelCommand(input_batch: *const shared_types.input.InputBatch) SearchPanelCommand {
    if (input_batch.keyPressed(.escape)) return .close;
    if (input_batch.keyPressed(.enter) or input_batch.keyPressed(.kp_enter) or input_batch.keyPressed(.f3)) {
        return if (input_batch.mods.shift) .prev else .next;
    }
    if (input_batch.keyPressed(.backspace) or input_batch.keyRepeated(.backspace)) return .backspace;
    return .none;
}

pub fn appendSearchPanelTextEvents(
    allocator: std.mem.Allocator,
    query: *std.ArrayList(u8),
    input_batch: *const shared_types.input.InputBatch,
) !bool {
    var appended = false;
    for (input_batch.events.items) |event| {
        if (event != .text) continue;
        const text = event.text.utf8Slice();
        if (text.len == 0) continue;
        try query.appendSlice(allocator, text);
        appended = true;
    }
    return appended;
}
