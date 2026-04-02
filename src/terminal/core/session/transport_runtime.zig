const std = @import("std");
const pty_mod = @import("../../io/pty.zig");
const terminal_transport = @import("../runtime/terminal_transport.zig");

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
    try reportInBandResize2048(self, rows, cols);
}

fn reportInBandResize2048(self: anytype, rows: u16, cols: u16) !void {
    if (!self.session.interaction.inband_resize_notifications_2048) return;
    if (lockPtyWriter(self)) |writer_guard| {
        var writer = writer_guard;
        const rows_px: u32 = @as(u32, rows) * @as(u32, self.session.interaction.cell_height);
        const cols_px: u32 = @as(u32, cols) * @as(u32, self.session.interaction.cell_width);
        var buf: [64]u8 = undefined;
        const seq = try std.fmt.bufPrint(
            &buf,
            "\x1b[48;{d};{d};{d};{d}t",
            .{ rows, cols, rows_px, cols_px },
        );
        defer writer.unlock();
        _ = try writer.write(seq);
    }
}
