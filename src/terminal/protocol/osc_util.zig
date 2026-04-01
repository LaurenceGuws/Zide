const std = @import("std");
const app_logger = @import("../../app_logger.zig");

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
    const log = app_logger.logger("terminal.osc");
    self.core.clearCwdBuffer();
    self.core.appendCwdByte(self.allocator, '/') catch |err| {
        log.logf(.warning, "osc cwd normalize root append failed: {s}", .{@errorName(err)});
        return;
    };

    var stack = std.ArrayList(usize).empty;
    defer stack.deinit(self.allocator);

    var it = std.mem.splitScalar(u8, raw_path, '/');
    while (it.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".")) continue;
        if (std.mem.eql(u8, segment, "..")) {
            if (stack.pop()) |new_len| {
                self.core.truncateCwdBuffer(new_len);
            } else if (self.core.cwdBufferLen() > 1) {
                self.core.truncateCwdBuffer(1);
            }
            continue;
        }
        if (self.core.cwdBufferLen() > 1 and self.core.cwdBufferLast() != '/') {
            self.core.appendCwdByte(self.allocator, '/') catch |err| {
                log.logf(.warning, "osc cwd normalize slash append failed: {s}", .{@errorName(err)});
                return;
            };
        }
        const segment_start = self.core.cwdBufferLen();
        self.core.appendCwdSlice(self.allocator, segment) catch |err| {
            log.logf(.warning, "osc cwd normalize segment append failed: {s}", .{@errorName(err)});
            return;
        };
        _ = stack.append(self.allocator, segment_start) catch |err| {
            log.logf(.warning, "osc cwd normalize stack append failed: {s}", .{@errorName(err)});
            return;
        };
    }

    if (self.core.cwdBufferLen() == 0) {
        self.core.appendCwdByte(self.allocator, '/') catch |err| {
            log.logf(.warning, "osc cwd normalize final root append failed: {s}", .{@errorName(err)});
            return;
        };
    }
    self.core.publishCwdBuffer();
}

fn hexNibble(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}
