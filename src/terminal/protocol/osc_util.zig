const std = @import("std");

pub fn decodeOscPercent(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) bool {
    out.clearRetainingCapacity();
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const b = text[i];
        if (b != '%') {
            _ = out.append(allocator, b) catch return false;
            continue;
        }
        if (i + 2 >= text.len) return false;
        const hi = hexNibble(text[i + 1]) orelse return false;
        const lo = hexNibble(text[i + 2]) orelse return false;
        const value: u8 = @as(u8, (hi << 4) | lo);
        _ = out.append(allocator, value) catch return false;
        i += 2;
    }
    return true;
}

pub fn normalizeCwd(self: anytype, raw_path: []const u8) void {
    self.cwd_buffer.clearRetainingCapacity();
    _ = self.cwd_buffer.append(self.allocator, '/') catch return;

    var stack = std.ArrayList(usize).empty;
    defer stack.deinit(self.allocator);

    var it = std.mem.splitScalar(u8, raw_path, '/');
    while (it.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".")) continue;
        if (std.mem.eql(u8, segment, "..")) {
            if (stack.pop()) |new_len| {
                self.cwd_buffer.items.len = new_len;
            } else if (self.cwd_buffer.items.len > 1) {
                self.cwd_buffer.items.len = 1;
            }
            continue;
        }
        if (self.cwd_buffer.items.len > 1 and self.cwd_buffer.items[self.cwd_buffer.items.len - 1] != '/') {
            _ = self.cwd_buffer.append(self.allocator, '/') catch return;
        }
        const segment_start = self.cwd_buffer.items.len;
        _ = self.cwd_buffer.appendSlice(self.allocator, segment) catch return;
        _ = stack.append(self.allocator, segment_start) catch return;
    }

    if (self.cwd_buffer.items.len == 0) {
        _ = self.cwd_buffer.append(self.allocator, '/') catch return;
    }
    self.cwd = self.cwd_buffer.items;
}

fn hexNibble(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}
