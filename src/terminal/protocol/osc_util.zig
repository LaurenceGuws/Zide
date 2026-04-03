const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_core_osc_metadata = @import("../core/protocol/terminal_core_osc_metadata.zig");

pub fn decodeOscPercent(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) bool {
    const log = app_logger.logger("terminal.osc");
    out.clearRetainingCapacity();
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const b = text[i];
        if (b != '%') {
            _ = out.append(allocator, b) catch |err| {
                log.logf(.warning, "osc percent decode append failed: {s}", .{@errorName(err)});
                return false;
            };
            continue;
        }
        if (i + 2 >= text.len) return false;
        const hi = hexNibble(text[i + 1]) orelse return false;
        const lo = hexNibble(text[i + 2]) orelse return false;
        const value: u8 = @as(u8, (hi << 4) | lo);
        _ = out.append(allocator, value) catch |err| {
            log.logf(.warning, "osc percent decode value append failed: {s}", .{@errorName(err)});
            return false;
        };
        i += 2;
    }
    return true;
}

pub fn normalizeCwd(self: anytype, raw_path: []const u8) void {
    terminal_core_osc_metadata.normalizeAndPublishCwd(self, raw_path);
}

fn hexNibble(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}
