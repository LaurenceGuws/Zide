const clipboard = @import("clipboard.zig");
const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub fn getText(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8)) ?[]const u8 {
    const log = app_logger.logger("renderer.clipboard");
    const slice = clipboard.getText() orelse return null;
    if (slice.len == 0) {
        clipboard.freeText(slice);
        return null;
    }
    buffer.clearRetainingCapacity();
    _ = buffer.appendSlice(allocator, slice) catch |err| {
        log.logf(.warning, "clipboard text append failed bytes={d} err={s}", .{ slice.len, @errorName(err) });
        clipboard.freeText(slice);
        return null;
    };
    clipboard.freeText(slice);
    return buffer.items;
}

pub fn getData(allocator: std.mem.Allocator, mime_type: [*:0]const u8) ?[]u8 {
    const log = app_logger.logger("renderer.clipboard");
    const slice = clipboard.getData(mime_type) orelse return null;
    defer clipboard.freeData(slice);
    if (slice.len == 0) {
        return allocator.dupe(u8, "") catch |err| {
            log.logf(.warning, "clipboard data dup empty failed err={s}", .{ @errorName(err) });
            return null;
        };
    }
    return allocator.dupe(u8, slice) catch |err| {
        log.logf(.warning, "clipboard data dup failed bytes={d} err={s}", .{ slice.len, @errorName(err) });
        return null;
    };
}
