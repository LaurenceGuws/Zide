const std = @import("std");
const session_runtime = @import("runtime.zig");

pub fn prepareForShutdown(self: anytype) void {
    session_runtime.prepareForShutdown(self);
}

pub fn start(self: anytype, shell: ?[:0]const u8) !void {
    try session_runtime.start(self, shell);
}

pub fn attachPtyTransport(self: anytype, pty: @import("../../io/pty.zig").Pty) void {
    session_runtime.attachPtyTransport(self, pty);
}

pub fn detachPtyTransport(self: anytype) void {
    session_runtime.detachPtyTransport(self);
}

pub fn startNoThreads(self: anytype, shell: ?[:0]const u8) !void {
    try session_runtime.startNoThreads(self, shell);
}

pub fn setLaunchShellPath(self: anytype, shell_path: ?[]const u8) !void {
    if (self.runtime.launch_shell_path) |old| {
        self.allocator.free(old);
        self.runtime.launch_shell_path = null;
    }
    if (shell_path) |path| {
        self.runtime.launch_shell_path = try self.allocator.dupe(u8, path);
    }
}

pub fn launchShellPath(self: anytype) []const u8 {
    return self.runtime.launch_shell_path orelse "";
}

pub fn attachExternalTransport(self: anytype) void {
    session_runtime.attachExternalTransport(self);
}

pub fn enqueueExternalBytes(self: anytype, bytes: []const u8) !bool {
    return try session_runtime.enqueueExternalBytes(self, bytes);
}

pub fn closeExternalTransport(self: anytype) bool {
    return session_runtime.closeExternalTransport(self);
}

pub fn reportExternalChildExit(self: anytype, code: ?i32) bool {
    return session_runtime.reportExternalChildExit(self, code);
}

pub fn takeExternalOutgoingBytes(self: anytype, allocator: std.mem.Allocator) !?[]u8 {
    return try session_runtime.takeExternalOutgoingBytes(self, allocator);
}

pub fn poll(self: anytype) !void {
    return session_runtime.poll(self);
}

pub fn refreshChildExit(self: anytype) void {
    session_runtime.refreshChildExit(self);
}

pub fn hasData(self: anytype) bool {
    return session_runtime.hasData(self);
}

pub fn pollBacklogHint(self: anytype) bool {
    return session_runtime.pollBacklogHint(self);
}

pub fn lockPtyWriter(self: anytype) ?@import("../runtime/terminal_transport.zig").Writer {
    return session_runtime.lockPtyWriter(self);
}

pub fn writePtyBytes(self: anytype, bytes: []const u8) !void {
    try session_runtime.writePtyBytes(self, bytes);
}
