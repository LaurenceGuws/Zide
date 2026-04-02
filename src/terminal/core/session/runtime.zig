const std = @import("std");
const pty_io = @import("../runtime/pty_io.zig");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const pty_mod = @import("../../io/pty.zig");
const session_lifecycle = @import("lifecycle.zig");
const runtime_init = @import("runtime_init.zig");
const session_transport_runtime = @import("transport_runtime.zig");
const session_thread_runtime = @import("thread_runtime.zig");

const Pty = pty_mod.Pty;

pub fn init(self_type: type, allocator: std.mem.Allocator, rows: u16, cols: u16, options: anytype) !*self_type {
    return try runtime_init.init(self_type, allocator, rows, cols, options);
}

pub fn start(self: anytype, shell: ?[:0]const u8) !void {
    try session_transport_runtime.start(self, shell);
}

pub fn attachPtyTransport(self: anytype, pty: Pty) void {
    session_transport_runtime.attachPtyTransport(self, pty);
}

pub fn detachPtyTransport(self: anytype) void {
    session_transport_runtime.detachPtyTransport(self);
}

pub fn attachExternalTransport(self: anytype) void {
    session_transport_runtime.attachExternalTransport(self);
}

pub fn enqueueExternalBytes(self: anytype, bytes: []const u8) !bool {
    return try session_transport_runtime.enqueueExternalBytes(self, bytes);
}

pub fn closeExternalTransport(self: anytype) bool {
    return session_transport_runtime.closeExternalTransport(self);
}

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

pub fn startNoThreads(self: anytype, shell: ?[:0]const u8) !void {
    try session_transport_runtime.startNoThreads(self, shell);
}

pub fn setInputPressure(self: anytype, value: bool) void {
    self.control.input_pressure.store(value, .release);
}

pub fn poll(self: anytype) !void {
    session_lifecycle.maybeUpdateChildExit(self);
    return pty_io.poll(self);
}

pub fn refreshChildExit(self: anytype) void {
    session_lifecycle.refreshChildExit(self);
}

pub fn hasData(self: anytype) bool {
    return session_thread_runtime.hasData(self);
}

pub fn pollBacklogHint(self: anytype) bool {
    return session_thread_runtime.pollBacklogHint(self);
}

pub fn lockPtyWriter(self: anytype) ?terminal_transport.Writer {
    return session_transport_runtime.lockPtyWriter(self);
}

pub fn takeExternalOutgoingBytes(self: anytype, allocator: std.mem.Allocator) !?[]u8 {
    return try session_transport_runtime.takeExternalOutgoingBytes(self, allocator);
}

pub fn writePtyBytes(self: anytype, bytes: []const u8) !void {
    try session_transport_runtime.writePtyBytes(self, bytes);
}

pub fn resize(self: anytype, rows: u16, cols: u16) !void {
    try session_transport_runtime.resize(self, rows, cols);
}
