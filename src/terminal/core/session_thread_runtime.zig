const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const app_lifecycle_runtime = @import("../../app/lifecycle_runtime.zig");
const terminal_transport = @import("terminal_transport.zig");

pub fn deinit(self: anytype) void {
    prepareForShutdown(self);
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_transport_deinit_begin", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(self) } },
            .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
            .{ .key = "transport_alive", .value = .{ .boolean = transport.isAlive() } },
            .{ .key = "child_exited", .value = .{ .boolean = self.child_exited.load(.acquire) } },
            .{ .key = "child_exit_code", .value = .{ .integer = self.child_exit_code.load(.acquire) } },
        });
        transport.deinit();
        app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_transport_deinit_end", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(self) } },
            .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
        });
    }
    if (self.launch_shell_path) |path| {
        self.allocator.free(path);
        self.launch_shell_path = null;
    }
    self.render_caches[0].deinit(self.allocator);
    self.render_caches[1].deinit(self.allocator);
    self.io_buffer.deinit(self.allocator);
    self.core.deinit(self);
    self.allocator.destroy(self);
}

pub fn prepareForShutdown(self: anytype) void {
    if (!self.tearing_down) {
        self.tearing_down = true;
    }
    stopThreads(self);
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_transport_prepare_shutdown_begin", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(self) } },
            .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
            .{ .key = "transport_alive", .value = .{ .boolean = transport.isAlive() } },
            .{ .key = "child_exited", .value = .{ .boolean = self.child_exited.load(.acquire) } },
            .{ .key = "child_exit_code", .value = .{ .integer = self.child_exit_code.load(.acquire) } },
        });
        transport.deinit();
        app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_transport_prepare_shutdown_end", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(self) } },
            .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
        });
    }
}

pub fn hasData(self: anytype) bool {
    if (self.read_thread != null) {
        if (self.parse_thread != null) {
            return self.output_pending.load(.acquire) or hasUnreadBufferedIo(self);
        }
        if (self.output_pending.load(.acquire)) return true;
        return hasUnreadBufferedIo(self);
    }
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        return transport.hasData();
    }
    return false;
}

pub fn pollBacklogHint(self: anytype) bool {
    return hasData(self) or @import("terminal_publication.zig").hasPublishedGenerationBacklog(self);
}

fn hasUnreadBufferedIo(self: anytype) bool {
    var pending = false;
    self.io_mutex.lock();
    if (self.io_buffer.items.len > self.io_read_offset) {
        pending = true;
    }
    self.io_mutex.unlock();
    return pending;
}

fn stopThreads(self: anytype) void {
    if (self.read_thread) |thread| {
        app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_read_thread_stop_signal", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(self) } },
            .{ .key = "shutdown_started", .value = .{ .boolean = app_lifecycle_runtime.shutdownStarted() } },
            .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
        });
        self.read_thread_running.store(false, .release);
        app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_read_thread_join_begin", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(self) } },
        });
        thread.join();
        app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_read_thread_join_end", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(self) } },
            .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
        });
        self.read_thread = null;
    }
    if (self.parse_thread) |thread| {
        app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_parse_thread_stop_signal", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(self) } },
            .{ .key = "shutdown_started", .value = .{ .boolean = app_lifecycle_runtime.shutdownStarted() } },
            .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
        });
        self.parse_thread_running.store(false, .release);
        self.io_wait_cond.signal();
        app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_parse_thread_join_begin", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(self) } },
        });
        thread.join();
        app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_parse_thread_join_end", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(self) } },
            .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
        });
        self.parse_thread = null;
    }
}

test "hasData stays true for threaded session while unread parse buffer remains" {
    const session_runtime = @import("session_runtime.zig");

    const allocator = std.testing.allocator;
    const session = try session_runtime.init(allocator, 24, 80, .{});
    defer {
        session.read_thread = null;
        session.parse_thread = null;
        session.deinit();
    }

    session.read_thread = undefined;
    session.parse_thread = undefined;
    session.output_pending.store(false, .release);
    try session.io_buffer.appendSlice(session.allocator, "queued");
    session.io_read_offset = 0;

    try std.testing.expect(hasData(session));
}
