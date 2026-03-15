const app_logger = @import("../../app_logger.zig");
const std = @import("std");
const sdl_api = @import("../../platform/sdl_api.zig");

pub fn setText(text: [*:0]const u8) void {
    sdl_api.setClipboardText(text);
}

pub fn getText() ?[]const u8 {
    return sdl_api.getClipboardText();
}

pub fn freeText(text: []const u8) void {
    sdl_api.freeClipboardText(text);
}

pub fn getData(mime_type: [*:0]const u8) ?[]const u8 {
    return sdl_api.getClipboardData(mime_type);
}

pub fn freeData(data: []const u8) void {
    sdl_api.freeClipboardData(data);
}

pub fn copyText(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8)) ?[]const u8 {
    const log = app_logger.logger("renderer.clipboard");
    const slice = getText() orelse return null;
    if (slice.len == 0) {
        freeText(slice);
        return null;
    }
    buffer.clearRetainingCapacity();
    _ = buffer.appendSlice(allocator, slice) catch |err| {
        log.logf(.warning, "clipboard text append failed bytes={d} err={s}", .{ slice.len, @errorName(err) });
        freeText(slice);
        return null;
    };
    freeText(slice);
    return buffer.items;
}

pub fn copyData(allocator: std.mem.Allocator, mime_type: [*:0]const u8) ?[]u8 {
    const log = app_logger.logger("renderer.clipboard");
    const slice = getData(mime_type) orelse return null;
    defer freeData(slice);
    if (slice.len == 0) {
        return allocator.dupe(u8, "") catch |err| {
            log.logf(.warning, "clipboard data dup empty failed err={s}", .{@errorName(err)});
            return null;
        };
    }
    return allocator.dupe(u8, slice) catch |err| {
        log.logf(.warning, "clipboard data dup failed bytes={d} err={s}", .{ slice.len, @errorName(err) });
        return null;
    };
}
