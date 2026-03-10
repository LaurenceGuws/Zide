const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const pty_io = @import("pty_io.zig");
const resize_reflow = @import("resize_reflow.zig");

pub fn start(self: anytype, shell: ?[:0]const u8) !void {
    try pty_io.start(self, shell);
}

pub fn startNoThreads(self: anytype, shell: ?[:0]const u8) !void {
    try pty_io.startNoThreads(self, shell);
}

pub fn poll(self: anytype) !void {
    maybeUpdateChildExit(self);
    return pty_io.poll(self);
}

fn maybeUpdateChildExit(self: anytype) void {
    if (self.child_exited.load(.acquire)) return;
    if (self.pty) |*pty| {
        if (pty.pollExit() catch |err| blk: {
            const log = app_logger.logger("terminal.pty");
            log.logf(.warning, "pty pollExit failed err={s}", .{@errorName(err)});
            break :blk null;
        }) |code| {
            self.child_exit_code.store(code, .release);
            self.child_exited.store(true, .release);

            const log = app_logger.logger("terminal.pty");
            log.logf(.info, "pty child exited code={d}", .{code});
        }
    }
}

pub fn hasData(self: anytype) bool {
    if (self.read_thread != null) {
        if (self.parse_thread != null) {
            return self.output_pending.load(.acquire);
        }
        if (self.output_pending.load(.acquire)) return true;
        var pending = false;
        self.io_mutex.lock();
        if (self.io_buffer.items.len > self.io_read_offset) {
            pending = true;
        }
        self.io_mutex.unlock();
        return pending;
    }
    if (self.pty) |*pty| {
        return pty.hasData();
    }
    return false;
}

pub fn lockPtyWriter(self: anytype) ?@import("terminal_session.zig").PtyWriteGuard {
    if (self.pty) |*pty| {
        self.pty_write_mutex.lock();
        return .{
            .mutex = &self.pty_write_mutex,
            .pty = pty,
        };
    }
    return null;
}

pub fn writePtyBytes(self: anytype, bytes: []const u8) !void {
    var writer = lockPtyWriter(self) orelse return;
    defer writer.unlock();
    _ = try writer.write(bytes);
}

pub fn resize(self: anytype, rows: u16, cols: u16) !void {
    try resize_reflow.resize(self, rows, cols);
    try reportInBandResize2048(self, rows, cols);
}

fn reportInBandResize2048(self: anytype, rows: u16, cols: u16) !void {
    if (!self.inband_resize_notifications_2048) return;
    if (lockPtyWriter(self)) |writer_guard| {
        var writer = writer_guard;
        const rows_px: u32 = @as(u32, rows) * @as(u32, self.cell_height);
        const cols_px: u32 = @as(u32, cols) * @as(u32, self.cell_width);
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
