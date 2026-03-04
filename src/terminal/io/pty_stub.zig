const std = @import("std");
const PtySize = @import("pty.zig").PtySize;

pub const Pty = struct {
    pub fn init(_: std.mem.Allocator, _: PtySize, _: ?[:0]const u8) !Pty {
        return Pty{};
    }

    pub fn deinit(_: *Pty) void {}

    pub fn resize(_: *Pty, _: PtySize) !void {}

    pub fn write(_: *Pty, _: []const u8) !usize {
        return 0;
    }

    pub fn read(_: *Pty, _: []u8) !?usize {
        return null;
    }

    pub fn pollExit(_: *Pty) !?i32 {
        return null;
    }

    pub fn isAlive(_: *Pty) bool {
        return false;
    }

    pub fn hasForegroundProcessOutsideShell(_: *Pty) bool {
        return false;
    }

    pub fn foregroundProcessLabel(_: *Pty) ?[]const u8 {
        return null;
    }

    pub fn hasData(_: *Pty) bool {
        return false;
    }

    pub fn waitForData(_: *Pty, _: i32) bool {
        return false;
    }
};
