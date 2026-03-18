const std = @import("std");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");

const Shell = app_shell.Shell;

pub fn appendTextEvents(
    allocator: std.mem.Allocator,
    query: *std.ArrayList(u8),
    select_all: *bool,
    input_batch: *const shared_types.input.InputBatch,
) !bool {
    var appended = false;
    for (input_batch.events.items) |event| {
        if (event != .text) continue;
        const text = event.text.utf8Slice();
        if (text.len == 0) continue;
        if (select_all.*) {
            query.clearRetainingCapacity();
            select_all.* = false;
        }
        try query.appendSlice(allocator, text);
        appended = true;
    }
    return appended;
}

fn setClipboard(shell: *Shell, text: []const u8, allocator: std.mem.Allocator) !void {
    const buf = try allocator.alloc(u8, text.len + 1);
    defer allocator.free(buf);
    std.mem.copyForwards(u8, buf[0..text.len], text);
    buf[text.len] = 0;
    const cstr: [*:0]const u8 = @ptrCast(buf.ptr);
    shell.setClipboardText(cstr);
}

pub fn handleShortcuts(
    allocator: std.mem.Allocator,
    shell: *Shell,
    query: *std.ArrayList(u8),
    select_all: *bool,
    input_batch: *const shared_types.input.InputBatch,
) !bool {
    if (!input_batch.mods.ctrl or input_batch.mods.alt or input_batch.mods.super or input_batch.mods.altgr) return false;

    if (input_batch.keyPressed(.a)) {
        select_all.* = query.items.len > 0;
        return true;
    }
    if (input_batch.keyPressed(.c)) {
        if (select_all.* and query.items.len > 0) {
            try setClipboard(shell, query.items, allocator);
        }
        return true;
    }
    if (input_batch.keyPressed(.x)) {
        if (select_all.* and query.items.len > 0) {
            try setClipboard(shell, query.items, allocator);
            query.clearRetainingCapacity();
            select_all.* = false;
        }
        return true;
    }
    if (input_batch.keyPressed(.v)) {
        if (shell.getClipboardText()) |clip| {
            if (select_all.*) {
                query.clearRetainingCapacity();
                select_all.* = false;
            }
            try query.appendSlice(allocator, clip);
        }
        return true;
    }
    return false;
}
