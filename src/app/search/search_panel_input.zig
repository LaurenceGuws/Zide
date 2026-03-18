const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const app_text_field_input = @import("../text_field_input.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;

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
    select_all: *bool,
    input_batch: *const shared_types.input.InputBatch,
) !bool {
    return try app_text_field_input.appendTextEvents(allocator, query, select_all, input_batch);
}

pub fn handleSearchPanelFieldShortcuts(
    allocator: std.mem.Allocator,
    shell: *Shell,
    query: *std.ArrayList(u8),
    select_all: *bool,
    input_batch: *const shared_types.input.InputBatch,
) !bool {
    return try app_text_field_input.handleShortcuts(allocator, shell, query, select_all, input_batch);
}
