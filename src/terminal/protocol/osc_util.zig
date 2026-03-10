const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub const SessionFacade = struct {
    allocator: std.mem.Allocator,
    cwd_buffer: *std.ArrayList(u8),
    cwd: *[]const u8,

    pub fn from(session: anytype) SessionFacade {
        return .{
            .allocator = session.allocator,
            .cwd_buffer = &session.core.cwd_buffer,
            .cwd = &session.core.cwd,
        };
    }

    pub fn clearCwdBuffer(self: *const SessionFacade) void {
        self.cwd_buffer.clearRetainingCapacity();
    }

    pub fn appendCwdByte(self: *const SessionFacade, b: u8) !void {
        try self.cwd_buffer.append(self.allocator, b);
    }

    pub fn appendCwdSlice(self: *const SessionFacade, text: []const u8) !void {
        _ = try self.cwd_buffer.appendSlice(self.allocator, text);
    }

    pub fn setCwdFromBuffer(self: *const SessionFacade) void {
        self.cwd.* = self.cwd_buffer.items;
    }

    pub fn cwdBufferLen(self: *const SessionFacade) usize {
        return self.cwd_buffer.items.len;
    }

    pub fn truncateCwdBuffer(self: *const SessionFacade, len: usize) void {
        self.cwd_buffer.items.len = len;
    }

    pub fn cwdBufferLast(self: *const SessionFacade) ?u8 {
        if (self.cwd_buffer.items.len == 0) return null;
        return self.cwd_buffer.items[self.cwd_buffer.items.len - 1];
    }
};

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

pub fn normalizeCwd(session: SessionFacade, raw_path: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    session.clearCwdBuffer();
    session.appendCwdByte('/') catch |err| {
        log.logf(.warning, "osc cwd normalize root append failed: {s}", .{@errorName(err)});
        return;
    };

    var stack = std.ArrayList(usize).empty;
    defer stack.deinit(session.allocator);

    var it = std.mem.splitScalar(u8, raw_path, '/');
    while (it.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".")) continue;
        if (std.mem.eql(u8, segment, "..")) {
            if (stack.pop()) |new_len| {
                session.truncateCwdBuffer(new_len);
            } else if (session.cwdBufferLen() > 1) {
                session.truncateCwdBuffer(1);
            }
            continue;
        }
        if (session.cwdBufferLen() > 1 and session.cwdBufferLast() != '/') {
            session.appendCwdByte('/') catch |err| {
                log.logf(.warning, "osc cwd normalize slash append failed: {s}", .{@errorName(err)});
                return;
            };
        }
        const segment_start = session.cwdBufferLen();
        session.appendCwdSlice(segment) catch |err| {
            log.logf(.warning, "osc cwd normalize segment append failed: {s}", .{@errorName(err)});
            return;
        };
        _ = stack.append(session.allocator, segment_start) catch |err| {
            log.logf(.warning, "osc cwd normalize stack append failed: {s}", .{@errorName(err)});
            return;
        };
    }

    if (session.cwdBufferLen() == 0) {
        session.appendCwdByte('/') catch |err| {
            log.logf(.warning, "osc cwd normalize final root append failed: {s}", .{@errorName(err)});
            return;
        };
    }
    session.setCwdFromBuffer();
}

fn hexNibble(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}
