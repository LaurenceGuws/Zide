const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub const SessionFacade = struct {
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
    clear_cwd_buffer_fn: *const fn (ctx: *anyopaque) void,
    append_cwd_byte_fn: *const fn (ctx: *anyopaque, b: u8) anyerror!void,
    append_cwd_slice_fn: *const fn (ctx: *anyopaque, text: []const u8) anyerror!void,
    set_cwd_from_buffer_fn: *const fn (ctx: *anyopaque) void,
    cwd_buffer_len_fn: *const fn (ctx: *anyopaque) usize,
    truncate_cwd_buffer_fn: *const fn (ctx: *anyopaque, len: usize) void,
    cwd_buffer_last_fn: *const fn (ctx: *anyopaque) ?u8,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .allocator = session.allocator,
            .clear_cwd_buffer_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.cwd_buffer.clearRetainingCapacity();
                }
            }.call,
            .append_cwd_byte_fn = struct {
                fn call(ctx: *anyopaque, b: u8) anyerror!void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    try s.cwd_buffer.append(s.allocator, b);
                }
            }.call,
            .append_cwd_slice_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8) anyerror!void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    _ = try s.cwd_buffer.appendSlice(s.allocator, text);
                }
            }.call,
            .set_cwd_from_buffer_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.cwd = s.cwd_buffer.items;
                }
            }.call,
            .cwd_buffer_len_fn = struct {
                fn call(ctx: *anyopaque) usize {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.cwd_buffer.items.len;
                }
            }.call,
            .truncate_cwd_buffer_fn = struct {
                fn call(ctx: *anyopaque, len: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.cwd_buffer.items.len = len;
                }
            }.call,
            .cwd_buffer_last_fn = struct {
                fn call(ctx: *anyopaque) ?u8 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (s.cwd_buffer.items.len == 0) return null;
                    return s.cwd_buffer.items[s.cwd_buffer.items.len - 1];
                }
            }.call,
        };
    }

    pub fn clearCwdBuffer(self: *const SessionFacade) void {
        self.clear_cwd_buffer_fn(self.ctx);
    }

    pub fn appendCwdByte(self: *const SessionFacade, b: u8) !void {
        try self.append_cwd_byte_fn(self.ctx, b);
    }

    pub fn appendCwdSlice(self: *const SessionFacade, text: []const u8) !void {
        try self.append_cwd_slice_fn(self.ctx, text);
    }

    pub fn setCwdFromBuffer(self: *const SessionFacade) void {
        self.set_cwd_from_buffer_fn(self.ctx);
    }

    pub fn cwdBufferLen(self: *const SessionFacade) usize {
        return self.cwd_buffer_len_fn(self.ctx);
    }

    pub fn truncateCwdBuffer(self: *const SessionFacade, len: usize) void {
        self.truncate_cwd_buffer_fn(self.ctx, len);
    }

    pub fn cwdBufferLast(self: *const SessionFacade) ?u8 {
        return self.cwd_buffer_last_fn(self.ctx);
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
