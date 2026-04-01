const std = @import("std");
const screen_mod = @import("../../model/screen.zig");
const session_runtime = @import("runtime.zig");

pub fn init(self_type: type, allocator: std.mem.Allocator, rows: u16, cols: u16) !*self_type {
    return initWithOptions(self_type, allocator, rows, cols, .{});
}

pub fn initWithOptions(
    self_type: type,
    allocator: std.mem.Allocator,
    rows: u16,
    cols: u16,
    options: anytype,
) !*self_type {
    return try session_runtime.init(allocator, rows, cols, options);
}

pub fn activeScreen(self: anytype) *screen_mod.Screen {
    return self.core.activeScreen();
}

pub fn activeScreenConst(self: anytype) *const screen_mod.Screen {
    return self.core.activeScreenConst();
}

pub fn setInputPressure(self: anytype, value: bool) void {
    session_runtime.setInputPressure(self, value);
}

pub fn isAltActive(self: anytype) bool {
    return self.core.isAltActive();
}

pub fn deinit(self: anytype) void {
    session_runtime.deinit(self);
}

pub fn lock(self: anytype) void {
    self.control.state_mutex.lock();
}

pub fn tryLock(self: anytype) bool {
    return self.control.state_mutex.tryLock();
}

pub fn unlock(self: anytype) void {
    self.control.state_mutex.unlock();
}

pub fn resize(self: anytype, rows: u16, cols: u16) !void {
    try session_runtime.resize(self, rows, cols);
}
