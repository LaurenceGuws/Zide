const pty_io = @import("../runtime/pty_io.zig");
const session_lifecycle = @import("lifecycle.zig");
const session_thread_runtime = @import("thread_runtime.zig");

pub fn reportExternalChildExit(self: anytype, code: ?i32) bool {
    return session_lifecycle.reportExternalChildExit(self, code);
}

pub fn deinit(self: anytype) void {
    session_thread_runtime.deinit(self);
}

pub fn prepareForShutdown(self: anytype) void {
    session_lifecycle.refreshChildExit(self);
    session_thread_runtime.prepareForShutdown(self);
}

pub fn poll(self: anytype) !void {
    session_lifecycle.maybeUpdateChildExit(self);
    return pty_io.poll(self);
}

pub fn refreshChildExit(self: anytype) void {
    session_lifecycle.refreshChildExit(self);
}
