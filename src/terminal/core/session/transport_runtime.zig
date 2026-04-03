const std = @import("std");
const pty_mod = @import("../../io/pty.zig");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const host_reporting = @import("host_reporting.zig");

const Pty = pty_mod.Pty;

pub fn start(self: anytype, shell: ?[:0]const u8) !void {
    try terminal_transport.openPty(self, shell, true);
}

pub fn attachPtyTransport(self: anytype, pty: Pty) void {
    terminal_transport.attachPty(self, pty);
}

pub fn detachPtyTransport(self: anytype) void {
    terminal_transport.detachPty(self);
}

pub fn startNoThreads(self: anytype, shell: ?[:0]const u8) !void {
    try terminal_transport.openPty(self, shell, false);
}

pub fn attachExternalTransport(self: anytype) void {
    terminal_transport.attachExternalTransport(self);
}

pub fn enqueueExternalBytes(self: anytype, bytes: []const u8) !bool {
    return try terminal_transport.enqueueExternalBytes(self, bytes);
}

pub fn closeExternalTransport(self: anytype) bool {
    return terminal_transport.closeExternalTransport(self);
}

pub fn lockPtyWriter(self: anytype) ?terminal_transport.Writer {
    return terminal_transport.Writer.fromSession(self);
}

pub fn takeExternalOutgoingBytes(self: anytype, allocator: std.mem.Allocator) !?[]u8 {
    _ = allocator;
    if (self.session.runtime.external_transport) |*transport| {
        return try transport.takeOutgoing();
    }
    return null;
}

pub fn writePtyBytes(self: anytype, bytes: []const u8) !void {
    var writer = lockPtyWriter(self) orelse return;
    defer writer.unlock();
    _ = try writer.write(bytes);
}

pub fn resize(self: anytype, rows: u16, cols: u16) !void {
    try @import("../resize_reflow.zig").resize(self, rows, cols);
    try host_reporting.reportInBandResize2048(self, rows, cols);
}

pub fn resizeWithCellSize(self: anytype, rows: u16, cols: u16, cell_width: u16, cell_height: u16) !void {
    try @import("../resize_reflow.zig").resizeWithCellSize(self, rows, cols, cell_width, cell_height);
    try host_reporting.reportInBandResize2048(self, rows, cols);
}
